//
//  ScheduleViewDoseTime.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "ScheduleViewDoseTime.h"

@implementation ScheduleViewDoseTime
@synthesize doseTime;
@synthesize scheduleViewDoses;

- (id)init
{
    return [self init:nil scheduleViewDoses:nil];	
}

- (id)init:(NSDate*)time scheduleViewDoses:(NSArray*)doses
{
	if ((self = [super init]))
    {
		doseTime = time;
        if (!doses)
            doses = [[NSArray alloc] init];
		scheduleViewDoses = [[NSMutableArray alloc] initWithArray:doses];
	}
	
    return self;		
}


@end
