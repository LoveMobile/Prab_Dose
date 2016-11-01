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
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "WebServiceMan.h"
#import "IdleTimerMan.h"
#import "Constants.h"
#import "Utilities.h"
#import "AuthorizationMan.h"
#import "MoreViewController.h"
#import "ContactViewController.h"
#import "TutorialViewController.h"
#import "WarningViewController.h"

#ifdef TESTFLIGHT
#import "TestFlight.h"
#endif

@interface AppDelegate ()

@property (nonatomic, strong) UIImageView *splashView;

@end

@implementation AppDelegate

@synthesize window;
@synthesize m_vcMerlin;
@synthesize m_ai;
@synthesize navBarColor;
@synthesize delegate;
@synthesize m_msgVC;
@synthesize tabBarController;
@synthesize alerts;



- (void) buildTabBarControllers {
    NSMutableArray* viewControllers = [NSMutableArray arrayWithObjects:nil];
    
    [viewControllers addObject:
     [self addTabForViewController:[dosecastAPI createScheduleViewController]
                         withTitle:@"Schedule"
                     withImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/ScheduleTabIcon.png"]
             withSelectedImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/ScheduleTabIconSelected.png"]]];
    
    [viewControllers addObject:
     [self addTabForViewController:[dosecastAPI createDrugsViewController]
                         withTitle:@"Medications"
                     withImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MedicationTabIcon.png"]
             withSelectedImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MedicationTabIconSelected.png"]]];
    
    [viewControllers addObject:
     [self addTabForViewController:[dosecastAPI createHistoryViewController:nil]
                         withTitle:@"History"
                     withImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/HistoryTabIcon.png"]
             withSelectedImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/HistoryTabIconSelected.png"]]];
    
    [viewControllers addObject:
     [self addTabForViewController:[[ContactViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ContactViewController"] bundle:[NSBundle mainBundle]]
                         withTitle:@"Contact"
                     withImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/ContactTabIcon.png"]
             withSelectedImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/ContactTabIconSelected.png"]]];
    
    [viewControllers addObject:
     [self addTabForViewController:[[MoreViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"MoreViewController"] bundle:[NSBundle mainBundle] dosecastAPI:dosecastAPI]
                         withTitle:@"More"
                     withImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MoreTabIcon.png"]
             withSelectedImagePath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath], @"/MoreTabIconSelected.png"]]];
    
    tabBarController.viewControllers = viewControllers;
    tabBarController.customizableViewControllers = nil;
}

// Callback for when user attempts to delete all data
- (void)handleDeleteAllData
{
    if (shouldAvoidResettingDevice)
        shouldAvoidResettingDevice = NO;
    else
        [[AuthorizationMan get] resetDevice];

    if (!self.m_vcMerlin)
    {
        [[Utilities getAppDel] hideMessage];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"flagSignOn"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[IdleTimerMan get] killTimer];
        [[Utilities getAppDel] showMerlin];
    }
    
    // Reset all view controllers
    /*
    for (UINavigationController* navController in tabBarController.viewControllers)
    {
        [navController popToRootViewControllerAnimated:NO];
    }
    */
    
    // it is safer to rebuild the VCs in the case!!
    tabBarController.viewControllers=nil;
    [self buildTabBarControllers];
    tabBarController.selectedIndex = 0;
    
    
}

- (void) handleChangePasscode
{
    [signOutConfirmation show];
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController
{
    // Don't allow the user to select a tab while in the process of resolving an overdue dose alert
    return !dosecastAPI.isResolvingOverdueDoseAlert;
}

- (UINavigationController*) addTabForViewController:(UIViewController*)vc
                                          withTitle:(NSString*)title
                                      withImagePath:(NSString*)imagePath
                              withSelectedImagePath:(NSString*)selectedImagePath
{
    UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:vc];
    [navController setNavigationBarHidden:NO animated:NO];
    [navController setToolbarHidden:YES animated:NO];
    UITabBarItem* tabBarItem = nil;
    
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        // Set selected & unselected images
        if (selectedImagePath)
            tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage imageWithContentsOfFile:imagePath] selectedImage:[UIImage imageWithContentsOfFile:selectedImagePath]];
        else
            tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage imageWithContentsOfFile:imagePath] tag:0];

        navController.navigationBar.barTintColor = navBarColor;
        navController.navigationBar.tintColor = [UIColor whiteColor];
        
        NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:navController.navigationBar.titleTextAttributes];
        [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
        navController.navigationBar.titleTextAttributes = titleTextAttributes;
    }
    else
    {
        tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage imageWithContentsOfFile:imagePath] tag:0];
        
        // Set selected & unselected images
        if (selectedImagePath)
        {
            [tabBarItem setFinishedSelectedImage:[UIImage imageWithContentsOfFile:selectedImagePath]
                     withFinishedUnselectedImage:[UIImage imageWithContentsOfFile:imagePath]];
        }

        navController.navigationBar.tintColor = navBarColor;
    }

    navController.navigationBar.topItem.title = title;
    navController.tabBarItem = tabBarItem;
    
    return navController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[TouchCapturingWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

#ifdef TESTFLIGHT
    [TestFlight setDeviceIdentifier:[DosecastUtil getHardwareID]];
    [TestFlight takeOff:@"0f9bd4c7-8bab-4345-9de5-d1812b13851a"];
#endif
    
    registrationErrorAlert = nil;
    signOutConfirmation = [[UIAlertView alloc] initWithTitle:@"Sign Out"
                                                        message:@"Are you sure you want to sign out?"
                                                       delegate:self
                                           cancelButtonTitle:@"No"
                                           otherButtonTitles:@"Yes", nil];
    
    allowSpinnerProgressViewController = YES;
    needsApplicationDidBecomeActiveCall = NO;
    
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        [[UITabBar appearance] setBarTintColor:[UIColor blackColor]];
    }
    
    [Utilities AppLaunchActions];
    
    // ************* KP authentication web service URLs
    
#ifdef DEBUG
    [WebServiceMan get].wsBaseUrl=@"https://mydoctor-pp.kaiserpermanente.org/mykpmedsdev/v1/services";
#else
    [WebServiceMan get].wsBaseUrl=@"https://mydoctor.kaiserpermanente.org/mykpmeds/v1/services";
#endif
    
    [WebServiceMan get].appId = @"MD-5";
    
    LOG("The webservice man url is: %@", [WebServiceMan get].wsBaseUrl);

    self.navBarColor = [DosecastUtil getNavigationBarColor];

    // Construct DosecastAPI interface
    isMerlinPerformingActivation = NO;
    shouldAvoidResettingDevice = NO;
    isInitializingDosecast = YES; // flag that we're about to start initializing Dosecast
    dosecastAPI = [[DosecastAPI alloc]  initWithDelegate:self
										   launchOptions:launchOptions
												userData:nil
                                                apiFlags:[NSArray arrayWithObjects:
                                                          DosecastAPIEnablePasscodeSettings,
                                                          DosecastAPIShowVersionInSettings,
                                                          DosecastAPIEnableDebugLog,
                                                          DosecastAPIEnableUSDrugDatabaseSearch,
                                                          DosecastAPIEnableUSDrugDatabaseTypes,
                                                          DosecastAPIEnableDeleteAllDataSettings,
                                                          DosecastAPIIdentifyServerAccountByUserData,
                                                          DosecastAPIPrescriptionNumberSupport,
                                                          DosecastAPIEnableSecondaryRemindersByDefault,
                                                          DosecastAPIEnableManagedDrugUpdates,
                                                          DosecastAPIWarnOnEmailingDrugInfo,
                                                          DosecastAPIEnableShowArchivedDrugs,
                                                          DosecastAPIShowArchivedDrugsByDefault,
                                                          DosecastAPIDisplayUnarchivedDrugStatusInDrugInfo,
                                                          nil]
                                         persistentFlags:[NSArray arrayWithObjects:nil]];

    spinnerViewController = [[SpinnerViewController alloc] init];
    progressViewController = [[ProgressViewController alloc] init];

    tabBarController = [[UITabBarController alloc] init];
    tabBarController.delegate = self;
    
    [self buildTabBarControllers];
    tabBarController.selectedViewController = [tabBarController.viewControllers objectAtIndex:0];
    
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        tabBarController.moreNavigationController.navigationBar.barTintColor = navBarColor;
        tabBarController.moreNavigationController.navigationBar.tintColor = [UIColor whiteColor];
        tabBarController.tabBar.tintColor = [UIColor whiteColor];
        
        NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:tabBarController.navigationController.navigationBar.titleTextAttributes];
        [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
        tabBarController.navigationController.navigationBar.titleTextAttributes = titleTextAttributes;
        
        [[UINavigationBar appearance] setBarTintColor:navBarColor];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        
        [[UIToolbar appearance] setBarTintColor:navBarColor];
        [[UIToolbar appearance] setTintColor:[UIColor whiteColor]];
    }
    else
    {
        tabBarController.moreNavigationController.navigationBar.tintColor = navBarColor;
        
        [[UINavigationBar appearance] setTintColor:navBarColor];
        [[UIToolbar appearance] setTintColor:[DosecastUtil getToolbarColor]];
    }
    
    window.rootViewController = tabBarController;
    [window addSubview:tabBarController.view];

    [window makeKeyAndVisible];
    
    // Setup activity indicator view
    self.m_ai = [[VCActivityIndicator alloc] init];
    CGRect r = self.m_ai.view.frame;
    r.origin.y = 61.0;
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    
    if (screenBounds.size.height == 568) {
        // code for 4-inch screen
        r.size.height = r.size.height + 50;
        r.origin.y = r.origin.y+5;
	} else {
        // code for 3.5-inch screen
    }

    self.m_ai.view.frame = r;
    [self.window addSubview:self.m_ai.view];
    
    // Setup message view
    self.m_msgVC = [[MessageVC alloc] init];
    [window addSubview:self.m_msgVC.view];
    [self.m_msgVC hide];
    
	// Adding a splashview so that we do not show any blank screens in various scenarios.
	self.splashView = [[UIImageView alloc] init];
	[self.splashView setAutoresizesSubviews:NO];
	self.splashView.contentMode = UIViewContentModeScaleAspectFit;
    
	//TODO: We need to remove the hardcoded values for the frames and use the frame of the view controllers view.
	if ([Utilities isiPhone5]) {
		self.splashView.frame = CGRectMake(0, 13, 320, 568);
		self.splashView.image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Default-568h@2x" ofType:@"png"]];
	} else {
		self.splashView.frame = CGRectMake(0, 13, 320, 480);
		self.splashView.image = [UIImage imageNamed:@"Default.png"];
	}
    
	[self.window addSubview:self.splashView];
	self.splashView.alpha = 0.0;
    
	return YES;
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
	[dosecastAPI didRegisterForRemoteNotificationsWithDeviceToken:devToken];
}

