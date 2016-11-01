//
//  HistoryAddEditEventViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 
#import "DosecastCoreTypes.h"

@class EditableHistoryEvent;
@protocol HistoryAddEditEventViewControllerDelegate

@required

// Returns whether to allow the given add/edit event
- (BOOL)handleAddEditEventComplete:(NSString*)drugId
                        actionName:(NSString*)actionName
                postponePeriodSecs:(int)postponePeriodSecs
                         eventTime:(NSDate*)eventTime
                     scheduledTime:(NSDate*)scheduledTime
                      refillAmount:(float)refillAmount;

@optional

// Callback for when user hits cancel
- (void)handleCancelAddEditEvent;

@end
