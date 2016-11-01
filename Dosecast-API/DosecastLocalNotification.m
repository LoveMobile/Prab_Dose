//
//  DosecastLocalNotification.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/26/14.
//  Copyright (c) 2014 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastLocalNotification.h"

@implementation DosecastLocalNotification
@synthesize isScheduled;

- (id)init
{
    return [self init:nil isScheduled:NO];
}

- (id)init:(UILocalNotification*)n
isScheduled:(BOOL)scheduled
{
    if ((self = [super init]))
    {
        notification = n;
        isScheduled = scheduled;
        needsCancelling = NO;
        needsScheduling = NO;
    }
    
    return self;	
}

- (NSDate*) fireDate
{
    if (notification)
        return notification.fireDate;
    else
        return nil;
}

- (NSDictionary*) userInfo
{
    if (notification)
        return notification.userInfo;
    else
        return nil;
}

- (NSCalendarUnit) repeatInterval
{
    if (notification)
        return notification.repeatInterval;
    else
        return nil;
}

- (void) requestSchedule
{
    if (needsScheduling || !notification)
        return;
    
    if (needsCancelling)
        needsCancelling = NO;
    else
        needsScheduling = YES;
}

- (void) requestCancel
{
    if (needsCancelling || !notification)
        return;
    
    if (needsScheduling)
        needsScheduling = NO;
    else
        needsCancelling = YES;
}

- (void) commit
{
    if ((!needsScheduling && !needsCancelling) || !notification)
        return;
    
    if  (needsScheduling)
    {
        if (!isScheduled)
        {
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            isScheduled = YES;
        }
        needsScheduling = NO;
    }
    else if (needsCancelling)
    {
        if (isScheduled)
        {
            [[UIApplication sharedApplication] cancelLocalNotification:notification];
            isScheduled = NO;
        }
        needsCancelling = NO;
    }
}

+ (NSArray*) createFromScheduledLocalNotifications
{
    NSArray* scheduledLocalNotifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
    NSMutableArray* dosecastLocalNotifications = [[NSMutableArray alloc] init];
    
    for (UILocalNotification* n in scheduledLocalNotifications)
    {
        [dosecastLocalNotifications addObject:
         [[DosecastLocalNotification alloc] init:n isScheduled:YES]];
    }
    
    return dosecastLocalNotifications;
}

@end