// Get the currently active navigation controller 
- (UINavigationController*)getUINavigationController
{
    UIViewController* viewController = tabBarController.selectedViewController;
    if ([viewController isKindOfClass:[UINavigationController class]])
        return (UINavigationController*)viewController;
    else
        return viewController.navigationController;
}

// Callback for when UI initialization is complete. The DosecastAPI view controllers must not be made visible until
// after this call is made
- (void)handleDosecastUIInitializationComplete
{
    isInitializingDosecast = NO; // Flag that we're done initializing Dosecast
    
    // Set the version string
	NSMutableString* versionStr = [NSMutableString stringWithFormat:@"Version %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    
#ifdef DEBUG
	[versionStr appendString:@" (Debug)"];
#endif
    
	dosecastAPI.productVersion = versionStr;
    
    // If merlin is waiting on us, dismiss it now
    if (!isMerlinPerformingActivation && self.m_vcMerlin)
    {
        if (!dosecastAPI.userRegistered)
        {
            // Store the userId in dosecast
            dosecastAPI.userData = [AuthorizationMan get].userId;
            
            [self showAi];
            [dosecastAPI registerUser];
        }
        else // If we're done initializing and registering Dosecast, dismiss merlin now
        {
            [self dismissMerlin];
        }
    }
}

// Button-click callback when UIAlertView appears and "Try Again" button is pressed
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{	
    if (alertView == registrationErrorAlert)
    {
        [self showAi];
        [dosecastAPI registerUser];
    }
    else if (alertView == signOutConfirmation)
    {
        if (buttonIndex == 1) // Yes
        {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"flagSignOn"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[IdleTimerMan get] killTimer];
            /* not need to clear the last Sync time on sign out
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"LastSyncTime"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SYNCTIME_UPDATE_NOTIFICATION" object:nil];
            */
            [[Utilities getAppDel] showMerlin];
            
            tabBarController.selectedIndex = 0;
        }
    }
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

// Callback for when Dosecast registration completes. If an error occurred, errorMessage will be non-nil.
- (void)handleDosecastRegistrationComplete:(NSString*)errorMessage
{
    [self hideAi];
    
    if (errorMessage)
    {
        registrationErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Try Again"
                                                  otherButtonTitles:nil];
        [registrationErrorAlert setMessage:errorMessage];
        [registrationErrorAlert show];
    }
    else
    {        
        // Since merlin is waiting on us, dismiss it now
        if (!isMerlinPerformingActivation && self.m_vcMerlin)
        {
            [self dismissMerlin];
        }
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	[dosecastAPI didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
	[dosecastAPI didReceiveRemoteNotification:userInfo];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
	[dosecastAPI didFailToRegisterForRemoteNotificationsWithError:err];
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message
{
    if (!allowSpinnerProgressViewController)
        return;
    
    spinnerViewController.message = message;
    [spinnerViewController showInView:window];
}

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (!allowSpinnerProgressViewController)
        return;
    
    spinnerViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation
{
    if (!allowSpinnerProgressViewController)
        return;
    
    [spinnerViewController hide:allowAnimation];
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress // A number between 0 and 1
{
    if (!allowSpinnerProgressViewController)
        return;
    
    progressViewController.message = message;
    progressViewController.progress = progress;
    [progressViewController showInView:window];
}

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress // A number between 0 and 1
{
    if (!allowSpinnerProgressViewController)
        return;
    
    progressViewController.progress = progress;
}

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (!allowSpinnerProgressViewController)
        return;
    
    progressViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation
{
    if (!allowSpinnerProgressViewController)
        return;
    
    [progressViewController hide:allowAnimation];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[IdleTimerMan get] killTimer];
    
    [self.window bringSubviewToFront:self.splashView];
	self.splashView.alpha = 1.0;
    LOG("back : - %@",[NSDate date]);
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"BackGroundTime"];
    [[NSUserDefaults standardUserDefaults] synchronize];    
    
    [dosecastAPI applicationWillResignActive:application];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [dosecastAPI applicationDidEnterBackground:application];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    //[[IdleTimerMan get] resetIdleTimer];
    
    [dosecastAPI applicationWillEnterForeground:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    needsApplicationDidBecomeActiveCall = YES;
    BOOL hasMerlinShown = [Utilities AppBecomeActiveActions];
    
    // Do not call [dosecastAPI applicationDidBecomeActive] yet if the merlin was shown. In this case, we need to postpone this call until the merlin is dismissed.
    if (!hasMerlinShown)
    {
        needsApplicationDidBecomeActiveCall = NO;
        [dosecastAPI applicationDidBecomeActive:application];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [dosecastAPI applicationWillTerminate:application];
}

- (void)showMerlin
{
    [Utilities getAppDel].splashView.alpha=0.0;
    [self showMerlinWithState:INITIALIZE];
}

- (void)showMerlinWithState:(WIZARD_STATE)eWizardState
{
    UIViewController* vc = [self getUINavigationController];
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self showMerlinWithVC:vc andState:(WIZARD_STATE)eWizardState];
}

- (void)showMerlinWithVC:(UIViewController*)vcBase andState:(WIZARD_STATE)eWizardState
{
    dosecastAPI.notificationsPaused = YES; // pause overdue dose alerts
    dosecastAPI.lazyServerUpdatesPaused = YES; // pause lazy server updates

    if (nil != self.m_vcMerlin)
    { 
        // Temporarily disable use of the spinner & progress view controller. Dismissing the modal view controller and then
        // presenting it again below will trigger a refresh, and we don't want to see that while merlin is active.
        allowSpinnerProgressViewController = NO;

        [vcBase dismissViewControllerAnimated:NO completion:nil];

        self.m_vcMerlin = nil;
    } 
    self.m_vcMerlin = [[VCGeneralDialog alloc] initWithState:eWizardState]; 
    self.m_vcMerlin.m_delegate = self;
    [vcBase presentViewController:self.m_vcMerlin animated:NO completion:nil];
    
    isMerlinPerformingActivation = YES; // Flag that merlin is performing activation
    allowSpinnerProgressViewController = YES;
}

- (void)dismissMerlin
{
    [[self getUINavigationController] dismissViewControllerAnimated:NO completion:nil];

    self.m_vcMerlin = nil;
    if (self.delegate)
    {
        [self.delegate merlinClosed];
    }
    
    dosecastAPI.notificationsPaused = NO; // resume overdue dose alerts
    dosecastAPI.lazyServerUpdatesPaused = NO; // resume lazy server updates

    // Inform the Dosecast API that we became active now. We didn't do this earlier because the merlin was still visible
    if (needsApplicationDidBecomeActiveCall)
    {
        needsApplicationDidBecomeActiveCall = NO;
        [dosecastAPI applicationDidBecomeActive:[UIApplication sharedApplication]];
    }
}

#pragma mark - VCMerlinDelegate
- (void)dismissModal
{    
    isMerlinPerformingActivation = NO; // Flag that merlin is done performing activation
    
    if (!isInitializingDosecast)
    {
        if (!dosecastAPI.userRegistered)
        {
            // Store the userId in dosecast
            dosecastAPI.userData = [AuthorizationMan get].userId;
            
            [self showAi];
            [dosecastAPI registerUser];
        }
        else // If we're done initializing and registering Dosecast, dismiss merlin now
        {
            [self dismissMerlin];
        }
    }
}

- (void)showAi
{
    [self showAi:nil];
}

- (void)showAi:(NSString*)szText
{
    if (szText && [szText length] > 0)
    {
        self.m_ai.m_lbText.text = szText;
    }
    [self.m_ai show];    
}

- (void)hideAi
{
    NSString *lbText=self.m_ai.m_lbText.text;
    if (lbText && [lbText length] > 0)
    {
        self.m_ai.m_lbText.text = nil;
    }    
    [self.m_ai hide];
}

// The client App should choose their own way of defining the App display name
-(NSString *)getAppDisplayName{
    return [DosecastUtil getProductAppName];    
}

- (NSString *)appVersion
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

// These are placeholder method to keep Activation Library project being standalone and runnable or some UIViewController become runnable
- (void)hideMessage
{
    [self.m_msgVC hide];
}

- (void)setFullMode
{
}

- (void)setFullModeWithCheck
{
}

- (void)setFacOnlyMode
{
}

- (void)facOnly
{
}

- (double)getLastMemberMedsSyncTime
{
    return [dosecastAPI.lastManagedUpdate timeIntervalSince1970];
}

- (void)clearAllData {
    
    // Avoid asking the activation library to reset the device because it should only happen when the user initiates a device reset
    shouldAvoidResettingDevice = YES;
    
    [dosecastAPI deleteAllData];
}


- (int)getAppEnvironment
{
    return 5;
/*
    NSString* env = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AppEnv"];
    int envType = 0;
    
    if ([env isEqualToString:@"QA"] || [env isEqualToString:@"ALPHA"])
    {
        envType = 1;
    } else if ([env isEqualToString:@"PROD"] || [env isEqualToString:@"LIVE"] || [env isEqualToString:@"ITUNES"])
    {
        envType = 2;
    }
    else if ([env isEqualToString:@"PP"] || [env isEqualToString:@"BETA"])
    {
        envType = 3;
    }
    else if ([env isEqualToString:@"LOCAL"])
    {
        envType = 4;
    }
    else if ([env isEqualToString:@"DEV"])
    {
        envType = 5;
    }
    return envType;
 */
}


- (NSString*)getAppEnvironmentAsString
{
    return @"DEV";
    /*
     NSString* env = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AppEnv"];
     
     return env;
     */
}

@end

