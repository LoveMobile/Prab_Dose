//
//  GNCDosecastAPI.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//
#import <CoreData/CoreData.h>
#import <MessageUI/MFMailComposeViewController.h>

@protocol DosecastAPI;
@protocol DosecastAPIDelegate;

// This class is the API to the Dosecast functionality. An instance of this class
// should be created by the App Delegate, and most App Delegate methods should be
// passed through.

@interface GNCDosecastAPI : NSObject <MFMailComposeViewControllerDelegate>
{
@private
	NSObject<DosecastAPI>* dosecastAPI;
    UIViewController* mainViewController;
}

// Initializer with delegate and launch options. After initializing, the client must wait until the delegate's
// handleDosecastUIInitializationComplete method is called before displaying any of this object's view controllers.
-(id)initWithDelegate:(NSObject<DosecastAPIDelegate>*)del
        launchOptions:(NSDictionary*)launchOptions
       productVersion:(NSString*)productVersion;                             // The launchOptions passed to the ApplicationDelegate's didFinishLaunchingWithOptions method

// Method to asyncronously register the current user. Will be notified of result in DosecastAPIDelegate's handleDosecastRegistrationComplete method
-(void)registerUser;

// ----- Pass-through calls from App Delegate
-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken;
-(void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;
-(void)didReceiveLocalNotification:(UILocalNotification *)notification;
-(void)didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;
-(void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)err;
-(void)applicationDidEnterBackground:(UIApplication *)application;
-(void)applicationWillEnterForeground:(UIApplication *)application;
-(void)applicationWillResignActive:(UIApplication *)application;
-(void)applicationDidBecomeActive:(UIApplication *)application;
-(void)applicationWillTerminate:(UIApplication *)application;

@property (weak, nonatomic, readonly) UIViewController* mainViewController;           // The main view controller
@property (weak, nonatomic, readonly) NSString* apiVersion;							// The Dosecast API version
@property (nonatomic, readonly) NSString* productVersion;							// The product version
@property (nonatomic, readonly) BOOL userRegistered;								// Whether or not the user is registered
@property (nonatomic, readonly) NSObject<DosecastAPIDelegate>* delegate;		    // The delegate
@property (nonatomic, readonly) BOOL internetConnection;						// Whether or not the device has an internet connection
@property (nonatomic, readonly) BOOL userInteractionsAllowed;                   // Whether or not user interactions with Dosecast are currently allowed
@property (weak, nonatomic, readonly) NSString* userIDAbbrev;                         // An abbreviation of the user ID for displaying to the user
@property (nonatomic, assign) BOOL notificationsPaused;                         // Whether overdue dose notifications should be paused temporarily
@property (nonatomic, readonly) BOOL isResolvingOverdueDoseAlert;               // Whether the user is resolving an overdue dose alert

@end

