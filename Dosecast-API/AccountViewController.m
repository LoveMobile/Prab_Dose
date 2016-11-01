//
//  AccountViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "AccountViewController.h"
#import "DataModel.h"
#import "PurchaseManager.h"
#import "StoreKit/SKProduct.h"
#import "GlobalSettings.h"
#import "HistoryManager.h"
#import "DosecastUtil.h"
#import "QuartzCore/CALayer.h"
#import "ReachabilityManager.h"
#import "ServerProxy.h"
#import "PillNotificationManager.h"
#import "LocalNotificationManager.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const CGFloat LABEL_BASE_HEIGHT = 17.0f;
static const CGFloat CELL_MIN_HEIGHT = 40.0f;
static float epsilon = 0.0001;

@implementation AccountViewController

@synthesize tableView;
@synthesize accountTypeCell;
@synthesize subscriptionProductCell;
@synthesize subscriptionDescriptionCell;
@synthesize restorePurchaseCell;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(NSObject<AccountViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
		delegate = del;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		hasRefreshedProductList = NO;
        exampleSubscriptionProductCell = nil;
		[PurchaseManager getInstance].delegate = self;
		origAccountType = [DataModel getInstance].globalSettings.accountType;
        origSubscriptionExpires = [DataModel getInstance].globalSettings.subscriptionExpires;
        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

	self.title = NSLocalizedStringWithDefaultValue(@"ViewAccountTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Account", @"The title of the Account view"]);
		
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	tableView.allowsSelection = NO;	
	
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"ProductTableViewCell" owner:self options:nil];
    exampleSubscriptionProductCell = subscriptionProductCell;
    subscriptionProductCell = nil;
    
	// Refresh the product list
    [[PurchaseManager getInstance] refreshProductList];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    // Scroll the text view to the top
    UITextView* textView = (UITextView *)[subscriptionDescriptionCell viewWithTag:1];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];
}

- (void) recalcExampleCellWidth
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int screenWidth = 0;
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait ||
        self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        screenWidth = screenBounds.size.width;
    }
    else
        screenWidth = screenBounds.size.height;
    exampleSubscriptionProductCell.frame = CGRectMake(exampleSubscriptionProductCell.frame.origin.x, exampleSubscriptionProductCell.frame.origin.y, screenWidth, exampleSubscriptionProductCell.frame.size.height);
    [exampleSubscriptionProductCell layoutIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (BOOL) isOfferingFreeTrial
{
    DataModel* dataModel = [DataModel getInstance];
    return (!dataModel.globalSettings.issued7daySubscriptionTrial && !dataModel.globalSettings.subscriptionExpires);
}

- (IBAction)handlePurchase:(id)sender
{
    // Make sure the sender is a UIButton
    if (![sender isKindOfClass:[UIButton class]])
        return;
	
	// Get the superview (the UITableViewCell)
	UIButton* senderButton = (UIButton*)sender;
    UIView* superView = senderButton.superview;
    while (![superView isKindOfClass:[UITableViewCell class]])
        superView = superView.superview;
	UITableViewCell *tableViewCell = (UITableViewCell*)superView;
	
	DebugLog(@"handlePurchase start");

	// Now extract the index path for the cell
	NSIndexPath* cellIndexPath = [self.tableView indexPathForCell:tableViewCell];
	
    if ([self isOfferingFreeTrial] && cellIndexPath.row == 0)
    {
        [[LocalNotificationManager getInstance] startFreeTrial:nil async:NO];
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil message:NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionTrialStartedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your free trial has started and will last 7 days. Enjoy!", @"The message in the alert appearing if purchases are disabled and the user attempts to purchase"]) style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          [self handleSubscribeComplete];
                                      }]];

        [alert showInViewController:self];
    }
    else
    {
        SKProduct* p = [[PurchaseManager getInstance].productList objectAtIndex:([self isOfferingFreeTrial] ? cellIndexPath.row-1 : cellIndexPath.row)];

        // Purchase the product, if we are allowed to
        if ([SKPaymentQueue canMakePayments])
        {
            [[PurchaseManager getInstance] purchaseProduct:p];
        }
        else
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPurchaseTransactionFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Process Purchase", @"The title on the alert appearing if an error occurred when processing a purchase"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorPurchasesDisabledMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"In-app purchases are currently disabled on this device. Please re-enable in-app purchases and try again.", @"The message in the alert appearing if purchases are disabled and the user attempts to purchase"])];
            [alert showInViewController:self];
        }
    }
    
	DebugLog(@"handlePurchase end");
}

