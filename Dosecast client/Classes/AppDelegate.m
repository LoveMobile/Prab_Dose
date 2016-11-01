//
//  AppDelegate.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "AppDelegate.h"
#import "DosecastAPI.h"
#import "SpinnerViewController.h"
#import "ProgressViewController.h"
#import "DosecastAPIFlags.h"
#import "DosecastUtil.h"
#import "RegistrationViewController.h"
#import "PersistentFlags.h"
#import "AboutViewController.h"
#import "DosecastNavigationController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

#ifdef APP_STORE
 #import <HockeySDK/HockeySDK.h>
#endif

static const int IPAD_STATUS_BAR_HEIGHT=20;

// Persistent flags
NSString *PersistentFlagWroteReview = @"wroteReview";                                        // Whether the user wrote a review
NSString *PersistentFlagDisplayed5DayWriteReviewAlert = @"displayed5DayWriteReviewAlert";    // Whether the 5 day write review alert was displayed
NSString *PersistentFlagDisplayed10DayWriteReviewAlert = @"displayed10DayWriteReviewAlert";  // Whether the 10 day write review alert was displayed
NSString *PersistentFlagDisplayed15DayWriteReviewAlert = @"displayed15DayWriteReviewAlert";  // Whether the 15 day write review alert was displayed
NSString *PersistentFlagDisplayedFacebookTwitterAlert = @"displayedFacebookTwitterAlert";    // Whether the facebook/twitter alert was displayed
NSString *PersistentFlagDisplayed14DaySubscriptionExpiresAlert = @"displayed14DaySubscriptionExpiresAlert";  // Whether the 14 day subscription expires alert was displayed
NSString *PersistentFlagDisplayed3DaySubscriptionExpiresAlert = @"displayed3DaySubscriptionExpiresAlert";  // Whether the 3 day subscription expires alert was displayed
NSString *PersistentFlagDisplayedSubscriptionExpiredAlert = @"displayedSubscriptionExpiredAlert";  // Whether the subscription expired alert was displayed
NSString *PersistentFlagDisplayedPremiumSubscriptionPitch = @"displayedPremiumSubscriptionPitch";  // Whether the subscription was pitched to premium users

@implementation AppDelegate

@synthesize window;

// Callback for when user attempts to delete all data
- (void)handleDeleteAllData:(NSString*)errorMessage
{
    if (errorMessage)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
    else
    {
        // Pop the Settings view
        [mainNavigationController popToRootViewControllerAnimated:NO];
        
        window.rootViewController = launchScreenViewController;
        [window addSubview:launchScreenViewController.view];
        [[mainNavigationController view] removeFromSuperview];
        [self handleDosecastUIInitializationComplete];
    }
}

// Returns whether the given number of days has passed since the account was created
- (BOOL) hasDaysPassedSinceAccountCreated:(int)numDays
{
    NSDate* accountCreated = dosecastAPI.accountCreated;
    if (accountCreated == nil)
	{
		return NO;
	}

    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDate* now = [NSDate date];
	unsigned unitFlags = NSDayCalendarUnit;
	
	NSDateComponents *componentsSinceAccountCreated = [cal components:unitFlags fromDate:accountCreated toDate:now options:0];
	if (componentsSinceAccountCreated)
	{
		int daysSinceAccountCreated = (int)[componentsSinceAccountCreated day];
		return (daysSinceAccountCreated >= numDays);
	}
	else
		return NO;
}

// Returns the number of days until the subscription expires
- (BOOL) numDaysUntilSubscriptionExpiration:(int*)numDays
{
    *numDays = 0;
    AccountType accountType = dosecastAPI.accountType;
    NSDate* subscriptionExpires = dosecastAPI.subscriptionExpires;
    if (accountType != AccountTypeSubscription ||
        !subscriptionExpires)
    {
        return NO;
    }
    
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDate* now = [NSDate date];
    unsigned unitFlags = NSDayCalendarUnit;
    
    NSDateComponents *components = [cal components:unitFlags fromDate:now toDate:subscriptionExpires options:0];
    if (components)
    {
        *numDays = (int)[components day];
        return YES;
    }
    else
        return NO;
}


// Returns whether the subscription is expired
- (BOOL) isSubscriptionExpired
{
    AccountType accountType = dosecastAPI.accountType;
    NSDate* subscriptionExpires = dosecastAPI.subscriptionExpires;
    if (accountType == AccountTypeSubscription ||
        !subscriptionExpires)
    {
        return NO;
    }
    else
        return [subscriptionExpires timeIntervalSinceNow] < 0;
}

