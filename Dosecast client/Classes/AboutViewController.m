//
//  AboutViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "AboutViewController.h"
#import "DosecastUtil.h"
#import "PrivacyPolicyViewController.h"
#import "TermsOfServiceViewController.h"
#import "WhatsNewViewController.h"
#import "DosecastAPI.h"
#import "DosecastAPIDelegate.h"
#import "PersistentFlags.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

@implementation AboutViewController

@synthesize tableView;
@synthesize productInfoCell;
@synthesize termsOfServiceCell;
@synthesize privacyPolicyCell;
@synthesize feedbackCell;
@synthesize websiteCell;
@synthesize whatsNewCell;
@synthesize writeReviewCell;
@synthesize tellFriendCell;
@synthesize facebookCell;
@synthesize twitterCell;
@synthesize reportProblemCell;
@synthesize faqCell;

// The different UI sections & rows
typedef enum {
	AboutViewControllerSectionsProductInfo = 0,
    AboutViewControllerSectionsWhatsNew    = 1,
    AboutViewControllerSectionsWordOfMouth = 2,
    AboutViewControllerSectionsFeedback    = 3,
    AboutViewControllerSectionsLinks       = 4,
    AboutViewControllerSectionsTerms       = 5
} AboutViewControllerSections;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil dosecastAPI:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dosecastAPI:(DosecastAPI*)a
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
        api = a;
	}
	return self;    
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSString* titleText = NSLocalizedStringWithDefaultValue(@"ViewAboutTitle", @"Dosecast-client", [NSBundle mainBundle], @"About %@", @"The title of the About view"]);
	self.title = [NSString stringWithFormat:titleText, [DosecastUtil getProductAppName]];
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    self.view.backgroundColor = [DosecastUtil getViewBackgroundColor];

    tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
    tableViewSections = [[NSMutableArray alloc] init];
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.tableView.backgroundColor = [UIColor clearColor];
		
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
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

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	if (result == MFMailComposeResultFailed && error != nil)
	{
		NSString* errorAlertTitle = NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Error Sending Email", @"The title of the alert when an error occurs sending an email"]);
		NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your email could not be sent as a result of the following error: %@.", @"The message of the alert when an email can't be sent"]);
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:errorAlertTitle message:[NSString stringWithFormat:errorAlertMessage, [error localizedDescription]] style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          [self dismissViewControllerAnimated:YES completion:nil];
                                      }]];
        
		[alert showInViewController:self];
	}
    else
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [tableViewSections removeAllObjects];
        
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsProductInfo]];
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsWhatsNew]];
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsWordOfMouth]];
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsFeedback]];
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsLinks]];
    [tableViewSections addObject:[NSNumber numberWithInt:AboutViewControllerSectionsTerms]];

	return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
    AboutViewControllerSections controllerSection = (AboutViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == AboutViewControllerSectionsProductInfo)
        return 1;
    else if (controllerSection == AboutViewControllerSectionsWhatsNew)
        return 1;
    else if (controllerSection == AboutViewControllerSectionsWordOfMouth)
        return 2;
    else if (controllerSection == AboutViewControllerSectionsFeedback)
        return 3;
    else if (controllerSection == AboutViewControllerSectionsLinks)
        return 3;
    else // controllerSection == AboutViewControllerSectionsTerms
        return 2;    
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AboutViewControllerSections controllerSection = (AboutViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (controllerSection == AboutViewControllerSectionsProductInfo)
	{
        UIView* containerView = [productInfoCell viewWithTag:1];
        containerView.backgroundColor = [UIColor clearColor];

		UILabel* productNameLabel = (UILabel*)[containerView viewWithTag:2];
		productNameLabel.text = [DosecastUtil getProductAppName];
		UILabel* versionLabel = (UILabel*)[containerView viewWithTag:3];
		versionLabel.text = api.productVersion;
		UILabel* accountIDLabel = (UILabel*)[containerView viewWithTag:4];
		NSString* accountIDText = NSLocalizedStringWithDefaultValue(@"ViewAboutAccountID", @"Dosecast-client", [NSBundle mainBundle], @"Account ID: %@", @"The account ID displayed in the About view"]);
		accountIDLabel.text = [NSString stringWithFormat:accountIDText, api.userIDAbbrev];

        UILabel* editionLabel = (UILabel*)[containerView viewWithTag:5];
        NSString* editionStr = nil;
        AccountType accountType = api.accountType;
        if (accountType == AccountTypeDemo)
            editionStr = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionDemo", @"Dosecast", [DosecastUtil getResourceBundle], @"Free", @"The demo edition label in the Settings view"]);
        else if (accountType == AccountTypePremium)
            editionStr = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPremium", @"Dosecast", [DosecastUtil getResourceBundle], @"Premium", @"The Premium edition label in the Settings view"]);
        else
            editionStr = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPro", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro with CloudSync", @"The Premium edition label in the Settings view"]);
        editionLabel.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedStringWithDefaultValue(@"ViewSettingsEdition", @"Dosecast", [DosecastUtil getResourceBundle], @"Edition", @"The edition label in the Settings view"]), editionStr];

		UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		productInfoCell.backgroundView = backView;
        productInfoCell.backgroundColor = [UIColor clearColor];

		return productInfoCell;
	}
    else if (controllerSection == AboutViewControllerSectionsWhatsNew)
	{
		UILabel* whatsNewLabel = (UILabel*)[whatsNewCell viewWithTag:1];
		whatsNewLabel.text = NSLocalizedStringWithDefaultValue(@"ViewWhatsNewTitle", @"Dosecast-client", [NSBundle mainBundle], @"What's New", @"Title of About => What's New view"]);
		return whatsNewCell;
	}		
    else if (controllerSection == AboutViewControllerSectionsWordOfMouth)
	{
		if (indexPath.row == 0)
		{
			UILabel* writeReviewLabel = (UILabel*)[writeReviewCell viewWithTag:1];
			writeReviewLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutWriteReview", @"Dosecast-client", [NSBundle mainBundle], @"Write a Review", @"The About view cell for writing a review in the App Store"]);
			return writeReviewCell;
		}
		else // if (indexPath.row == 1)
		{
			UILabel* tellFriendLabel = (UILabel*)[tellFriendCell viewWithTag:1];
			tellFriendLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutTellFriend", @"Dosecast-client", [NSBundle mainBundle], @"Tell a Friend", @"The About view cell for telling a friend about this app"]);
			return tellFriendCell;			
		}
	}		
    else if (controllerSection == AboutViewControllerSectionsFeedback)
	{
		if (indexPath.row == 0)
		{
			UILabel* feedbackLabel = (UILabel*)[feedbackCell viewWithTag:1];
			feedbackLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedback", @"Dosecast-client", [NSBundle mainBundle], @"Send Feedback", @"The About view cell for sending feedback"]);
			return feedbackCell;
		}
		else if (indexPath.row == 1)
		{
			UILabel* label = (UILabel*)[reportProblemCell viewWithTag:1];
			label.text = NSLocalizedStringWithDefaultValue(@"ViewAboutReportProblem", @"Dosecast-client", [NSBundle mainBundle], @"Report a Problem", @"The About view cell for reporting a problem"]);
			return reportProblemCell;			
		}
		else // if (indexPath.row == 2)
		{
			UILabel* label = (UILabel*)[faqCell viewWithTag:1];
			label.text = NSLocalizedStringWithDefaultValue(@"ViewAboutFAQ", @"Dosecast-client", [NSBundle mainBundle], @"View Frequently Asked Questions", @"The About view cell for frequently asked questions"]);
			return faqCell;						
		}
	}
    else if (controllerSection == AboutViewControllerSectionsLinks)
	{
		if (indexPath.row == 0)
		{
			UILabel* cellLabel = (UILabel*)[facebookCell viewWithTag:1];
			cellLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutFacebook", @"Dosecast-client", [NSBundle mainBundle], @"Join Us on Facebook", @"The About view cell for visiting Facebook page"]);
			return facebookCell;		
		}
		else if (indexPath.row == 1)
		{
			UILabel* cellLabel = (UILabel*)[twitterCell viewWithTag:1];
			cellLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutTwitter", @"Dosecast-client", [NSBundle mainBundle], @"Follow Us on Twitter", @"The About view cell for visiting Twitter page"]);
			return twitterCell;							
		}
		else // if (indexPath.row == 2)
		{
			UILabel* websiteLabel = (UILabel*)[websiteCell viewWithTag:1];
			websiteLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutWebsite", @"Dosecast-client", [NSBundle mainBundle], @"Visit Website", @"The About view cell for visiting app website"]);
			return websiteCell;			
		}
	}
    else if (controllerSection == AboutViewControllerSectionsTerms)
	{
		if (indexPath.row == 0)
		{
			UILabel* termsOfServiceLabel = (UILabel*)[termsOfServiceCell viewWithTag:1];
			termsOfServiceLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutTermsOfService", @"Dosecast-client", [NSBundle mainBundle], @"View Terms of Service", @"The About view cell for viewing the terms of service"]);
			return termsOfServiceCell;
		}
		else // if (indexPath.row == 1)
		{
			UILabel* privacyPolicyLabel = (UILabel*)[privacyPolicyCell viewWithTag:1];
			privacyPolicyLabel.text = NSLocalizedStringWithDefaultValue(@"ViewAboutPrivacyPolicy", @"Dosecast-client", [NSBundle mainBundle], @"View Privacy Policy", @"The About view cell for viewing the privacy policy"]);
			return privacyPolicyCell;			
		}
	}
	else
		return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AboutViewControllerSections controllerSection = (AboutViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (controllerSection == AboutViewControllerSectionsProductInfo)
		return 100;
	else
		return 44;

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    AboutViewControllerSections controllerSection = (AboutViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == AboutViewControllerSectionsWhatsNew)
		return NSLocalizedStringWithDefaultValue(@"ViewAboutWhatsNewDescription", @"Dosecast-client", [NSBundle mainBundle], @"Check out the list of enhancements in recent versions.", @"The description under the About view's What's New cell"]);
    else if (controllerSection == AboutViewControllerSectionsWordOfMouth)
	{
		NSString* tellFriendMessage = NSLocalizedStringWithDefaultValue(@"ViewAboutWriteReviewTellFriendDescription", @"Dosecast-client", [NSBundle mainBundle], @"If you like %@, please consider writing a short review or telling a friend. It will help others discover this app and give us a pat on the back!", @"The description under the About view's Write a Review and Tell a Friend cells"]);
		return [NSString stringWithFormat:tellFriendMessage, [DosecastUtil getProductAppName]];
	}
    else if (controllerSection == AboutViewControllerSectionsFeedback)
		return NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedbackDescription", @"Dosecast-client", [NSBundle mainBundle], @"Please contact us with comments, suggestions, or problems you encounter. We'd love to hear from you!", @"The description under the About view's Send Feedback cell"]);
    else if (controllerSection == AboutViewControllerSectionsLinks)
		return NSLocalizedStringWithDefaultValue(@"ViewAboutFacebookTwitterDescription", @"Dosecast-client", [NSBundle mainBundle], @"Join us on Facebook or follow us on Twitter to weigh-in on future enhancements and get a sneak peak at our next update!", @"The description under the About view's Facebook and Twitter cells"]);
    else if (controllerSection == AboutViewControllerSectionsTerms)
	{
		NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		NSDate* now = [NSDate date];
		unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;		
		NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
        
		NSString* copyrightText = NSLocalizedStringWithDefaultValue(@"ViewAboutCopyright", @"Dosecast-client", [NSBundle mainBundle], @"Copyright © %d Montuno Software, LLC\nwww.dosecast.com", @"The copyright at the bottom of the About view"]);
		return [NSString stringWithFormat:copyrightText, [todayComponents year]];	
	}
	else
		return nil;
}

