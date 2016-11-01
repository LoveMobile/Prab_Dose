//
//  DataModelDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//


@protocol DataModelDelegate

@required

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

// Callback for when user attempts to change the passcode
- (void)handleChangePasscode;

// Callback for when user attempts to delete all data
- (void)handleDeleteAllData;

// Callback for whether or not the user is registered
- (BOOL)userRegistered;

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService;

@end