// Returns whether to display an alert requesting to write a review 10 days after account creation
- (BOOL)shouldDisplayPremiumSubscriptionPitch
{
    AccountType accountType = dosecastAPI.accountType;
    if (accountType != AccountTypePremium ||
        [dosecastAPI doesAnyGroupGivePremium] ||
        [dosecastAPI getPersistentFlag:PersistentFlagDisplayedPremiumSubscriptionPitch])
    {
        return NO;
    }
    else
        return YES;
}

// Returns whether to display an alert requesting to write a review 5 days after account creation
- (BOOL)shouldDisplay5DayWriteReviewAlert
{
    if ([dosecastAPI getPersistentFlag:PersistentFlagWroteReview] ||
        [dosecastAPI getPersistentFlag:PersistentFlagDisplayed5DayWriteReviewAlert])
    {
        return NO;
    }
    else
        return [self hasDaysPassedSinceAccountCreated:5];
}

// Returns whether to display an alert requesting to write a review 10 days after account creation
- (BOOL)shouldDisplay10DayWriteReviewAlert
{
	if ([dosecastAPI getPersistentFlag:PersistentFlagWroteReview] ||
		[dosecastAPI getPersistentFlag:PersistentFlagDisplayed10DayWriteReviewAlert])
	{
		return NO;
	}
    else
        return [self hasDaysPassedSinceAccountCreated:10];
}

// Returns whether to display an alert requesting to write a review 15 days after account creation 
- (BOOL)shouldDisplay15DayWriteReviewAlert
{
	if ([dosecastAPI getPersistentFlag:PersistentFlagWroteReview] ||
		[dosecastAPI getPersistentFlag:PersistentFlagDisplayed15DayWriteReviewAlert])
	{
		return NO;
	}
    else
        return [self hasDaysPassedSinceAccountCreated:15];	
}

// Returns whether to display an alert requesting to renew a subscription 14 days before expiration
- (BOOL)shouldDisplay14DaySubscriptionExpiresAlert
{
    int numDays = 0;
    if ([dosecastAPI getPersistentFlag:PersistentFlagDisplayed14DaySubscriptionExpiresAlert] ||
        ![self numDaysUntilSubscriptionExpiration:&numDays])
    {
        return NO;
    }
    else
        return (numDays > 12 && numDays <= 14);
}

// Returns whether to display an alert requesting to renew a subscription 3 days before expiration
- (BOOL)shouldDisplay3DaySubscriptionExpiresAlert
{
    int numDays = 0;
    if ([dosecastAPI getPersistentFlag:PersistentFlagDisplayed3DaySubscriptionExpiresAlert] ||
        ![self numDaysUntilSubscriptionExpiration:&numDays])
    {
        return NO;
    }
    else
        return (numDays > 1 && numDays <= 3);
}

// Returns whether to display an alert requesting to renew a subscription after expiration
- (BOOL)shouldDisplaySubscriptionExpiredAlert
{
    if ([dosecastAPI getPersistentFlag:PersistentFlagDisplayedSubscriptionExpiredAlert] ||
        ![self isSubscriptionExpired])
    {
        return NO;
    }
    else
        return YES;
}

// Returns whether to display an alert highlighting facebook & twitter 
- (BOOL)shouldDisplayFacebookTwitterAlert
{
	if ([dosecastAPI getPersistentFlag:PersistentFlagDisplayedFacebookTwitterAlert])
	{
		return NO;
	}
	else
        return [self hasDaysPassedSinceAccountCreated:20];
}

- (void) displaySubscriptionExpiringAlert
{
    int numDays = 0;
    [self numDaysUntilSubscriptionExpiration:&numDays];
    
    NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
    NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
    NSString* numDaysStr = nil;
    if (![DosecastUtil shouldUseSingularForInteger:numDays])
        numDaysStr = [NSString stringWithFormat:@"%d %@", numDays, dayPlural];
    else
        numDaysStr = [NSString stringWithFormat:@"%d %@", numDays, daySingular];
    
    DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionExpiringSoonTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscription Expiring Soon", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                               message:[NSString stringWithFormat:
                                                                                        NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionExpiringSoonMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your subscription to Dosecast Pro with CloudSync will be expiring in %@. To avoid losing access to the CloudSync service and all the features in this edition, tap the 'Subscribe' button below to renew your subscription now.", @"The title on the alert appearing when a premium feature is accessed in the demo edition"]),
                                                                                        numDaysStr]
                                                                                 style:DosecastAlertControllerStyleAlert];
    
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFeatureSubscriptionButtonSubscribe", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe", @"The Upgrade button of the alert appearing when a premium feature is accessed in the demo edition"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action){
                                      [self handleViewAccountController];
                                  }]];
    
    UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
    [alert showInViewController:rootViewController];
}

