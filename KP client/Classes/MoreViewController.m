//
//  MoreViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "MoreViewController.h"
#import "DosecastUtil.h"
#import "DosecastAPI.h"
#import "SpinnerViewController.h"
#import "TermsAndConditionsViewController.h"
#import "SupportViewController.h"

@implementation MoreViewController

@synthesize tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil dosecastAPI:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
          dosecastAPI:(DosecastAPI*)api
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
        dosecastAPI = api;
        
        emailConfirmSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:@"Send History In Email Body",
                             @"Send History In CSV File", nil];
        emailConfirmSheet.actionSheetStyle = UIActionSheetStyleDefault;

        spinnerViewController = [[SpinnerViewController alloc] init];
     
        emailDrugListWarningAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Warning", @"The title on the alert warning when emailing drug info"])
                                                       message:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"If you send this email, the personal health information shared within it will not be protected. Continue if you are sure you want to send this information in an email.", @"The message on the alert warning when emailing drug info"])
                                                      delegate:self
                                                     cancelButtonTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonClose", @"Dosecast", [DosecastUtil getResourceBundle], @"Close", @"The text on the Close button in an alert"])
                                                     otherButtonTitles:NSLocalizedStringWithDefaultValue(@"AlertButtonContinue", @"Dosecast", [DosecastUtil getResourceBundle], @"Continue", @"The text on the Continue button in an alert"]), nil];
        
        emailDrugHistoryWarningAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Warning", @"The title on the alert warning when emailing drug info"])
                                                               message:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"If you send this email, the personal health information shared within it will not be protected. Continue if you are sure you want to send this information in an email.", @"The message on the alert warning when emailing drug info"])
                                                              delegate:self
                                                        cancelButtonTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonClose", @"Dosecast", [DosecastUtil getResourceBundle], @"Close", @"The text on the Close button in an alert"])
                                                        otherButtonTitles:NSLocalizedStringWithDefaultValue(@"AlertButtonContinue", @"Dosecast", [DosecastUtil getResourceBundle], @"Continue", @"The text on the Continue button in an alert"]), nil];
	}
	return self;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    
    if (result == MFMailComposeResultFailed && error != nil)
	{
		NSString* errorAlertMessage = @"Your email could not be sent as a result of the following error: %@.";
		UIAlertView* errorAlert = [[UIAlertView alloc] initWithTitle:@"Error Sending Email"
                                                             message:[NSString stringWithFormat:errorAlertMessage, [error localizedDescription]]
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
		[errorAlert show];
	}
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = @"More";
	
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }

    // Set background image in table
    NSString *backgroundFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], [DosecastUtil getDeviceSpecificFilename:@"/Background.png"]];
    UIImage* image = [[UIImage alloc] initWithContentsOfFile:backgroundFilePath];
    UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeTopLeft;
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    tableView.backgroundView = imageView;

	tableView.sectionHeaderHeight = 8;
	tableView.sectionFooterHeight = 0;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
        self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
        self.navigationController.toolbar.tintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.toolbar.translucent = NO;
    }
    else
    {
        self.navigationController.navigationBar.tintColor = [DosecastUtil getNavigationBarColor];
        self.navigationController.toolbar.tintColor = [DosecastUtil getToolbarColor];
    }
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}

- (NSUInteger)supportedInterfaceOrientations
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

- (void) composeEmailWithHistoryInBody:(NSTimer*)theTimer
{
	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	NSString* body = [dosecastAPI getDrugHistoryString:nil];
    
	NSString* subject = [NSString stringWithFormat:@"Dose History in %@", [DosecastUtil getProductAppName]];
	[mailController setSubject:subject];
	[mailController setMessageBody:body isHTML:NO];
	
    [spinnerViewController hide:NO];
    
    [self.navigationController presentViewController:mailController animated:YES completion:nil];
}

- (void) composeEmailWithCSVHistory:(NSTimer*)theTimer
{
	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	
	NSString* daySingular = @"day";
	NSString* dayPlural = @"days";
	NSString* historyDurationUnit = nil;
    
	if ([DosecastUtil shouldUseSingularForInteger:dosecastAPI.doseHistoryDays])
		historyDurationUnit = daySingular;
	else
		historyDurationUnit = dayPlural;
    
    NSString* personName = @"me";
    
    NSString* subject = [NSString stringWithFormat:@"Dose History in %@", [DosecastUtil getProductAppName]];
    NSData* drugHistoryCSVFile = [dosecastAPI getDrugHistoryCSVFile:nil];
    if (drugHistoryCSVFile)
    {
        NSString* headerForEvents = [NSString stringWithFormat:@"Attached is the dose history for %@ over the last %d %@.", personName, dosecastAPI.doseHistoryDays, historyDurationUnit];
        [mailController setMessageBody:headerForEvents isHTML:NO];
    }
    else
    {
        NSString* headerForNoEvents = [NSString stringWithFormat:@"No dose history for %@ over the last %d %@.", personName, dosecastAPI.doseHistoryDays, historyDurationUnit];
        [mailController setMessageBody:headerForNoEvents isHTML:NO];
    }
	
	[mailController setSubject:subject];
    
	if (drugHistoryCSVFile)
	{
		[mailController addAttachmentData:drugHistoryCSVFile mimeType:@"text/csv" fileName:@"DoseHistory.csv"];
	}
	
    [spinnerViewController hide:NO];
	
    [self.navigationController presentViewController:mailController animated:YES completion:nil];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) // in email body
    {
        spinnerViewController.message = @"Collecting information";
        [spinnerViewController showInView:self.view];
        
        [NSTimer scheduledTimerWithTimeInterval:.3 target:self selector:@selector(composeEmailWithHistoryInBody:) userInfo:nil repeats:NO];
    }
    else if (buttonIndex == 1) // in CSV file
    {
        spinnerViewController.message = @"Collecting information";
        [spinnerViewController showInView:self.view];
        
        [NSTimer scheduledTimerWithTimeInterval:.3 target:self selector:@selector(composeEmailWithCSVHistory:) userInfo:nil repeats:NO];
    }
}