- (IBAction)handleRestorePurchase:(id)sender
{
    // If we have an internet connection, do a sync call to the server to see if we were magically given a free premium edition
    if ([[ReachabilityManager getInstance] canReachInternet])
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRestoringPurchase", @"Dosecast", [DosecastUtil getResourceBundle], @"Restoring purchase", @"The message appearing in the spinner view when restoring a purchase"])];

        ServerProxy* ppProxy = [ServerProxy getInstance];
        [ppProxy sync:self];
    }
    else
    {
        DebugLog(@"handleRestorePurchase start");

        [[PurchaseManager getInstance] restoreCompletedTransactions];
        
        DebugLog(@"handleRestorePurchase end");
    }
}

// Called when the user initiated a subscribe and it completed successfully
- (void)handleSubscribeComplete
{
	DebugLog(@"handleSubscribeComplete start");

	[tableView reloadData];
	
	// Report back to our delegate, if any
	if (delegate && [delegate respondsToSelector:@selector(handleSubscribeComplete)])
	{
		[delegate handleSubscribeComplete];
	}					
	
    [self.navigationController popViewControllerAnimated:YES];

	DebugLog(@"handleSubscribeComplete end");
}

- (void)syncServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];

    if (status == ServerProxyDeviceDetached)
    {
        [dataModel allowDosecastUserInteractionsWithMessage:YES];
        return;
    }
    
    BOOL issuedOrExtendedAccess = NO;
    
	if (status == ServerProxySuccess)
	{
        // See whether we were given a premium edition account
        AccountType newAccountType = dataModel.globalSettings.accountType;
        NSDate* newSubscriptionExpires = dataModel.globalSettings.subscriptionExpires;
        BOOL issuedSubscription = (origAccountType != AccountTypeSubscription && newAccountType == AccountTypeSubscription);
        BOOL extendedSubscription = (origAccountType == AccountTypeSubscription && newAccountType == AccountTypeSubscription &&
                                     newSubscriptionExpires && [newSubscriptionExpires timeIntervalSinceNow] > 0 &&
                                     (!origSubscriptionExpires || [newSubscriptionExpires timeIntervalSinceDate:origSubscriptionExpires] > epsilon));
        BOOL issuedPremium = (origAccountType == AccountTypeDemo && newAccountType == AccountTypePremium);
        if (issuedSubscription || extendedSubscription || issuedPremium)
        {
            issuedOrExtendedAccess = YES;
            
            // Report back to our delegate, if any
            if (delegate && [delegate respondsToSelector:@selector(handleSubscribeComplete)])
            {
                [delegate handleSubscribeComplete];
            }					
        }
	}
    
    if (issuedOrExtendedAccess)
    {
        [dataModel allowDosecastUserInteractionsWithMessage:YES];
        [self.navigationController popViewControllerAnimated:YES];
    }
    else
    {
        DebugLog(@"handleRestorePurchase start");
        
        [[PurchaseManager getInstance] restoreCompletedTransactions];
        
        DebugLog(@"handleRestorePurchase end");
    }
}

- (void)handleProductListRefreshed
{
	DebugLog(@"handleProductListRefreshed start");
    
	if ([[PurchaseManager getInstance].productList count] > 0)
	{
		hasRefreshedProductList = YES;
        
        [tableView reloadData];
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorAccountProductListRefreshTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Apple Server Unavailable", @"The title on the alert appearing when a product list refresh fails on the account page"])
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ErrorAccountProductListRefreshMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Apple's in-app purchase server appears to be unavailable. Consequently, the list of products available for purchase could not be retrieved. Please try again in a few moments.", @"The message on the alert appearing when a product list refresh fails on the account page"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          // If the user clicked cancel, no reason to stay here
                                          [self.navigationController popViewControllerAnimated:YES];
                                      }]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonTryAgain", @"Dosecast", [DosecastUtil getResourceBundle], @"Try Again", @"The text on the Try Again button in an alert"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          DebugLog(@"product list refresh error alert start");
                                          
                                          [[PurchaseManager getInstance] refreshProductList];
                                          
                                          DebugLog(@"product list refresh error alert end");
                                      }]];
        
        [alert showInViewController:self];
	}
		
	DebugLog(@"handleProductListRefreshed end");
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];
	if (!hasRefreshedProductList)
		return 2;
	else
		return 4;
}
 
// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 1;
    else if (section == 1)
        return 1;
    else if (section == 2)
    {
        NSUInteger numProducts = [[PurchaseManager getInstance].productList count];
        if ([self isOfferingFreeTrial])
            numProducts += 1;
   
        return numProducts;
    }
    else // if section == 3
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	DataModel* dataModel = [DataModel getInstance];

	if (indexPath.section == 0)
	{
        UILabel* accountTypeHeader = (UILabel *)[accountTypeCell viewWithTag:1];
        UILabel* accountTypeLabel = (UILabel *)[accountTypeCell viewWithTag:3];
        UILabel* subscriptionStatusHeader = (UILabel *)[accountTypeCell viewWithTag:2];
        UILabel* subscriptionStatusLabel = (UILabel *)[accountTypeCell viewWithTag:4];
        
        accountTypeCell.accessoryType = UITableViewCellAccessoryNone;
        accountTypeCell.selectionStyle = UITableViewCellSelectionStyleGray;

        accountTypeHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEdition", @"Dosecast", [DosecastUtil getResourceBundle], @"Edition", @"The edition label in the Settings view"]);
        
        AccountType accountType = dataModel.globalSettings.accountType;
        
        if (accountType == AccountTypeDemo)
            accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionDemo", @"Dosecast", [DosecastUtil getResourceBundle], @"Free", @"The demo edition label in the Settings view"]);
        else if (accountType == AccountTypePremium)
            accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPremium", @"Dosecast", [DosecastUtil getResourceBundle], @"Premium", @"The Premium edition label in the Settings view"]);
        else
            accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPro", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro with CloudSync", @"The Premium edition label in the Settings view"]);
        
        if (dataModel.globalSettings.subscriptionExpires &&
            ((accountType == AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0) ||
             (accountType != AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] < 0)))
        {
            subscriptionStatusHeader.hidden = NO;
            subscriptionStatusHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscription", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscription", @"The edition label in the Settings view"]);
            
            subscriptionStatusLabel.hidden = NO;
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            
            if ([dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0)
            {
                subscriptionStatusLabel.textColor = [UIColor blackColor];
                subscriptionStatusLabel.text = [NSString stringWithFormat:
                                                NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscriptionExpiresPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Expires on %@", @"The edition label in the Settings view"]),
                                                [dateFormatter stringFromDate:dataModel.globalSettings.subscriptionExpires]];
            }
            else
            {
                subscriptionStatusLabel.textColor = [DosecastUtil getDrugWarningLabelColor];
                subscriptionStatusLabel.text = [NSString stringWithFormat:
                                                NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscriptionExpiredPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Expired on %@", @"The edition label in the Settings view"]),
                                                [dateFormatter stringFromDate:dataModel.globalSettings.subscriptionExpires]];
            }
        }
        else
        {
            subscriptionStatusHeader.hidden = YES;
            subscriptionStatusLabel.hidden = YES;
        }
        
        return accountTypeCell;
	}
    else if (indexPath.section == 1)
    {
        UITextView* descriptionTextView = (UITextView *)[subscriptionDescriptionCell viewWithTag:1];
        
        // Initialize the properties of the cell
        descriptionTextView.text = NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The edition label in the Settings view"]);
        descriptionTextView.editable = NO;
        descriptionTextView.dataDetectorTypes = UIDataDetectorTypeNone;

        return subscriptionDescriptionCell;
    }
	else if (indexPath.section == 2)
	{
        static NSString *MyIdentifier = @"ProductCellIdentifier";
        
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
        if (cell == nil) {
            [[DosecastUtil getResourceBundle] loadNibNamed:@"ProductTableViewCell" owner:self options:nil];
            cell = subscriptionProductCell;
            subscriptionProductCell = nil;
        }
        UILabel* productTitleLabel = (UILabel *)[cell viewWithTag:1];
        UILabel* productDescriptionLabel = (UILabel *)[cell viewWithTag:2];
        UIButton* productPriceButton = (UIButton *)[cell viewWithTag:3];
        NSString* productPrice = nil;
        
        if ([self isOfferingFreeTrial] && indexPath.row == 0)
        {
            productTitleLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionTrialTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"7 day trial of Dosecast Pro with CloudSync", @"The edition label in the Settings view"]);
            productDescriptionLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionTrialDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"Try Dosecast Pro with CloudSync free for 7 days!", @"The edition label in the Settings view"]);
            productPrice = NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionTrialPrice", @"Dosecast", [DosecastUtil getResourceBundle], @"Free", @"The edition label in the Settings view"]);
        }
        else
        {
            SKProduct* product = (SKProduct*)[[PurchaseManager getInstance].productList objectAtIndex:([self isOfferingFreeTrial] ? indexPath.row-1 : indexPath.row)];
            productTitleLabel.text = product.localizedTitle;
            productDescriptionLabel.text = product.localizedDescription;
            productPrice = [[PurchaseManager getInstance] getDisplayPriceForProduct:product];
        }

        CGFloat descriptionFieldHeight = (int)ceilf([self getHeightForCellLabel:2 withString:productDescriptionLabel.text]);
        productDescriptionLabel.frame = CGRectMake(productDescriptionLabel.frame.origin.x, productDescriptionLabel.frame.origin.y, productDescriptionLabel.frame.size.width, descriptionFieldHeight);

        [productPriceButton setTitle:productPrice forState:UIControlStateNormal];
        [productPriceButton setTitle:productPrice forState:UIControlStateHighlighted];
        [productPriceButton setTitle:productPrice forState:UIControlStateDisabled];
        [productPriceButton setTitle:productPrice forState:UIControlStateSelected];
        
        // Dynamically set the color of the price button
        [DosecastUtil setBackgroundColorForButton:productPriceButton color:[DosecastUtil getProductPriceButtonColor]];
        
        return cell;
	}
	else if (indexPath.section == 3)
	{
		UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		restorePurchaseCell.backgroundView = backView;
        restorePurchaseCell.backgroundColor = [UIColor clearColor];
		
		// Dynamically set the color of the button
		UIButton* restoreButton = (UIButton *)[restorePurchaseCell viewWithTag:1];
		[restoreButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewAccountRestorePurchase", @"Dosecast", [DosecastUtil getResourceBundle], @"Restore Past Purchases", @"The text on the Restore Past Purchase button in Account view"]) forState:UIControlStateNormal];
		[DosecastUtil setBackgroundColorForButton:restoreButton color:[DosecastUtil getRestorePurchaseButtonColor]];
		
		return restorePurchaseCell;
	}
    else
        return nil;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[tableView reloadData];
}