- (void) handleDisplayWriteReviewAlert
{
    DosecastAlertController* writeReviewAlert = [DosecastAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"AlertWriteReviewTitle", @"Dosecast-client", [NSBundle mainBundle], @"Would You Recommend %@?", @"The title of the alert asking the user to write a review"]), [DosecastUtil getProductAppName]]
                                                                                          message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"AlertWriteReviewMessage", @"Dosecast-client", [NSBundle mainBundle], @"If you find %@ useful, please consider writing a short review in the App Store to help others discover this app. It will only take a minute of your time.", @"The message of the alert asking the user to write a review"]), [DosecastUtil getProductAppName]]
                                                                                            style:DosecastAlertControllerStyleAlert];
    
    
    [writeReviewAlert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertWriteReviewButtonNoThanks", @"Dosecast-client", [NSBundle mainBundle], @"No Thanks", @"The No Thanks button on the alert asking the user to write a review"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:nil]];
    
    [writeReviewAlert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertWriteReviewButtonWriteReview", @"Dosecast-client", [NSBundle mainBundle], @"Write Review", @"The Write Review button on the alert asking the user to write a review"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action){
                                      // Remember that the user wrote a review
                                      [dosecastAPI setPersistentFlag:PersistentFlagWroteReview value:YES];
                                      
                                      NSString *url = NSLocalizedStringWithDefaultValue(@"ViewAboutWriteReviewURL", @"Dosecast-client", [NSBundle mainBundle], @"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=365191644&pageNumber=0&sortOrdering=1&type=Purple+Software&mt=8", @"The URL of the Write a Review page linked from the About view"]);
                                      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                  }]];
    
    UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
    [writeReviewAlert showInViewController:rootViewController];
}

// Method to display relevant user alerts at the appropriate time
- (void)displayUserAlerts:(NSNotification *)notification
{
    if ([self shouldDisplay14DaySubscriptionExpiresAlert])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayed14DaySubscriptionExpiresAlert value:YES];

        [self displaySubscriptionExpiringAlert];
    }
    else if ([self shouldDisplay3DaySubscriptionExpiresAlert])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayed3DaySubscriptionExpiresAlert value:YES];
        
        [self displaySubscriptionExpiringAlert];
    }
    else if ([self shouldDisplaySubscriptionExpiredAlert])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayedSubscriptionExpiredAlert value:YES];

        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionExpiredTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscription Expired", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ViewAccountSubscriptionExpiredMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your subscription to Dosecast Pro with CloudSync has expired. To keep your drug data up-to-date across multiple devices and to access all the features in this edition, tap the 'Subscribe' button below to renew your subscription now.", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:nil]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFeatureSubscriptionButtonSubscribe", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe", @"The Upgrade button of the alert appearing when a premium feature is accessed in the demo edition"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          [self handleViewAccountController];
                                      }]];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
    else if ([self shouldDisplayPremiumSubscriptionPitch])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayedPremiumSubscriptionPitch value:YES];
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewAccountPremiumSubscriptionPitchTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Got Multiple Devices?", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ViewAccountPremiumSubscriptionPitchMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This version of Dosecast introduces CloudSync, a new subscription service that keeps all your drug data up-to-date across multiple devices, and enables dose reminders to be delivered to all devices simultaneously. You can learn more about CloudSync from the Settings screen, or by tapping the 'Learn More' button below.", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:nil]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewAccountPremiumSubscriptionPitchButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Learn More", @"The Upgrade button of the alert appearing when a premium feature is accessed in the demo edition"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          [self handleViewAccountController];
                                      }]];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
    else if ([self shouldDisplay5DayWriteReviewAlert])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayed5DayWriteReviewAlert value:YES];
        
        [self handleDisplayWriteReviewAlert];
    }
    else if ([self shouldDisplay10DayWriteReviewAlert])
    {				
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayed10DayWriteReviewAlert value:YES];
        
        [self handleDisplayWriteReviewAlert];
    }
    else if ([self shouldDisplay15DayWriteReviewAlert])
    {				
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayed15DayWriteReviewAlert value:YES];
        
        [self handleDisplayWriteReviewAlert];
    }
    else if ([self shouldDisplayFacebookTwitterAlert])
    {
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayedFacebookTwitterAlert value:YES];
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"AlertFacebookTwitterTitle", @"Dosecast-client", [NSBundle mainBundle], @"%@ Is Now On Facebook & Twitter", @"The title on the alert asking the user to visit Facebook & Twitter"]), [DosecastUtil getProductAppName]]
                                                                                              message:NSLocalizedStringWithDefaultValue(@"AlertFacebookTwitterMessage", @"Dosecast-client", [NSBundle mainBundle], @"Join us on Facebook or follow us on Twitter to weigh-in on future enhancements and get a sneak peak at our next update!", @"The message on the alert asking the user to visit Facebook & Twitter"])
                                                                                                style:DosecastAlertControllerStyleAlert];
        
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:nil]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFacebookTwitterButtonFacebook", @"Dosecast-client", [NSBundle mainBundle], @"Go to Facebook", @"The Go to Facebook button on the alert asking the user to visit Facebook & Twitter"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          NSString *url = NSLocalizedStringWithDefaultValue(@"ViewAboutFacebookURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.facebook.com/pages/Dosecast/143374575706386", @"The URL of the Facebook page linked from the About view"]);
                                          [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                      }]];

        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFacebookTwitterButtonTwitter", @"Dosecast-client", [NSBundle mainBundle], @"Go to Twitter", @"The Go to Twitter button on the alert asking the user to visit Facebook & Twitter"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          NSString *url = NSLocalizedStringWithDefaultValue(@"ViewAboutTwitterURL", @"Dosecast-client", [NSBundle mainBundle], @"http://www.twitter.com/dosecast", @"The URL of the Twitter page linked from the About view"]);
                                          [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                      }]];

        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
}

