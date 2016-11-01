//
//  SyncMoveDeviceViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "SyncMoveDeviceViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "ServerProxy.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const CGFloat LABEL_BASE_HEIGHT = 18.0f;
static const CGFloat CELL_MIN_HEIGHT = 40.0f;
static const CGFloat WARNING_MARGIN = 20.0f;
static const CGFloat INSTRUCTIONS_MARGIN = 20.0f;

@implementation SyncMoveDeviceViewController

@synthesize tableView;
@synthesize instructionsCell;
@synthesize syncCodeCell;
@synthesize warningCell;
@synthesize submitCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        self.hidesBottomBarWhenPushed = YES;
        syncCode = nil;
        

    }
    return self;
}

- (void)dealloc {
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Move Device", @"The title of the Sync Move Device view"]);
		
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
    // Set Cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	tableView.allowsSelection = YES;
}

- (IBAction)handleCancel:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)sender
{
    CGSize kbSize = [[[sender userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [[[sender userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, kbSize.height, 0);
        [tableView setContentInset:edgeInsets];
        [tableView setScrollIndicatorInsets:edgeInsets];
    }];
}

- (void)keyboardWillHide:(NSNotification *)sender
{
    NSTimeInterval duration = [[[sender userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        UIEdgeInsets edgeInsets = UIEdgeInsetsZero;
        [tableView setContentInset:edgeInsets];
        [tableView setScrollIndicatorInsets:edgeInsets];
    }];
}

- (void)syncServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

    if (status == ServerProxySuccess)
    {
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil message:NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceSuccessMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The text on the OK button in an alert"]) style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          [self.navigationController popToRootViewControllerAnimated:YES];
                                      }]];

        [alert showInViewController:self];
    }
    else if (status != ServerProxyDeviceDetached)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)submitRendezvousCodeServerProxyResponse:(ServerProxyStatus)status rendezvousResult:(NSString*)rendezvousResult errorMessage:(NSString*)errorMessage
{
    if (status == ServerProxySuccess)
    {
        if (rendezvousResult && [rendezvousResult isEqualToString:@"success"])
        {
            [[ServerProxy getInstance] sync:self];
        }
        else
        {
            [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

            NSString* alertMessage = nil;

            if (rendezvousResult && [rendezvousResult isEqualToString:@"noSuchCode"])
                alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSyncMoveDeviceNoSuchCode", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title on the alert appearing when a general error occurs"]);
            else if (rendezvousResult && [rendezvousResult isEqualToString:@"expired"])
                alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSyncMoveDeviceExpired", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title on the alert appearing when a general error occurs"]);
            else if (rendezvousResult && [rendezvousResult isEqualToString:@"alreadyUsed"])
                alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSyncMoveDeviceAlreadyUsed", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title on the alert appearing when a general error occurs"]);
            else // if (rendezvousResult && [rendezvousResult isEqualToString:@"selfRedemption"])
                alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSyncMoveDeviceSelfRedemption", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title on the alert appearing when a general error occurs"]);
            
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:alertMessage];
            [alert showInViewController:self];
        }
    }
    else if (status != ServerProxyDeviceDetached)
    {
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)showKeyboard
{
    UITextField *textField = (UITextField*)[syncCodeCell viewWithTag:1];
    [textField becomeFirstResponder];
}

- (void)hideKeyboard
{
    UITextField *textField = (UITextField*)[syncCodeCell viewWithTag:1];
    if ([textField isFirstResponder])
        [textField resignFirstResponder];
}

// Callback when user presses Return button on keyboard when editing a text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self hideKeyboard];
    return YES;
}

