//
//  DosecastAPIDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 9/26/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

@protocol DosecastAPIDelegate

@required

// Callback for when UI initialization is complete. The DosecastAPI view controllers must not be made visible until
// after this call is made
- (void)handleDosecastUIInitializationComplete;

// Callback for when Dosecast registration completes. If an error occurred, errorMessage will be non-nil.
- (void)handleDosecastRegistrationComplete:(NSString*)errorMessage;

// Callback for when the Dosecast component must be made visible. If Dosecast is embedded in a UITabBarController
// or other UI component, this component must be made visible at the time of this call if it is not already.
- (void)displayDosecastComponent;

// Callback to find out if the Dosecast component is visible. If Dosecast is embedded in a UITabBarController
// or other UI component, return whether the component is active/selected.
- (BOOL)isDosecastComponentVisible;

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message;

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message;

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation;

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress; // A number between 0 and 1

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress; // A number between 0 and 1

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message;

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation;

// Callback for when an alert message should be displayed to the user
- (void)displayAlertMessageToUser:(NSString*)message;

// Get the currently active navigation controller 
- (UINavigationController*)getUINavigationController;

@optional

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService;

// Callback for when user attempts to change the passcode
- (void)handleChangePasscode;

// Callback for when user attempts to delete all data
- (void)handleDeleteAllData:(NSString*)errorMessage;

// Callback for when a subscription is purchased
- (void)handleSubscriptionPurchased;

@end