- (void) handleViewAccountController
{
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
    mainNavigationController.topViewController.navigationItem.backBarButtonItem = backButton;
    
    [mainNavigationController pushViewController:[dosecastAPI createAccountViewController] animated:YES];
}

- (void)handleAboutToolbarButton:(id)sender
{    
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
	mainNavigationController.topViewController.navigationItem.backBarButtonItem = backButton;
	
	// Display about
    AboutViewController* aboutController = [[AboutViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"AboutViewController"]
                                                                                  bundle:[NSBundle mainBundle]
                                                                             dosecastAPI:dosecastAPI];
	[mainNavigationController pushViewController:aboutController animated:YES];
}

- (void)handleSettingsToolbarButton:(id)sender {
    
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
	mainNavigationController.topViewController.navigationItem.backBarButtonItem = backButton;
	
	// Display settings
	UIViewController* settingsController = [dosecastAPI createSettingsViewController];
	[mainNavigationController pushViewController:settingsController animated:YES];
}

- (void)handleHistoryToolbarButton:(id)sender
{
	// Premium-only feature
	if (dosecastAPI.accountType == AccountTypeDemo)
	{
        // Remember that we displayed this reminder
        [dosecastAPI setPersistentFlag:PersistentFlagDisplayedFacebookTwitterAlert value:YES];
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro Feature", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoseHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:nil]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFeatureSubscriptionButtonSubscribe", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe", @"The Upgrade button of the alert appearing when a premium feature is accessed in the demo edition"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action){
                                          [self handleViewAccountController];
                                      }]];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
	}
	else
	{
        NSArray* pNames = nil;
        NSArray* pIDs = nil;
        [dosecastAPI getListOfPersonNames:&pNames andCorrespondingPersonIds:&pIDs];

        NSMutableArray* personNames = [NSMutableArray arrayWithArray:pNames];
        
        // If there are no persons existing, just display the history for "me"
        if ([personNames count] == 0)
        {
            // Set Back button title
            NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
            UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
            backButton.style = UIBarButtonItemStylePlain;
            if (!backButton.image)
                backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
            mainNavigationController.topViewController.navigationItem.backBarButtonItem = backButton;
                        
            [mainNavigationController pushViewController:[dosecastAPI createHistoryViewController:nil] animated:YES];
        }
        else // ask the user to choose a person
        {
            DosecastAlertController* selectPersonController = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewMainHistorySelectPersonTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"View dose history for:", @"The title in the main view action sheet for selecting which person's drug history to view"])
                                                                               message:nil
                                                                                 style:DosecastAlertControllerStyleActionSheet];
            
            [personNames insertObject:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]) atIndex:0];
            
            for (NSString *name in personNames)
            {
                [selectPersonController addAction:
                 [DosecastAlertAction actionWithTitle:name
                                                style:DosecastAlertActionStyleDefault
                                              handler:^(DosecastAlertAction *action){
                                                  NSArray* personNames = nil;
                                                  NSArray* personIDs = nil;
                                                  [dosecastAPI getListOfPersonNames:&personNames andCorrespondingPersonIds:&personIDs];
                                                  
                                                  NSUInteger nameIndex = [personNames indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                                                      NSString* thisName = (NSString*)obj;
                                                      BOOL isMatch = [thisName isEqualToString:action.title];
                                                      if (isMatch)
                                                          *stop = YES;
                                                      return isMatch;
                                                  }];
                                                  NSString* personID = nil;
                                                  if (nameIndex != NSNotFound)
                                                      personID = [personIDs objectAtIndex:nameIndex];
                                                  
                                                  // Set Back button title
                                                  NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
                                                  UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
                                                  backButton.style = UIBarButtonItemStylePlain;
                                                  if (!backButton.image)
                                                      backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
                                                  mainNavigationController.topViewController.navigationItem.backBarButtonItem = backButton;
                                                  
                                                  [mainNavigationController pushViewController:[dosecastAPI createHistoryViewController:personID] animated:YES];
                                                  
                                              }]];
            }
            
            [selectPersonController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];
            
            UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];

            [selectPersonController showInViewController:rootViewController sourceBarButtonItem:(UIBarButtonItem*)sender];
        }
	}
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
                                          [mainNavigationController dismissViewControllerAnimated:YES completion:nil];
                                      }]];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
    else
    {
        [mainNavigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void) composeDrugListEmail
{
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    mailController.mailComposeDelegate = self;
    NSMutableString* subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugListSubject", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ Drug List", @"The subject line of the drug list email"]), [DosecastUtil getProductAppName]];
    [mailController setSubject:subject];
    
    NSString* body = [dosecastAPI getDrugListHTMLDescription];
    [mailController setMessageBody:body isHTML:YES];
    
    NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:mailController.navigationBar.titleTextAttributes];
    [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    
    mailController.navigationBar.titleTextAttributes = titleTextAttributes;
    
    [mailController.navigationBar setBarTintColor:[DosecastUtil getNavigationBarColor]];
    [mailController.navigationBar setTintColor:[UIColor whiteColor]];
    
    [mainNavigationController presentViewController:mailController animated:YES completion:nil];
}

