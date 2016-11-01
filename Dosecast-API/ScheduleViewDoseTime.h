//
//  ScheduleViewDoseTime.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScheduleViewDoseTime : NSObject
{
@private
	NSDate* doseTime;                  // a particular dose time
	NSMutableArray* scheduleViewDoses; // an array of schedule view doses that are due at the dose time
}

- (id)init:(NSDate*)time scheduleViewDoses:(NSArray*)doses;

@property (nonatomic, strong) NSDate* doseTime;
@property (nonatomic, strong) NSMutableArray* scheduleViewDoses;

@end
