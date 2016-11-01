//
//  ScheduleViewDose.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "ScheduleViewDose.h"
#import "HistoryEvent.h"

@implementation ScheduleViewDose
@synthesize drugID;
@synthesize doseTime;
@synthesize historyEvent;
@synthesize isLastAction;
@synthesize isNextAction;
@synthesize doseLimitCheckDate;

- (id)init
{
    return [self init:nil doseTime:nil historyEvent:nil doseLimitCheckDate:nil isLastAction:NO isNextAction:NO];
}

- (id)init:(NSString*)dID
  doseTime:(NSDate*)time
historyEvent:(HistoryEvent*)event
doseLimitCheckDate:(NSDate*)date
isLastAction:(BOOL)lastAction
isNextAction:(BOOL)nextAction
{
	if ((self = [super init]))
    {
		drugID = dID;
        doseTime = time;
        historyEvent = event;
        doseLimitCheckDate = date;
        isLastAction = lastAction;
        isNextAction = nextAction;
	}
	
    return self;		
}


@end
