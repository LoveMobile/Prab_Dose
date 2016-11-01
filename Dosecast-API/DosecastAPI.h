//
//  DosecastAPI.h
//  Dosecast
//
//  Created by Jonathan Levene on 9/26/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"

@protocol DosecastAPIDelegate;

// This protocol is the API to the Dosecast functionality. An instance of this class
// should be created by the App Delegate, and most App Delegate methods should be
// passed through.

@interface DosecastAPI : NSObject

// Create an instance of the Dosecast API with delegate and launch options. After calling, the client must wait until the delegate's
// handleDosecastUIInitializationComplete method is called before displaying any of this object's view controllers.
+(DosecastAPI*) createDosecastAPIInstanceWithDelegate:(NSObject<DosecastAPIDelegate>*)delegate
                                                  launchOptions:(NSDictionary*)launchOptions                     // The launchOptions passed to the ApplicationDelegate's didFinishLaunchingWithOptions method
                                                       userData:(NSString*)userData                              // Optional custom data to be stored about the current user (such as an account ID)
                                                       apiFlags:(NSArray*)apiFlags                               // An array of Dosecast API flags to enable (if a flag is not included, it is considered disabled)
                                                persistentFlags:(NSArray*)persistentFlags                        // An array of strings corresponding to persistent flags to write to & read from the Dosecast data file
                                                 productVersion:(NSString*)productVersion;                       // The version of the product that the API is running in

// Method to asyncronously register the current user. Will be notified of result in DosecastAPIDelegate's handleDosecastRegistrationComplete method
-(void)registerUser;

// Factory methods for creating view controllers, as needed
- (UIViewController*) createMainViewController;                                 // Factory method for creating the main view
- (UIViewController*) createScheduleViewController;                             // Factory method for creating the schedule view
- (UIViewController*) createDrugsViewController;                                // Factory method for creating the drugs view
- (UIViewController*) createSettingsViewController;                             // Factory method for creating the settings view
- (UIViewController*) createHistoryViewController:(NSString*)personId;          // Factory method for creating the history view. personId is the ID of the person whose drugs should be displayed. If 'me', use nil.
- (UIViewController*) createAccountViewController;                              // Factory method for creating the account view

// A string containing an HTML description of the entire drug list
- (NSString*) getDrugListHTMLDescription;
// Return the drug history as a string for the personID provided
- (NSString*) getDrugHistoryString:(NSString*)personId;
// Return the drug history as a CSV file for the personID provided
- (NSData*) getDrugHistoryCSVFile:(NSString*)personId;
// A string containing key diagnostic information
- (NSString*) getKeyDiagnostics;
// The debug log in the form of a CSV file (for attachment in an email)
- (NSData*) getDebugLogCSVFile;
// Perform a deletion of all data.
- (void) deleteAllData;

// Returns the terms of service addenda from all groups the user joined
- (NSString*)getGroupTermsOfServiceAddenda;

// Returns whether any group gives a premium license away
- (BOOL)doesAnyGroupGivePremium;

- (void) getListOfPersonNames:(NSArray**)personNames andCorrespondingPersonIds:(NSArray**)personIds; // returns an array of person names and a corresponding array of ids, sorted by name alphabetically

// Methods to get & set persistent flags. Flag names must have been passed into the list of persistent flags at initialization time.
-(BOOL)getPersistentFlag:(NSString*)flagName; // Returns NO if flag not found
-(void)setPersistentFlag:(NSString*)flagName value:(BOOL)val;

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
-(void)applicationDidReceiveMemoryWarning:(UIApplication *)application;
-(void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

@property (weak, nonatomic, readonly) NSString* apiVersion;							// The Dosecast API version
@property (weak, nonatomic, readonly) NSString* productVersion;                     // The product version
@property (nonatomic, readonly) BOOL userRegistered;                                // Whether or not the user is registered
@property (nonatomic, weak, readonly) NSObject<DosecastAPIDelegate>* delegate;      // The delegate
@property (nonatomic, readonly) BOOL internetConnection;                            // Whether or not the device has an internet connection
@property (nonatomic, readonly) BOOL userInteractionsAllowed;                       // Whether or not user interactions with Dosecast are currently allowed
@property (nonatomic, strong) NSString* userData;                                   // Custom data to be stored about the current user (such as an account ID)
@property (weak, nonatomic, readonly) NSString* userIDAbbrev;                       // An abbreviation of the user ID for displaying to the user
@property (weak, nonatomic, readonly) NSDate* accountCreated;                       // The date the account was created
@property (weak, nonatomic, readonly) NSDate* appLastOpened;                        // The date the app was last opened
@property (weak, nonatomic, readonly) NSDate* lastManagedUpdate;                    // The date of the last managed update from the Dosecast server
@property (nonatomic, readonly) AccountType accountType;                            // The type of account (demo, premium, or subscription)
@property (nonatomic, readonly) NSDate* subscriptionExpires;                        // The the date when the subscription expires (if a subscription account)
@property (nonatomic, readonly) int doseHistoryDays;                                // The number of days of dose history retained
@property (nonatomic, assign) BOOL notificationsPaused;                             // Whether overdue dose notifications should be paused temporarily
@property (nonatomic, readonly) BOOL isResolvingOverdueDoseAlert;                   // Whether the user is resolving an overdue dose alert

@end