// Button-click callback when UIAlertView appears and "Try Again" button is pressed
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == emailDrugListWarningAlert)
    {
		if (buttonIndex == 1) // Yes
        {
            MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
            mailController.mailComposeDelegate = self;
            NSMutableString* subject = [NSMutableString stringWithFormat:@"%@ Medication List", [DosecastUtil getProductAppName]];
            [mailController setSubject:subject];
            
            NSString* body = [dosecastAPI getDrugListHTMLDescription];
            [mailController setMessageBody:body isHTML:YES];
            [self.navigationController presentViewController:mailController animated:YES completion:nil];
        }
    }
    else if (alertView == emailDrugHistoryWarningAlert)
    {
        if (buttonIndex == 1) // Yes
        {
            UINavigationController* navigationController = self.navigationController;
            
            // Open an action sheet to confirm
            if (navigationController && !navigationController.toolbarHidden)
                [emailConfirmSheet showFromToolbar:navigationController.toolbar];
            else if (navigationController.topViewController.tabBarController)
                [emailConfirmSheet showFromTabBar:navigationController.topViewController.tabBarController.tabBar];
            else
                [emailConfirmSheet showInView:[navigationController.topViewController view]];
        }
    }
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int numRows = 5;
#ifndef APP_STORE
    numRows += 1;
#endif
    return numRows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"MoreCellIdentifier";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MyIdentifier];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    BOOL isAppStoreBuild = YES;
#ifndef APP_STORE
    isAppStoreBuild = NO;
#endif
    
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:15.0];
    if (indexPath.row == 0)
    {
        cell.textLabel.text = @"Terms & conditions";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/icon_terms.png"]];
    }
    else if (indexPath.row == 1)
    {
        cell.textLabel.text = @"Email medication list";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MoreMail.png"]];
    }
    else if (indexPath.row == 2)
    {
        cell.textLabel.text = @"Email medication history";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MoreMail.png"]];
    }
    else if (!isAppStoreBuild && indexPath.row == 3)
    {
        cell.textLabel.text = @"Email debug log";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MoreMail.png"]];        
    }
    else if ((!isAppStoreBuild && indexPath.row == 4) ||
             (isAppStoreBuild && indexPath.row == 3))
    {
        cell.textLabel.text = @"Settings";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/icon_settings.png"]];
    }
    else if ((!isAppStoreBuild && indexPath.row == 5) ||
             (isAppStoreBuild && indexPath.row == 4))
    {
        cell.textLabel.text = @"App support";
        cell.imageView.image = [UIImage imageWithContentsOfFile:
                                [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/icon_support.png"]];        
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

    BOOL isAppStoreBuild = YES;
#ifndef APP_STORE
    isAppStoreBuild = NO;
#endif

    if (indexPath.row == 0)
    {
        UIViewController* vc = [[TermsAndConditionsViewController alloc] init];
        vc.title = @"Terms & conditions";
        
        if ([DosecastUtil getOSVersionFloat] >= 7.0f)
        {
            vc.edgesForExtendedLayout = UIRectEdgeNone;
            vc.automaticallyAdjustsScrollViewInsets = NO;
        }

        [self.navigationController pushViewController:vc animated:YES];
    }
    else if (indexPath.row == 1)
    {
        if (![MFMailComposeViewController canSendMail])
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Can't Send Email"
                                                        message:@"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            [emailDrugListWarningAlert show];
        }
    }
    else if (indexPath.row == 2)
    {
        if (![MFMailComposeViewController canSendMail])
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Can't Send Email"
                                                            message:@"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            [emailDrugHistoryWarningAlert show];
        }
    }
    else if (!isAppStoreBuild && indexPath.row == 3)
    {
        if (![MFMailComposeViewController canSendMail])
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Can't Send Email"
                                                            message:@"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
            mailController.mailComposeDelegate = self;
            NSMutableString* subject = [NSMutableString stringWithFormat:@"%@ Debug Log", [DosecastUtil getProductAppName]];
            [mailController setSubject:subject];
            
            NSData* debugLogCSVFile = [dosecastAPI getDebugLogCSVFile];
            [mailController setMessageBody:[dosecastAPI getKeyDiagnostics] isHTML:NO];
            [mailController addAttachmentData:debugLogCSVFile mimeType:@"text/csv" fileName:@"DebugLog.csv"];
            [self.navigationController presentViewController:mailController animated:YES completion:nil];
        }
    }
    else if ((!isAppStoreBuild && indexPath.row == 4) ||
             (isAppStoreBuild && indexPath.row == 3))
    {
        // Set Back button title
        NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
        UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
        backButton.style = UIBarButtonItemStylePlain;
        if (!backButton.image)
            backButton.title = @"Back";
        self.navigationItem.backBarButtonItem = backButton;
        
        // Push the settings controller
        [self.navigationController pushViewController:[dosecastAPI createSettingsViewController] animated:YES];
    }
    else if ((!isAppStoreBuild && indexPath.row == 5) ||
             (isAppStoreBuild && indexPath.row == 4))
    {
        UIViewController* vc = [[SupportViewController alloc] init];
        vc.title = @"App support";
        
        if ([DosecastUtil getOSVersionFloat] >= 7.0f)
        {
            vc.edgesForExtendedLayout = UIRectEdgeNone;
            vc.automaticallyAdjustsScrollViewInsets = NO;
        }

        [self.navigationController pushViewController:vc animated:YES];
    }
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