- (CGFloat) getHeightForCellLabel:(int)tag withString:(NSString*)value
{
    UILabel* label = (UILabel*)[exampleSubscriptionProductCell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, LABEL_BASE_HEIGHT * (float)label.numberOfLines);
    
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:@{NSFontAttributeName: label.font}
                                              context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    
    if (labelSize.height <= CELL_MIN_HEIGHT)
        return CELL_MIN_HEIGHT;
    else
        return labelSize.height+2.0f;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DataModel* dataModel = [DataModel getInstance];

    if (indexPath.section == 0)
    {
        AccountType accountType = dataModel.globalSettings.accountType;
        if (dataModel.globalSettings.subscriptionExpires &&
            ((accountType == AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0) ||
             (accountType != AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] < 0)))
        {
            return 88;
        }
        else
            return 44;
    }
    else if (indexPath.section == 1)
    {
        return 157;
    }
	else if (indexPath.section == 2)
    {
        if ([self isOfferingFreeTrial] && indexPath.row == 0)
        {
            NSString* trialDescription = NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionTrialDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"Try Dosecast Pro with CloudSync free for 7 days!", @"The edition label in the Settings view"]);
            CGFloat descriptionFieldHeight = (int)ceilf([self getHeightForCellLabel:2 withString:trialDescription]);
            return 93.0f + (descriptionFieldHeight - CELL_MIN_HEIGHT);
        }
        else
        {
            SKProduct* product = (SKProduct*)[[PurchaseManager getInstance].productList objectAtIndex:([self isOfferingFreeTrial] ? indexPath.row-1 : indexPath.row)];
            CGFloat descriptionFieldHeight = (int)ceilf([self getHeightForCellLabel:2 withString:product.localizedDescription]);
            return 93.0f + (descriptionFieldHeight - CELL_MIN_HEIGHT);
        }
	}
	else
		return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 1)
        return 66;
    else if (section == 2)
        return 44;
    else
        return 11;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 1)
	{
        DataModel* dataModel = [DataModel getInstance];

        AccountType accountType = dataModel.globalSettings.accountType;
        if (accountType == AccountTypeSubscription && dataModel.globalSettings.subscriptionExpires && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0)
            return NSLocalizedStringWithDefaultValue(@"ViewAccountExtendSubscriptionMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Extend your subscription to the Pro edition with CloudSync", @"The message to display in the Account view for a demo edition"]);
        else
            return NSLocalizedStringWithDefaultValue(@"ViewAccountPurchaseSubscriptionMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe to the Pro edition with CloudSync", @"The message to display in the Account view for a demo edition"]);
	}
    else if (section == 2)
        return NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionOptionsMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscription Options", @"The message to display in the Account view for a demo edition"]);
	else
		return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


- (void)dealloc {
	[PurchaseManager getInstance].delegate = nil;
}


@end
