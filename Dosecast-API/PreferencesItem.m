//
//  PreferencesItem.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "PreferencesItem.h"
#import "DosecastUtil.h"
#import "DataModel.h"

static NSString *ModifiedDateKey = @"modified";
static NSString *ValueKey = @"value";
static NSString *PerDeviceKey = @"perDevice";
static NSString *ServerEditSourceKey = @"serverEditSource";

@implementation PreferencesItem

- (id)init
{
    return [self init:nil perDevice:NO persistLocally:NO persistOnServer:NO value:nil];
}

- (id)init:(NSDate*)modDate
 perDevice:(BOOL)perDev
persistLocally:(BOOL)persistLocal
persistOnServer:(BOOL)persistServer
     value:(NSString*)val
{
    if ((self = [super init]))
    {
        if (!val)
            val = @"";
        
        modifiedDate = modDate;
        value = val;
        perDevice = perDev;
        persistLocally = persistLocal;
        persistOnServer = persistServer;
	}
	
    return self;	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[PreferencesItem alloc] init:[modifiedDate copyWithZone:zone]
                               perDevice:perDevice
                          persistLocally:persistLocally
                         persistOnServer:persistOnServer
                                  value:[value mutableCopyWithZone:zone]];
}

// Read all values from the given dictionary
- (void) readFromDictionary:(NSMutableDictionary*)dict storeModifiedDate:(BOOL)storeModifiedDate
{
    NSNumber* modifiedDateNum = [dict objectForKey:ModifiedDateKey];
    NSDate* modDate = nil;
    if (storeModifiedDate && modifiedDateNum && [modifiedDateNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        modDate = [NSDate dateWithTimeIntervalSince1970:[modifiedDateNum longLongValue]];
    }
    modifiedDate = modDate;

    NSString* val = [dict objectForKey:ValueKey];
    if (!val)
        val = @"";
    value = val;

    NSNumber* perDeviceNum = [dict objectForKey:PerDeviceKey];
    BOOL perDev = NO;
    if (perDeviceNum)
        perDev = ([perDeviceNum intValue] == 1 ? YES : NO);
    perDevice = perDev;
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict storeModifiedDate:(BOOL)storeModifiedDate
{
    if (!dict)
        return;
    
    if (storeModifiedDate && modifiedDate)
    {
        NSNumber* modifiedDateNum = [NSNumber numberWithLongLong:(long long)[modifiedDate timeIntervalSince1970]];
        [dict setObject:modifiedDateNum forKey:ModifiedDateKey];
    }

    if (value)
        [dict setObject:value forKey:ValueKey];
    
    [dict setObject:[NSNumber numberWithInt:(perDevice ? 1 : 0)] forKey:PerDeviceKey];
}

// Update from provided server dictionary. Returns whether updated.
- (BOOL) updateFromServerDictionary:(NSMutableDictionary *)dict storeModifiedDate:(BOOL)storeModifiedDate currentServerTime:(NSDate *)currentServerTime
{
    BOOL updated = NO;
    
    if (!dict)
        return updated;
    
    NSNumber* modifiedDateNum = [dict objectForKey:ModifiedDateKey];
    NSDate* modDate = nil;
    if (storeModifiedDate && modifiedDateNum && [modifiedDateNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        modDate = [NSDate dateWithTimeIntervalSince1970:[modifiedDateNum longLongValue]];
    }
    
    NSString* serverEditSource = [dict objectForKey:ServerEditSourceKey];

    NSString* val = [dict objectForKey:ValueKey];
    
    NSNumber* perDeviceNum = [dict objectForKey:PerDeviceKey];
    BOOL perDev = perDevice;
    if (perDeviceNum)
        perDev = ([perDeviceNum intValue] == 1 ? YES : NO);

    if (val)
    {
        NSDate* localServerEditTime = nil;
        if (currentServerTime && modDate)
        {
            NSTimeInterval serverInterval = [currentServerTime timeIntervalSinceDate:modDate];
            localServerEditTime = [[NSDate date] dateByAddingTimeInterval:-serverInterval];
        }
        
        BOOL allowSource = (!serverEditSource || ![serverEditSource isEqualToString:[DataModel getInstance].hardwareID]);
        BOOL isModifiedLater = (!localServerEditTime || [localServerEditTime timeIntervalSinceDate:modifiedDate] > 0);
        BOOL isGlobalAndValueChanged = (!perDevice && !perDev && (!value || ![value isEqualToString:val]));
        BOOL isSwitchingFromGlobalToPerDev = (!perDevice && perDev);
        
        // See if the server's edit occurred later than ours
        if (!modifiedDate ||
            (allowSource && isModifiedLater && (isGlobalAndValueChanged || isSwitchingFromGlobalToPerDev)))
        {
            value = val;
            modifiedDate = modDate;
            perDevice = perDev;
            updated = YES;
        }
    }
    
    return updated;
}

- (NSString*) value
{
    return value;
}

- (void) setValue:(NSString*)val storeModifiedDate:(BOOL)storeModifiedDate
{
    if (!val)
        val = @"";
    
    // Allow the same value to be set to allow the modified date to be changed
    
    value = val;
    if (storeModifiedDate)
        modifiedDate = [NSDate date];
}

- (BOOL) perDevice
{
    return perDevice;
}

- (void) setPerDevice:(BOOL)perDev storeModifiedDate:(BOOL)storeModifiedDate
{
    if (perDevice && !perDev) // don't allow to switch from perDevice to Global
        return;
    
    // Allow the same value to be set to allow the modified date to be changed

    perDevice = perDev;
    if (storeModifiedDate)
        modifiedDate = [NSDate date];
}

- (NSDate*) modifiedDate
{
    return modifiedDate;
}

- (BOOL) persistLocally
{
    return persistLocally;
}

- (BOOL) persistOnServer
{
    return persistOnServer;
}

@end
