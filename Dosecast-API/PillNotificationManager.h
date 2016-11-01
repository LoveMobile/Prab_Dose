//
//  PillNotificationManager.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/12/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PillNotificationManagerDelegate.h"
#import "PillAlertViewControllerDelegate.h"
#import "TakePillHandlerDelegate.h"
#import "SkipPillHandlerDelegate.h"
#import "LocalNotificationManagerDelegate.h"
#import "PostponePillHandlerDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@class PillAlertViewController;
@class TakePillHandler;
@class SkipPillHandler;
@class PostponePillHandler;

// This class handles pill notifications received while the app is running
@interface PillNotificationManager : NSObject<PillAlertViewControllerDelegate,
                                              TakePillHandlerDelegate,
                                              SkipPillHandlerDelegate,
                                              PostponePillHandlerDelegate,
                                              LocalNotificationManagerDelegate>
{
@private
	PillAlertViewController* pillAlertViewController;
	BOOL receivedPillNotification;
	BOOL notificationsPaused;
	BOOL allowNotificationSound;
	NSObject<PillNotificationManagerDelegate>* __weak delegate;
    BOOL isViewingDrugFromOverdueDoseAlert;
    BOOL canRefreshDrugState;
    BOOL needsRefreshDrugState;
    BOOL suppressOverdueDoseAlert;
    BOOL isResolvingOverdueDrug;
    BOOL isGetStateInProgress;
    TakePillHandler* takePillHandler;
    SkipPillHandler* skipPillHandler;
    PostponePillHandler* postponePillHandler;
    NSMutableDictionary* disabledReminderTimerDict; // Dictionary containing a timer for each disabled reminder time
    AVAudioPlayer* player;
}

// Singleton methods
+ (PillNotificationManager*) getInstance;

// Called to refresh all drug state. Returns whether successful.
- (BOOL)refreshDrugState:(BOOL)force;

// Hides the overdue pill alert if it's visible
- (void)hideOverduePillAlertIfVisible:(BOOL)animated;

// Called when pill notification occurs from within app
- (void)handlePillNotification;

// Called to handle a request to take the given drugs
- (void)performTakePills:(NSArray*)drugIds sourceButton:(UIButton*)button;

// Called to handle a request to skip the given drugs
- (void)performSkipPills:(NSArray*)drugIds displayActions:(BOOL)displayActions sourceButton:(UIButton*)button;

// Called to handle a request to postpone the given drugs
- (void)performPostponePills:(NSArray*)drugIds sourceButton:(UIButton*)button;

// Returns the minimum postpone period in minutes
- (int) minimumPostponePeriodMin;

// Returns whether the user is resolving an overdue dose alert
- (BOOL) isResolvingOverdueDoseAlert;

@property (nonatomic, assign) BOOL notificationsPaused; // Set to temporarily pause and later resume notifications
@property (nonatomic, weak) NSObject<PillNotificationManagerDelegate>* delegate;
@property (nonatomic, assign) BOOL canRefreshDrugState;
@property (nonatomic, assign) BOOL needsRefreshDrugState;
@property (nonatomic, assign) BOOL suppressOverdueDoseAlert;

@end