- (IBAction)handleSubmit:(id)sender
{
    UITextField *textField = (UITextField*)[syncCodeCell viewWithTag:1];
    NSString* code = textField.text;
    if ([code length] == 0)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorSyncMoveDeviceNoCodeEntered", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter the sync code.", @"The title on the alert appearing when a sync error occurs"])];
        [alert showInViewController:self];
    }
    else
    {
        syncCode = code;
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceConfirmation", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title of the confirmation alert in the Sync Move Device view"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:nil]];

        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Move Device", @"The title of the Sync Move Device view"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction* action){
                                          [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingAccount", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating account", @"The message appearing in the spinner view when updating the account"])];
                                          
                                          [[ServerProxy getInstance] submitRendezvousCode:syncCode respondTo:self];
                                          
                                          syncCode = nil;
                                      }]];

        [alert showInViewController:self];
    }
}

- (void) recalcDynamicCellWidths
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
    instructionsCell.frame = CGRectMake(instructionsCell.frame.origin.x, instructionsCell.frame.origin.y, screenWidth, instructionsCell.frame.size.height);
    [instructionsCell layoutIfNeeded];
    warningCell.frame = CGRectMake(warningCell.frame.origin.x, warningCell.frame.origin.y, screenWidth, warningCell.frame.size.height);
    [warningCell layoutIfNeeded];
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

    if ( animated )
        [self.tableView reloadData];
    
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

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcDynamicCellWidths];
    
	return 3;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 2;
    else
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        if (indexPath.row == 0)
        {
            UILabel* warning = (UILabel*)[warningCell viewWithTag:1];
            warning.textColor = [DosecastUtil getDrugWarningLabelColor];
            warning.text = NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceWarning", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The warning in the Sync Move Device view"]);
            return warningCell;
        }
        else // if (indexPath.row == 1)
        {
            UILabel* warning = (UILabel*)[instructionsCell viewWithTag:1];
            warning.text = [NSString stringWithFormat:
                                 NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceInstructions", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The instructions in the Sync Add Device view"]),
                                 [DosecastUtil getProductAppName]];
            return instructionsCell;
        }
    }
    else if (indexPath.section == 1)
    {
        UITextField *textField = (UITextField*)[syncCodeCell viewWithTag:1];
        
        // Initialize the properties of the cell
        textField.text = @"";
        textField.placeholder = nil;
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.secureTextEntry = NO;
        
        return syncCodeCell;
    }
    else if (indexPath.section == 2)
    {
        UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
        backView.backgroundColor = [UIColor clearColor];
        submitCell.backgroundView = backView;
        submitCell.backgroundColor = [UIColor clearColor];
        
        // Dynamically set the color of the button if an image isn't already set.
        UIButton* button = (UIButton *)[submitCell viewWithTag:1];
        UIImage* buttonImage = button.currentImage;
        if (!buttonImage)
        {
            [button setTitle:NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceSubmitText", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The submit button text in the Sync Move Device view"]) forState:UIControlStateNormal];
            [DosecastUtil setBackgroundColorForButton:button color:[DosecastUtil getArchiveButtonColor]];
        }
        
        return submitCell;
    }
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
}

- (CGFloat) getHeightForCellLabel:(UITableViewCell*)cell tag:(int)tag withString:(NSString*)value
{
    UILabel* label = (UILabel*)[cell viewWithTag:tag];
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
    if (indexPath.section == 0)
    {
        if (indexPath.row == 0)
        {
            CGFloat height = (int)ceilf([self getHeightForCellLabel:warningCell tag:1 withString:
                                         NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceWarning", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The warning in the Sync Move Device view"])]);
            height += WARNING_MARGIN;
            return height;
        }
        else // if (indexPath.row == 1)
        {
            NSString* instructions = [NSString stringWithFormat:
                            NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceInstructions", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The instructions in the Sync Add Device view"]),
                            [DosecastUtil getProductAppName]];

            CGFloat height = (int)ceilf([self getHeightForCellLabel:instructionsCell tag:1 withString:instructions]);
            height += INSTRUCTIONS_MARGIN;
            return height;
        }
    }
	else
		return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1)
        return NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceSyncCode", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The sync code in the Sync Move Device view"]);
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return nil;
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

@end