- (void)handleEmailToolbarButton:(id)sender
{
	if (![MFMailComposeViewController canSendMail])
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"])];
        
        UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
	}
	else
	{
        NSString* languageCode = [DosecastUtil getLanguageCode];
        if ([languageCode compare:@"en" options:NSLiteralSearch] == NSOrderedSame)
        {
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Warning", @"The title on the alert warning when emailing drug info"])
                                                                                       message:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"If you send this email, the personal health information shared within it will not be protected. Continue if you are sure you want to send this information in an email.", @"The message on the alert warning when emailing drug info"])
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonClose", @"Dosecast", [DosecastUtil getResourceBundle], @"Close", @"The text on the Close button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonContinue", @"Dosecast", [DosecastUtil getResourceBundle], @"Continue", @"The text on the Continue button in an alert"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action){
                                              [self composeDrugListEmail];
                                          }]];
            
            UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
            [alert showInViewController:rootViewController];

        }
        else
            [self composeDrugListEmail];
	}
}

// Get the currently active navigation controller 
- (UINavigationController*)getUINavigationController
{
    return mainNavigationController;
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
    NSString *gearIconFilePath = [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/Gear.png"];
	UIImage* gearIconImage = [[UIImage alloc] initWithContentsOfFile:gearIconFilePath];
	UIBarButtonItem *gearButton = [[UIBarButtonItem alloc] initWithImage:gearIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleSettingsToolbarButton:)];
    
    NSString *helpIconFilePath = [NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/Help.png"];
    UIImage* helpIconImage = [[UIImage alloc] initWithContentsOfFile:helpIconFilePath];
    UIBarButtonItem *helpButton = [[UIBarButtonItem alloc] initWithImage:helpIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleAboutToolbarButton:)];
    
    UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
    NSMutableArray* toolbarItems = [[NSMutableArray alloc] init];
    [toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    [toolbarItems addObject:helpButton];
    [toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    [toolbarItems addObject:logButton];
    [toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    [toolbarItems addObject:mailButton];
    [toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    [toolbarItems addObject:gearButton];
    [toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    
    rootViewController.toolbarItems = toolbarItems;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window setFrame:[[UIScreen mainScreen] bounds]];
    
#ifdef APP_STORE
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"ca48024d5df1fd5e68c332aee6bf5fc6"];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayUserAlerts:)
                                                 name:DosecastAPIDisplayUserAlertsNotification
                                               object:nil];
    launchScreenViewController = nil;

    if ([DosecastUtil getOSVersionFloat] >= 8.0f)
    {
        UIStoryboard *launchStoryboard = [UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil];
        launchScreenViewController = (UIViewController*)[launchStoryboard instantiateInitialViewController];
    }
    else
    {
        // Determine if this device is an iPad
        NSString* deviceName = [[UIDevice currentDevice] model];	
        NSRange iPadRange = [deviceName rangeOfString:@"iPad" options:NSCaseInsensitiveSearch];
        BOOL isIPad = iPadRange.location != NSNotFound;
        
        // Get the proper startup image to display
        
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        NSMutableString* defaultImageName = [NSMutableString stringWithString:@"LaunchImage"];
        [defaultImageName appendString:@"-700"];
        if (isIPad)
        {
            if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
                [defaultImageName appendString:@"-Landscape"];
            else
                [defaultImageName appendString:@"-Portrait"];
        }
        else // iPhone 5 special handling
        {
            CGSize screenBounds = ([[UIScreen mainScreen] bounds]).size;
            if (screenBounds.height == 568)
                [defaultImageName appendString:@"-568h"];
        }
        if ([UIScreen mainScreen].scale == 2.0) // if the screen is retina
            [defaultImageName appendString:@"@2x"];
        if (isIPad)
            [defaultImageName appendString:@"~ipad"];
        else
            [defaultImageName appendString:@"~iphone"];
        [defaultImageName appendString:@".png"];
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        
        // Display the startup image
        UIImageView* imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:defaultImageName]];
        int imageViewWidth = imageView.frame.size.width;
        int imageViewHeight = imageView.frame.size.height;
        imageView.frame = CGRectMake(0, (isIPad ? IPAD_STATUS_BAR_HEIGHT : 0), imageViewWidth, imageViewHeight);
        
        // Rotate the startup image, if necessary
        CGSize screenBounds = ([[UIScreen mainScreen] bounds]).size;
        if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
        {
            int offset = 0;
            if (isIPad)
            {
                if (orientation == UIDeviceOrientationLandscapeLeft)
                    offset = -IPAD_STATUS_BAR_HEIGHT/2;
                else if (orientation == UIDeviceOrientationLandscapeRight)
                    offset = IPAD_STATUS_BAR_HEIGHT/2;
            }
            [imageView setCenter:CGPointMake(screenBounds.width/2 + offset, screenBounds.height/2)];
            CGAffineTransform cgCTM;
            if (orientation == UIDeviceOrientationLandscapeRight)
                cgCTM = CGAffineTransformMakeRotation(-M_PI/2.0);
            else
                cgCTM = CGAffineTransformMakeRotation(M_PI/2.0);
            imageView.transform = cgCTM;
            imageView.bounds = CGRectMake(0, 0, imageViewWidth, imageViewHeight);
        }
        
        launchScreenViewController = [[UIViewController alloc] init];
        launchScreenViewController.view = imageView;
    }
    
    window.rootViewController = launchScreenViewController;
    [window addSubview:launchScreenViewController.view];

	[window makeKeyAndVisible];	
	
    // Set the version string
	NSMutableString* versionStr = [NSMutableString stringWithFormat:@"Version %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    
#ifdef DEBUG
	[versionStr appendString:@" (Debug)"];
#endif
    
    // Construct API interface
	dosecastAPI = [DosecastAPI createDosecastAPIInstanceWithDelegate:self
                                                       launchOptions:launchOptions
                                                            userData:nil
                                                            apiFlags:[NSArray arrayWithObjects:
                                                                      DosecastAPIShowAccount,
                                                                      DosecastAPIShowNativeUIOnIPad,
                                                                      DosecastAPIMultiPersonSupport,
                                                                      DosecastAPITrackRemainingQuantities,
                                                                      DosecastAPITrackRefillsRemaining,
                                                                      DosecastAPIShowMainToolbar,
                                                                      DosecastAPIShowDrugInfoToolbar,
                                                                      DosecastAPIShowHistoryToolbar,
                                                                      DosecastAPIEnableDebugLog,
                                                                      DosecastAPIEnableUSDrugDatabaseSearch,
                                                                      DosecastAPIEnableDeleteAllDataSettings,
                                                                      DosecastAPIDoctorSupport,
                                                                      DosecastAPIPharmacySupport,
                                                                      DosecastAPIPrescriptionNumberSupport,
                                                                      DosecastAPIEnableShowArchivedDrugs,
                                                                      DosecastAPIEnableShowDrugImages,
                                                                      DosecastAPIWarnOnEmailingDrugInfo,
                                                                      DosecastAPIEnableShowDrugNamesInNotifications,
                                                                      DosecastAPIShowDrugNamesInNotificationsByDefault,
                                                                      DosecastAPIEnableGroups,
                                                                      DosecastAPIEnableSync,
                                                                      nil]
                                                     persistentFlags:[NSArray arrayWithObjects:
                                                                      PersistentFlagWroteReview,
                                                                      PersistentFlagDisplayed5DayWriteReviewAlert,
                                                                      PersistentFlagDisplayed10DayWriteReviewAlert,
                                                                      PersistentFlagDisplayed15DayWriteReviewAlert,
                                                                      PersistentFlagDisplayedFacebookTwitterAlert,
                                                                      PersistentFlagDisplayed14DaySubscriptionExpiresAlert,
                                                                      PersistentFlagDisplayed3DaySubscriptionExpiresAlert,
                                                                      PersistentFlagDisplayedSubscriptionExpiredAlert,
                                                                      PersistentFlagDisplayedPremiumSubscriptionPitch,
                                                                      nil]
                                                      productVersion:versionStr];
    
    spinnerViewController = [[SpinnerViewController alloc] init];
    progressViewController = [[ProgressViewController alloc] init];

	return YES;
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
	[dosecastAPI didRegisterForRemoteNotificationsWithDeviceToken:devToken];
}