- (void) setMailComposeViewControllerColors:(MFMailComposeViewController*)mailController
{
    NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:mailController.navigationBar.titleTextAttributes];
    [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    
    mailController.navigationBar.titleTextAttributes = titleTextAttributes;
    
    [mailController.navigationBar setBarTintColor:[DosecastUtil getNavigationBarColor]];
    [mailController.navigationBar setTintColor:[UIColor whiteColor]];
}

- (void) composeProblemReportEmail:(NSTimer*)theTimer
{
	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	NSString* subjectText = NSLocalizedStringWithDefaultValue(@"ViewAboutReportProblemSubject", @"Dosecast-client", [NSBundle mainBundle], @"%@ Problem Report (Account ID %@)", @"The subject of the problem report email sent from the About view"]);
	
	NSMutableString* subject = [NSMutableString stringWithFormat:subjectText, [DosecastUtil getProductAppName], api.userIDAbbrev];
	[mailController setSubject:subject];
	NSString* emailAddress = NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedbackEmailAddress", @"Dosecast-client", [NSBundle mainBundle], @"info@montunosoftware.com", @"The email address to send to in the feedback email sent from the About view"]);
	[mailController setToRecipients:[NSArray arrayWithObject:[NSString stringWithString:emailAddress]]];
	
	NSMutableString* body = [NSMutableString stringWithFormat:@""];
    [body appendString:@"<p>"];
    [body appendString:[[api getKeyDiagnostics] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />"]];
	[body appendFormat:@"<br />"];
	
	NSData* debugLogCSVFile = [api getDebugLogCSVFile];
	if (debugLogCSVFile)
		[mailController addAttachmentData:debugLogCSVFile mimeType:@"text/csv" fileName:@"DebugLog.csv"];
	else
		[body appendFormat:@"<br />%@<br />", NSLocalizedStringWithDefaultValue(@"ViewAboutReportProblemNoLogMessage", @"Dosecast-client", [NSBundle mainBundle], @"No debug log events exist.", @"The message appearing when no debug log events exist and the user sends a problem report from the About view"])];
	[body appendString:@"</p>"];
	[mailController setMessageBody:body isHTML:YES];
	
    [api.delegate allowDosecastUserInteractionsWithMessage:NO];
	   
    [self setMailComposeViewControllerColors:mailController];
    
    [self presentViewController:mailController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

    AboutViewControllerSections controllerSection = (AboutViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (controllerSection == AboutViewControllerSectionsWhatsNew)
	{
		// Set Back button title
        NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
        UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
        backButton.style = UIBarButtonItemStylePlain;
        if (!backButton.image)
            backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
		self.navigationItem.backBarButtonItem = backButton;
		
		// Display about
		WhatsNewViewController* whatsNewController = [[WhatsNewViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"WhatsNewViewController"] bundle:[NSBundle mainBundle]];
		[self.navigationController pushViewController:whatsNewController animated:YES];
	}	
    else if (controllerSection == AboutViewControllerSectionsWordOfMouth)
	{
		if (indexPath.row == 0)
		{
			// Remember that the user wrote a review
			if (![api getPersistentFlag:PersistentFlagWroteReview])
                [api setPersistentFlag:PersistentFlagWroteReview value:YES];
			
			NSString* url = NSLocalizedStringWithDefaultValue(@"ViewAboutWriteReviewURL", @"Dosecast-client", [NSBundle mainBundle], @"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=365191644&pageNumber=0&sortOrdering=1&type=Purple+Software&mt=8", @"The URL of the Write a Review page linked from the About view"]);
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
		}
		else // if (indexPath.row == 1)
		{
			if (![MFMailComposeViewController canSendMail])
			{
				NSString* errorAlertTitle = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"]);
				NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"]);

                DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:errorAlertTitle
                                                                                                   message:errorAlertMessage];
				[alert showInViewController:self];
			}
			else
			{
				MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
				mailController.mailComposeDelegate = self;
				[mailController setSubject:[NSString stringWithFormat:@"%@", [DosecastUtil getProductAppName]]];
				NSMutableString* url = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewAboutAppStoreListingURL", @"Dosecast-client", [NSBundle mainBundle], @"http://itunes.apple.com/us/app/dosecast/id365191644?mt=8", @"The URL of the App Store listing when telling a friend from the About view"])];

                // Make the URL country-specific by replacing '/us/' with '/<country code>/'
                [url replaceOccurrencesOfString:@"/us/" withString:[NSString stringWithFormat:@"/%@/", [[DosecastUtil getCountryCode] lowercaseString]] options:NSLiteralSearch range:NSMakeRange(0,[url length])];
                
				NSString* tellFriendText = NSLocalizedStringWithDefaultValue(@"ViewAboutTellFriendText", @"Dosecast-client", [NSBundle mainBundle], @"Check out this application:\n\n%@", @"The text appearing in the email to tell a friend from the About view"]);
				[mailController setMessageBody:[NSString stringWithFormat:tellFriendText, url] isHTML:NO];
				
                [self setMailComposeViewControllerColors:mailController];

                [self presentViewController:mailController animated:YES completion:nil];
			}
		}
	}	
    else if (controllerSection == AboutViewControllerSectionsFeedback)
	{
		if (indexPath.row == 0)
		{
			if (![MFMailComposeViewController canSendMail])
			{
				NSString* errorAlertTitle = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"]);
				NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"]);

                DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:errorAlertTitle
                                                                                                   message:errorAlertMessage];
				[alert showInViewController:self];
			}
			else
			{
				MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
				mailController.mailComposeDelegate = self;
				NSString* subjectText = NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedbackSubject", @"Dosecast-client", [NSBundle mainBundle], @"%@ Feedback (Account ID %@)", @"The subject of the feedback email sent from the About view"]);

				NSMutableString* subject = [NSMutableString stringWithFormat:subjectText, [DosecastUtil getProductAppName], api.userIDAbbrev];
				[mailController setSubject:subject];
				NSString* emailAddress = NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedbackEmailAddress", @"Dosecast-client", [NSBundle mainBundle], @"info@montunosoftware.com", @"The email address to send to in the feedback email sent from the About view"]);
				[mailController setToRecipients:[NSArray arrayWithObject:[NSString stringWithString:emailAddress]]];

                NSString* writeInEnglishText = NSLocalizedStringWithDefaultValue(@"ViewAboutSendFeedbackText", @"Dosecast-client", [NSBundle mainBundle], @"Please write to us in English.", @"The text appearing in the feedback email sent from the About view"]);
				[mailController setMessageBody:writeInEnglishText isHTML:NO];

                [self setMailComposeViewControllerColors:mailController];

                [self presentViewController:mailController animated:YES completion:nil];
			}
		}
		else if (indexPath.row == 1)
		{
			if (![MFMailComposeViewController canSendMail])
			{
				NSString* errorAlertTitle = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"]);
				NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"]);

                DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:errorAlertTitle
                                                                                                   message:errorAlertMessage];
				[alert showInViewController:self];
			}
			else
			{
				[api.delegate disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerCollectingInformation", @"Dosecast", [DosecastUtil getResourceBundle], @"Collecting information", @"The message appearing in the spinner view when collecting information"])];
				
				[NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(composeProblemReportEmail:) userInfo:nil repeats:NO];
			}					
		}
		else // if (indexPath.row == 2)
		{
			NSString* url = NSLocalizedStringWithDefaultValue(@"ViewAboutFAQURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.dosecast.com/faq.html", @"The URL of the FAQ page linked from the About view"]);
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
		}
	}
    else if (controllerSection == AboutViewControllerSectionsLinks)
	{
		if (indexPath.row == 0)
		{
			NSString* url = NSLocalizedStringWithDefaultValue(@"ViewAboutFacebookURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.facebook.com/pages/Dosecast/143374575706386", @"The URL of the Facebook page linked from the About view"]);
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
		}
		else if (indexPath.row == 1)
		{
			NSString* url = NSLocalizedStringWithDefaultValue(@"ViewAboutTwitterURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.twitter.com/dosecast", @"The URL of the Twitter page linked from the About view"]);
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
		}
		else // if (indexPath.row == 2)
		{
			NSString* url = NSLocalizedStringWithDefaultValue(@"ViewAboutWebsiteURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.dosecast.com", @"The URL of the website linked from the About view"]);
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
		}
	}	
    else if (controllerSection == AboutViewControllerSectionsTerms)
	{
		if (indexPath.row == 0)
		{
            // Set Back button title
            NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
            UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
            backButton.style = UIBarButtonItemStylePlain;
            if (!backButton.image)
                backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
            self.navigationItem.backBarButtonItem = backButton;
			
			// Display terms of service in new view
			TermsOfServiceViewController* termsOfServiceController = [[TermsOfServiceViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TermsOfServiceViewController"] bundle:[NSBundle mainBundle] dosecastAPI:api];
			[self.navigationController pushViewController:termsOfServiceController animated:YES];
		}
		else // if (indexPath.row == 1)
		{
            // Set Back button title
            NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
            UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
            backButton.style = UIBarButtonItemStylePlain;
            if (!backButton.image)
                backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
            self.navigationItem.backBarButtonItem = backButton;
			
			// Display privacy policy in new view
			PrivacyPolicyViewController* privacyPolicyController = [[PrivacyPolicyViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PrivacyPolicyViewController"] bundle:[NSBundle mainBundle] dosecastAPI:api];
			[self.navigationController pushViewController:privacyPolicyController animated:YES];
		}
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
