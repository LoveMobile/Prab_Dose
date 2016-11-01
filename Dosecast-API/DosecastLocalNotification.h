//
//  DosecastLocalNotification.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/26/14.
//  Copyright (c) 2014 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DosecastLocalNotification : NSObject
{
@private
    UILocalNotification* notification;
    BOOL isScheduled;
    BOOL needsScheduling;
    BOOL needsCancelling;
}

- (id)init:(UILocalNotification*)n
isScheduled:(BOOL)scheduled;

// requests that this notification be scheduled with the OS
- (void)requestSchedule;

// requests that this notification be cancelled with the OS
- (void)requestCancel;

// Commits any request
- (void)commit;

+ (NSArray*) createFromScheduledLocalNotifications;

@property(nonatomic, readonly) NSDate *fireDate;
@property(nonatomic, readonly) NSDictionary *userInfo;
@property(nonatomic, readonly) NSCalendarUnit repeatInterval;
@property(nonatomic, readonly) BOOL isScheduled;

@end
