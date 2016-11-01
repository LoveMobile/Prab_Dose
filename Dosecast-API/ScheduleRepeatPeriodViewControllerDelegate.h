//
//  ScheduleRepeatPeriodViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol ScheduleRepeatPeriodViewControllerDelegate

@required

// Callback for scheduleRepeatPeriodDays value
// Returns whether the new value is accepted.
- (BOOL)handleSetScheduleRepeatPeriodValue:(int)scheduleRepeatPeriodNum
                      scheduleRepeatPeriod:(int)scheduleRepeatPeriod
				               forNibNamed:(NSString*)nibName
					            identifier:(int)uniqueID; // a unique identifier for the current picker

@optional

// Callback for when user hits cancel
- (void)handleCancelScheduleRepeatPeriod:(int)uniqueID;

@end
