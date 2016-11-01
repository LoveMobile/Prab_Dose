//
//  GNCDosecastAPI.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "GNCDosecastAPI.h"
#import "DosecastAPI.h"
#import "DosecastAPIDelegate.h"
#import "DosecastAPIFlags.h"
#import "DosecastUtil.h"
#import "DrugDosageManager.h"
#import "SupplementBarDrugDosage.h"
#import "SupplementChewDrugDosage.h"
#import "SupplementDrinkDrugDosage.h"
#import "SupplementGelDrugDosage.h"
#import "SupplementPakDrugDosage.h"
#import "SupplementScoopDrugDosage.h"
#import "SupplementServingDrugDosage.h"
#import "SupplementShotDrugDosage.h"

@implementation GNCDosecastAPI

- (void)handleSettingsToolbarButton:(id)sender {
    
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
	mainViewController.navigationItem.backBarButtonItem = backButton;
	
	// Display settings
	UIViewController* settingsController = [dosecastAPI createSettingsViewController];
	[[dosecastAPI.delegate getUINavigationController] pushViewController:settingsController animated:YES];
}

- (void)handleHistoryToolbarButton:(id)sender
{
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
    mainViewController.navigationItem.backBarButtonItem = backButton;
                
    [[dosecastAPI.delegate getUINavigationController] pushViewController:[dosecastAPI createHistoryViewController:nil] animated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    if ([DosecastUtil getOSVersionFloat] >= 6.0f)
        [[dosecastAPI.delegate getUINavigationController] dismissViewControllerAnimated:YES completion:nil];
    else
        [[dosecastAPI.delegate getUINavigationController] dismissModalViewControllerAnimated:YES];

	if (result == MFMailComposeResultFailed && error != nil)
	{
		NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your email could not be sent as a result of the following error: %@.", @"The message of the alert when an email can't be sent"]);
		UIAlertView* errorAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Error Sending Email", @"The title of the alert when an error occurs sending an email"])
                                                             message:[NSString stringWithFormat:errorAlertMessage, [error localizedDescription]]
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                                   otherButtonTitles:nil];
		[errorAlert show];
	}	
}

- (void)handleEmailToolbarButton:(id)sender
{
	if (![MFMailComposeViewController canSendMail])
	{
		UIAlertView* errorAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"])
                                                             message:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"])
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                                   otherButtonTitles:nil];
		[errorAlert show];
	}
	else
	{
		MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
		mailController.mailComposeDelegate = self;
		NSMutableString* subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugListSubject", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ Drug List", @"The subject line of the drug list email"]), [DosecastUtil getProductAppName]];
		[mailController setSubject:subject];
        
		NSString* body = [dosecastAPI getDrugListHTMLDescription];
		[mailController setMessageBody:body isHTML:YES];
        if ([DosecastUtil getOSVersionFloat] >= 6.0f)
            [[dosecastAPI.delegate getUINavigationController] presentViewController:mailController animated:YES completion:nil];
        else
            [[dosecastAPI.delegate getUINavigationController] presentModalViewController:mailController animated:YES];
	}	
}

- (void) setupMainToolbar
{
    // Setup toolbar with buttons
	NSString *mailIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Mail.png"];
	UIImage* mailIconImage = [[UIImage alloc] initWithContentsOfFile:mailIconFilePath];
	UIBarButtonItem *mailButton = [[UIBarButtonItem alloc] initWithImage:mailIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleEmailToolbarButton:)];
    NSString *logIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Log.png"];
	UIImage* logIconImage = [[UIImage alloc] initWithContentsOfFile:logIconFilePath];
	UIBarButtonItem *logButton = [[UIBarButtonItem alloc] initWithImage:logIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleHistoryToolbarButton:)];
    NSString *gearIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Gear.png"];
	UIImage* gearIconImage = [[UIImage alloc] initWithContentsOfFile:gearIconFilePath];
	UIBarButtonItem *gearButton = [[UIBarButtonItem alloc] initWithImage:gearIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleSettingsToolbarButton:)];
    
	UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *flexSpaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *flexSpaceButton3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *flexSpaceButton4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
    mainViewController.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, logButton, flexSpaceButton2, mailButton, flexSpaceButton3, gearButton, flexSpaceButton4, nil];
}

-(id)init
{
	return [self initWithDelegate:nil launchOptions:nil productVersion:nil];
}

