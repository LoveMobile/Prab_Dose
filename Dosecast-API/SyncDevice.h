//
//  SyncDevice.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyncDevice : NSObject<NSMutableCopying>
{
@private
    NSString* friendlyName;
    NSString* hardwareID;
    NSDate* lastSeen;
}

    -(id)init:(NSString*)name
   hardwareID:(NSString*)hwID
     lastSeen:(NSDate*)last;

- (BOOL) isCurrentDevice;

@property (nonatomic, readonly) NSString* friendlyName;
@property (nonatomic, readonly) NSString* hardwareID;
@property (nonatomic, readonly) NSDate* lastSeen;

@end
