//
//  ScheduleViewDose.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HistoryEvent;
@interface ScheduleViewDose : NSObject
{
@private
	NSString* drugID;
    NSDate* doseTime;
    NSDate* doseLimitCheckDate;
    HistoryEvent* historyEvent;
    BOOL isLastAction; // Whether this dose was the last dose for this drug to be acted upon
    BOOL isNextAction; // Whether this dose is the next dose for the user to act upon
}

- (id)init:(NSString*)dID
  doseTime:(NSDate*)time
historyEvent:(HistoryEvent*)event
doseLimitCheckDate:(NSDate*)date
isLastAction:(BOOL)lastAction
isNextAction:(BOOL)nextAction;

@property (nonatomic, strong) NSString* drugID;
@property (nonatomic, strong) NSDate* doseTime;
@property (nonatomic, strong) HistoryEvent* historyEvent;
@property (nonatomic, strong) NSDate* doseLimitCheckDate;
@property (nonatomic, assign) BOOL isLastAction;
@property (nonatomic, assign) BOOL isNextAction;

@end
