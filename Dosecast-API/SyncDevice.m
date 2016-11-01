//
//  SyncDevice.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "SyncDevice.h"
#import "DosecastUtil.h"
#import "DataModel.h"

@implementation SyncDevice

@synthesize friendlyName;
@synthesize hardwareID;
@synthesize lastSeen;

- (id)init
{
    return [self init:nil hardwareID:nil lastSeen:nil];
}

-(id)init:(NSString*)name
hardwareID:(NSString*)hwID
 lastSeen:(NSDate*)last
{
    if ((self = [super init]))
    {
        if (!name)
            name = @"";
        friendlyName = name;
        if (!hwID)
            hwID = @"";
        hardwareID = hwID;
        lastSeen = last;
    }
    
    return self;
}

- (BOOL) isCurrentDevice
{
    return [hardwareID isEqualToString:[DataModel getInstance].hardwareID];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SyncDevice alloc] init:[friendlyName mutableCopyWithZone:zone]
                   hardwareID:[hardwareID mutableCopyWithZone:zone]
                   lastSeen:[lastSeen copyWithZone:zone]];
}


@end