// Called after the main view finishes sliding onto the registration view, once registration is complete
- (void)animationDidStop:(NSString*)animationID finished:(BOOL)finished context:(void *)context 
{
	// Remove the registration page
	[[registrationNavigationController view] removeFromSuperview];		
    window.rootViewController = mainNavigationController;

	[UIView setAnimationDelegate:nil];
	[UIView setAnimationDidStopSelector:nil];	
}

// Callback for when UI initialization is complete. The DosecastAPI view controllers must not be made visible until
// after this call is made
- (void)handleDosecastUIInitializationComplete
{
    mainNavigationController = [[DosecastNavigationController alloc] initWithRootViewController:[dosecastAPI createMainViewController]];
    [self setupMainToolbar];
    
    RegistrationViewController* registrationViewController = [[RegistrationViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"RegistrationViewController"]                                                                                                                                               bundle:[NSBundle mainBundle]];
    registrationViewController.registrationDelegate = self;
    registrationNavigationController = [[DosecastNavigationController alloc] initWithRootViewController:registrationViewController];
    [mainNavigationController setNavigationBarHidden:NO animated:NO];
    [mainNavigationController setToolbarHidden:NO animated:NO];
    [registrationNavigationController setNavigationBarHidden:NO animated:NO];
    [registrationNavigationController setToolbarHidden:YES animated:NO];
    
    NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:mainNavigationController.navigationBar.titleTextAttributes];
    [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    
    mainNavigationController.navigationBar.titleTextAttributes = titleTextAttributes;
    registrationNavigationController.navigationBar.titleTextAttributes = titleTextAttributes;

    [[UINavigationBar appearance] setBarTintColor:[DosecastUtil getNavigationBarColor]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    [[UIToolbar appearance] setBarTintColor:[DosecastUtil getNavigationBarColor]];
    [[UIToolbar appearance] setTintColor:[UIColor whiteColor]];
    
    // Add the main or registration view to the window, but underneath the startup image (so it isn't visible)
	if (dosecastAPI.userRegistered)
	{
		// Display our main view
		[window insertSubview:[mainNavigationController view] atIndex:0];
        window.rootViewController = mainNavigationController;
	}
	else
	{
		// Display our registration view
		[window insertSubview:[registrationNavigationController view] atIndex:0];
        window.rootViewController = registrationNavigationController;
	}

	// Ok - we should remove the image view now so the underlying view is visible
	[launchScreenViewController.view removeFromSuperview];
}

// Callback for when the Dosecast component must be made visible. If Dosecast is embedded in a UITabBarController
// or other UI component, this component must be made visible at the time of this call if it is not already.
- (void)displayDosecastComponent
{
}

// Callback to find out if the Dosecast component is visible. If Dosecast is embedded in a UITabBarController
// or other UI component, return whether the component is active/selected.
- (BOOL)isDosecastComponentVisible
{
    return YES;
}

// Called to register the user
- (void)registerUser
{
    [self disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSendingRegistration", @"Dosecast-client", [NSBundle mainBundle], @"Sending registration", @"The message appearing in the spinner view when sending the registration details"])];
    [dosecastAPI registerUser];
}

// Callback for when an alert message should be displayed to the user
- (void)displayAlertMessageToUser:(NSString*)message
{
    DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                       message:message];
    
    UIViewController* rootViewController = [mainNavigationController.viewControllers objectAtIndex:0];
    [alert showInViewController:rootViewController];
}

// Callback for when a subscription is purchased
- (void)handleSubscriptionPurchased
{
    // Clear all subscription alerts
    [dosecastAPI setPersistentFlag:PersistentFlagDisplayed14DaySubscriptionExpiresAlert value:NO];
    [dosecastAPI setPersistentFlag:PersistentFlagDisplayed3DaySubscriptionExpiresAlert value:NO];
    [dosecastAPI setPersistentFlag:PersistentFlagDisplayedSubscriptionExpiredAlert value:NO];
}

// Callback for when Dosecast registration completes. If an error occurred, errorMessage will be non-nil.
- (void)handleDosecastRegistrationComplete:(NSString*)errorMessage
{    
    if (errorMessage)
    {
        [self allowDosecastUserInteractionsWithMessage:YES];

        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        
        UIViewController* rootViewController = [registrationNavigationController.viewControllers objectAtIndex:0];
        [alert showInViewController:rootViewController];
    }
    else
    {
        // Flag if we should avoid displaying the facebook/twitter, 5 day write review, 10 day write review, or 15 day write review alerts
        if ([self hasDaysPassedSinceAccountCreated:5])
            [dosecastAPI setPersistentFlag:PersistentFlagDisplayed5DayWriteReviewAlert value:YES];
        if ([self hasDaysPassedSinceAccountCreated:10])
            [dosecastAPI setPersistentFlag:PersistentFlagDisplayed10DayWriteReviewAlert value:YES];
        if ([self hasDaysPassedSinceAccountCreated:15] && [dosecastAPI getPersistentFlag:PersistentFlagWroteReview])
            [dosecastAPI setPersistentFlag:PersistentFlagDisplayed15DayWriteReviewAlert value:YES];
        if ([self hasDaysPassedSinceAccountCreated:20])
            [dosecastAPI setPersistentFlag:PersistentFlagDisplayedFacebookTwitterAlert value:YES];

        [self allowDosecastUserInteractionsWithMessage:YES];

        [mainNavigationController view].frame = [registrationNavigationController view].frame;
        [mainNavigationController view].alpha = 0;
        
        [window addSubview:[mainNavigationController view]];
        
        // Note: there's no need to tell the pill notification manager to perform an initial getState.
        // This was already done as part of registration.
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:.5];
        [mainNavigationController view].alpha = 1;
        
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        [UIView commitAnimations];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	[dosecastAPI didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    [dosecastAPI didReceiveRemoteNotification:userInfo fetchCompletionHandler:handler];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    [dosecastAPI performFetchWithCompletionHandler:completionHandler];
}

- (void) applicationDidReceiveMemoryWarning:(UIApplication*)application
{
    [dosecastAPI applicationDidReceiveMemoryWarning:application];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
	[dosecastAPI didFailToRegisterForRemoteNotificationsWithError:err];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [dosecastAPI didRegisterUserNotificationSettings:notificationSettings];
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

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message
{
    spinnerViewController.message = message;
    if (dosecastAPI.userRegistered)
        [spinnerViewController showOnViewController:mainNavigationController.visibleViewController animated:YES];
    else
        [spinnerViewController showOnViewController:registrationNavigationController.visibleViewController animated:YES];
}

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    spinnerViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation
{
    [spinnerViewController hide:allowAnimation];
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress // A number between 0 and 1
{
    progressViewController.message = message;
    progressViewController.progress = progress;
    if (dosecastAPI.userRegistered)
        [progressViewController showOnViewController:mainNavigationController.visibleViewController animated:YES];
    else
        [progressViewController showOnViewController:registrationNavigationController.visibleViewController animated:YES];
}

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress // A number between 0 and 1
{
    progressViewController.progress = progress;
}

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    progressViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation
{
    [progressViewController hide:allowAnimation];
}

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService
{
    return NSLocalizedStringWithDefaultValue(@"ViewTermsOfServiceTermsGroup", @"Dosecast-client", [NSBundle mainBundle], @"", @"The terms of service");
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DosecastAPIDisplayUserAlertsNotification object:nil];
}


@end

