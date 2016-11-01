//
//  StringListItem.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "StringListItem.h"
#import "DosecastUtil.h"
#import "DataModel.h"

static NSString *GuidKey = @"guid";
static NSString *ModifiedDateKey = @"modified";
static NSString *ValueKey = @"value";
static NSString *ServerEditSourceKey = @"serverEditSource";

@implementation StringListItem

@synthesize modifiedDate;

- (id)init
{
	return [self init:nil value:nil];
}

- (id)init:(NSDate *)m
      value:(NSString *)v
{
    if ((self = [super init]))
    {
        if (!m)
            m = [NSDate date];
        if (!v)
            v = @"";
        modifiedDate = m;
		value = v;
	}
	
    return self;	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[StringListItem alloc] init:[modifiedDate copyWithZone:zone]
                                  value:[value mutableCopyWithZone:zone]];
}

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*)dict
{
    NSNumber* modifiedDateNum = [dict objectForKey:ModifiedDateKey];
    NSDate* m = nil;
    if (modifiedDateNum && [modifiedDateNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        m = [NSDate dateWithTimeIntervalSince1970:[modifiedDateNum longLongValue]];
    }

    NSString* v = [dict objectForKey:ValueKey];

    return [self init:m value:v];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict
{
    if (!dict)
        return;
    
    if (modifiedDate)
    {
        NSNumber* modifiedDateNum = [NSNumber numberWithLongLong:(long long)[modifiedDate timeIntervalSince1970]];
        [dict setObject:modifiedDateNum forKey:ModifiedDateKey];
    }

    if (value)
        [dict setObject:value forKey:ValueKey];
}

// Update state from provided server dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary *)dict currentServerTime:(NSDate *)currentServerTime
{
    if (!dict)
        return;
    
    NSNumber* modifiedDateNum = [dict objectForKey:ModifiedDateKey];
    NSDate* m = nil;
    if (modifiedDateNum && [modifiedDateNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        m = [NSDate dateWithTimeIntervalSince1970:[modifiedDateNum longLongValue]];
    }
    
    NSString* serverEditSource = [dict objectForKey:ServerEditSourceKey];

    NSString* v = [dict objectForKey:ValueKey];
    
    if (m && v && serverEditSource)
    {
        NSDate* localServerEditTime = nil;
        if (currentServerTime)
        {
            NSTimeInterval serverInterval = [currentServerTime timeIntervalSinceDate:m];
            localServerEditTime = [[NSDate date] dateByAddingTimeInterval:-serverInterval];
        }
        
        // See if the server's edit occurred later than ours
        if (![serverEditSource isEqualToString:[DataModel getInstance].hardwareID] &&
            (!localServerEditTime || [localServerEditTime timeIntervalSinceDate:modifiedDate] > 0) &&
            (!value || ![value isEqualToString:v]))
        {
            value = v;
            modifiedDate = m;
        }
    }
}

- (NSString*) value
{
    return value;
}

- (void) setValue:(NSString *)val
{
    if (!val)
        val = @"";
    
    if ([value isEqualToString:val])
        return;
    
    value = val;
    modifiedDate = [NSDate date];
}

@end