// Initializer with delegate and launch options. After initializing, the client must wait until the delegate's
// handleDosecastUIInitializationComplete method is called before displaying any of this object's view controllers.
-(id)initWithDelegate:(NSObject<DosecastAPIDelegate>*)del
        launchOptions:(NSDictionary*)launchOptions
       productVersion:(NSString*)productVersion // The launchOptions passed to the ApplicationDelegate's didFinishLaunchingWithOptions method
{
    if ((self = [super init]))
    {
        NSArray* apiFlags = [NSArray arrayWithObjects:
                             DosecastAPITrackRemainingQuantities,
                             DosecastAPIShowMainToolbar,
                             DosecastAPIShowDrugInfoToolbar,
                             DosecastAPIShowHistoryToolbar,
                             DosecastAPIEnableShowDrugNamesInNotifications,
                             DosecastAPIShowDrugNamesInNotificationsByDefault,
                             DosecastAPIEnableShowArchivedDrugs,
                             DosecastAPIEnableShowDrugImages,
                             nil];
        
        // Customize drug dosage types
        DrugDosageManager* drugDosageManager = [DrugDosageManager getInstanceWithAPIFlags:apiFlags];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementBarDrugDosage class] typeName:[SupplementBarDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementBarDrugDosage class] fileTypeName:[SupplementBarDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementChewDrugDosage class] typeName:[SupplementChewDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementChewDrugDosage class] fileTypeName:[SupplementChewDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementDrinkDrugDosage class] typeName:[SupplementDrinkDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementDrinkDrugDosage class] fileTypeName:[SupplementDrinkDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementGelDrugDosage class] typeName:[SupplementGelDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementGelDrugDosage class] fileTypeName:[SupplementGelDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementPakDrugDosage class] typeName:[SupplementPakDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementPakDrugDosage class] fileTypeName:[SupplementPakDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementScoopDrugDosage class] typeName:[SupplementScoopDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementScoopDrugDosage class] fileTypeName:[SupplementScoopDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementServingDrugDosage class] typeName:[SupplementServingDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementServingDrugDosage class] fileTypeName:[SupplementServingDrugDosage getFileTypeName]];
        
        [drugDosageManager registerDrugDosageWithTypeName:[SupplementShotDrugDosage class] typeName:[SupplementShotDrugDosage getTypeName]];
        [drugDosageManager registerDrugDosageWithFileTypeName:[SupplementShotDrugDosage class] fileTypeName:[SupplementShotDrugDosage getFileTypeName]];
        
        [drugDosageManager setStandardTypeNames:[NSArray arrayWithObjects:
                                                 [[SupplementBarDrugDosage class] getTypeName],
                                                 [[SupplementChewDrugDosage class] getTypeName],
                                                 [[SupplementDrinkDrugDosage class] getTypeName],
                                                 [[SupplementGelDrugDosage class] getTypeName],
                                                 [[SupplementPakDrugDosage class] getTypeName],
                                                 DrugDosageManagerPillDrugDosageTypeName,
                                                 [[SupplementScoopDrugDosage class] getTypeName],
                                                 [[SupplementServingDrugDosage class] getTypeName],
                                                 [[SupplementShotDrugDosage class] getTypeName], nil]
                                defaultTypeName:DrugDosageManagerPillDrugDosageTypeName];
        
        // Construct API interface
        dosecastAPI = [DosecastAPIFactory createDosecastAPIInstanceWithDelegate:del
                                                                  launchOptions:launchOptions
                                                                       userData:nil
                                                                       apiFlags:apiFlags
                                                                persistentFlags:[NSArray arrayWithObjects:
                                                                                 nil]
                                                                 productVersion:productVersion];
        
        mainViewController = [dosecastAPI createMainViewController];
        [self setupMainToolbar];
    }
    
	return self;
}

// Called to register the user
- (void)registerUser
{
    [dosecastAPI registerUser];
}

-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
    [dosecastAPI didRegisterForRemoteNotificationsWithDeviceToken:devToken];
}

- (void)didReceiveLocalNotification:(UILocalNotification *)notification
{
	[dosecastAPI didReceiveLocalNotification:notification];
}

-(void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [dosecastAPI didRegisterUserNotificationSettings:notificationSettings];
}

-(void)didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;
{
    [dosecastAPI didReceiveRemoteNotification:userInfo fetchCompletionHandler:handler];
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
	[dosecastAPI didFailToRegisterForRemoteNotificationsWithError:err];
}

-(void)applicationDidEnterBackground:(UIApplication *)application
{
    [dosecastAPI applicationDidEnterBackground:application];
}

-(void)applicationWillEnterForeground:(UIApplication *)application
{
    [dosecastAPI applicationWillEnterForeground:application];
}

-(void)applicationWillResignActive:(UIApplication *)application
{
    [dosecastAPI applicationWillResignActive:application];
}

-(void)applicationDidBecomeActive:(UIApplication *)application
{
    [dosecastAPI applicationDidBecomeActive:application];
}

-(void)applicationWillTerminate:(UIApplication *)application
{
    [dosecastAPI applicationWillTerminate:application];
}

-(UIViewController*) mainViewController
{
    return mainViewController;
}

-(NSString*) apiVersion
{
    return dosecastAPI.apiVersion;
}

-(NSString*) productVersion
{
    return dosecastAPI.productVersion;
}

-(BOOL) userRegistered
{
    return dosecastAPI.userRegistered;
}

- (NSObject<DosecastAPIDelegate>*) delegate
{
    return dosecastAPI.delegate;
}

- (BOOL) internetConnection
{
    return dosecastAPI.internetConnection;
}

- (BOOL) userInteractionsAllowed
{
    return dosecastAPI.userInteractionsAllowed;
}

- (NSString*) userIDAbbrev
{
    return dosecastAPI.userIDAbbrev;
}

- (BOOL) notificationsPaused
{
    return dosecastAPI.notificationsPaused;
}

- (void) setNotificationsPaused:(BOOL)notificationsPaused
{
    dosecastAPI.notificationsPaused = notificationsPaused;
}

- (BOOL) isResolvingOverdueDoseAlert
{
    return dosecastAPI.isResolvingOverdueDoseAlert;
}

#pragma mark -
#pragma mark Memory management



@end

