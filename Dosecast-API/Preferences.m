//
//  Preferences.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "Preferences.h"
#import "PreferencesItem.h"

static NSString *SyncPreferencesKey = @"syncPreferences";
static NSString *LegacyPreferencesKey = @"preferences"; // legacy
static NSString *KeyKey = @"key";
static NSString *ModifiedDateKey = @"modified";
static NSString *ValueKey = @"value";
static NSString *PerDeviceKey = @"perDevice";

@implementation Preferences

- (id)init
{
    return [self init:nil storeModifiedDate:YES];
}

- (id)init:(NSDictionary*)prefDict storeModifiedDate:(BOOL)storeModified
{
    if ((self = [super init]))
    {
        if (!prefDict)
            prefDict = [NSDictionary dictionary];
        prefsByKey = [NSMutableDictionary dictionaryWithDictionary:prefDict];
        storeModifiedDate = storeModified;
    }
    
    return self;
}

// Read all values from the given dictionary. Returns the keys that were read.
- (NSSet*)readFromDictionary:(NSMutableDictionary*)dict
{
    NSMutableSet* readKeys = [[NSMutableSet alloc] init];
    
    NSMutableArray* allPrefs = [dict objectForKey:SyncPreferencesKey];
    if (allPrefs)
    {
        for (NSMutableDictionary* thisPref in allPrefs)
        {
            NSString* key = [thisPref objectForKey:KeyKey];
            if (key)
            {
                PreferencesItem* prefItem = [prefsByKey objectForKey:key];
                // Pass through any unrecognized prefs
                if (!prefItem)
                    prefItem = [[PreferencesItem alloc] init:nil perDevice:NO persistLocally:YES persistOnServer:YES value:@""];

                [prefItem readFromDictionary:thisPref storeModifiedDate:storeModifiedDate];
                [prefsByKey setObject:prefItem forKey:key];
                [readKeys addObject:key];
            }
        }
    }
    
    NSMutableDictionary* legacyPrefs = [dict objectForKey:LegacyPreferencesKey]; // legacy
    if (legacyPrefs)
    {
        NSArray* allKeys = [legacyPrefs allKeys];
        for (NSString* key in allKeys)
        {
            if ([prefsByKey objectForKey:key] && ![readKeys member:key])
            {
                NSString* val = [legacyPrefs objectForKey:key];
                [self setValue:val forKey:key forceUpdate:YES];
                [readKeys addObject:key];
            }
        }
    }

    return readKeys;
}

+ (void) removePrefDictForKey:(NSString*)key inArray:(NSMutableArray*)array
{
    NSUInteger numItems = [array count];
    for (int i = 0; i < numItems; i++)
    {
        NSMutableDictionary* thisPref = [array objectAtIndex:i];
        NSString* thisKey = [thisPref objectForKey:KeyKey];
        if ([thisKey isEqualToString:key])
        {
            [array removeObjectAtIndex:i];
            return;
        }
    }
}

+ (NSMutableDictionary*) findPrefDictForKey:(NSString*)key inArray:(NSMutableArray*)array
{
    for (NSMutableDictionary* thisPref in array)
    {
        NSString* thisKey = [thisPref objectForKey:KeyKey];
        if ([thisKey isEqualToString:key])
        {
            return thisPref;
        }
    }
    
    return nil;
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
    if (!dict)
        return;
    
    NSMutableArray* syncPreferences = [dict objectForKey:SyncPreferencesKey];
    if (!syncPreferences)
        syncPreferences = [[NSMutableArray alloc] init];
    
    NSArray* allKeys = [prefsByKey allKeys];
    for (NSString* key in allKeys)
    {
        PreferencesItem* prefItem = [prefsByKey objectForKey:key];
        if ((forSyncRequest && prefItem.persistOnServer && (!storeModifiedDate || prefItem.modifiedDate)) ||
            (!forSyncRequest && prefItem.persistLocally))
        {
            [Preferences removePrefDictForKey:key inArray:syncPreferences]; // make sure we overwrite this pref if it already exists
            NSMutableDictionary* thisPrefDict = [[NSMutableDictionary alloc] init];
            [thisPrefDict setObject:key forKey:KeyKey];
            [prefItem populateDictionary:thisPrefDict storeModifiedDate:storeModifiedDate];
            [syncPreferences addObject:thisPrefDict];
        }
    }
    
    [dict setObject:syncPreferences forKey:SyncPreferencesKey];
}

- (NSString*) valueForKey:(NSString*)key isPerDevice:(BOOL*)perDevice
{
    if (!key)
        return nil;
    
    if (perDevice)
        *perDevice = NO;
    
    PreferencesItem* prefItem = [prefsByKey objectForKey:key];
    if (prefItem)
    {
        if (perDevice)
            *perDevice = prefItem.perDevice;
        return prefItem.value;
    }
    else
        return nil;
}

- (NSString*) valueForKey:(NSString*)key
{
    BOOL dummy = NO;
    return [self valueForKey:key isPerDevice:&dummy];
}

- (BOOL) setValue:(NSString*)val forKey:(NSString*)key forceUpdate:(BOOL)forceUpdate
{
    if (!key)
        return NO;
    
    PreferencesItem* prefItem = [prefsByKey objectForKey:key];
    if (prefItem &&
        (forceUpdate || (prefItem.value && val && ![val isEqualToString:prefItem.value])))
    {
        [prefItem setValue:val storeModifiedDate:storeModifiedDate];
        return YES;
    }
    else
        return NO;
}

- (BOOL) setValue:(NSString*)val forKey:(NSString*)key
{
    return [self setValue:val forKey:key forceUpdate:NO];
}

- (void) addPreference:(NSString*)key
                 value:(NSString*)val
             perDevice:(BOOL)perDevice
        persistLocally:(BOOL)persistLocally
       persistOnServer:(BOOL)persistOnServer
sendAfterCompletedFirstSync:(BOOL)sendAfterCompletedFirstSync
{
    if (!key)
        return;
    
    PreferencesItem* prefItem = [prefsByKey objectForKey:key];
    if (!prefItem)
    {
        NSDate* modifiedDate = nil;
        if (!sendAfterCompletedFirstSync && storeModifiedDate)
            modifiedDate = [NSDate date];
        [prefsByKey setObject:[[PreferencesItem alloc] init:modifiedDate
                                                  perDevice:perDevice
                                             persistLocally:persistLocally
                                            persistOnServer:persistOnServer
                                                      value:val] forKey:key];
    }
}

- (NSArray*) allKeys
{
    return [prefsByKey allKeys];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[Preferences alloc] init:[prefsByKey mutableCopyWithZone:zone]
                   storeModifiedDate:storeModifiedDate];
}

// Update from provided server dictionary. Returns a set of keys whose values were updated.
- (NSSet*) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime limitToKeys:(NSSet*)limitToKeys
{
    NSMutableSet* changedKeys = [[NSMutableSet alloc] init];
    NSMutableSet* encounteredKeys = [[NSMutableSet alloc] init];
    
    NSMutableArray* allPrefs = [dict objectForKey:SyncPreferencesKey];
    if (allPrefs)
    {
        for (NSMutableDictionary* thisPref in allPrefs)
        {
            NSString* key = [thisPref objectForKey:KeyKey];
            if (key)
            {
                if (!limitToKeys || [limitToKeys member:key])
                {
                    PreferencesItem* prefItem = [prefsByKey objectForKey:key];
                    if (prefItem)
                    {
                        BOOL updated = [prefItem updateFromServerDictionary:thisPref storeModifiedDate:storeModifiedDate currentServerTime:currentServerTime];
                        if (updated)
                            [changedKeys addObject:key];
                    }
                    else // Pass through any unrecognized prefs
                    {
                        prefItem = [[PreferencesItem alloc] init:nil perDevice:NO persistLocally:YES persistOnServer:YES value:@""];
                        [prefItem readFromDictionary:thisPref storeModifiedDate:storeModifiedDate];
                        [changedKeys addObject:key];
                    }
                    [prefsByKey setObject:prefItem forKey:key];
                }
                [encounteredKeys addObject:key];
            }
        }
    }
    
    // See if we have any legacy preferences we're expecting that haven't been migrated
    NSMutableDictionary* legacyPrefs = [dict objectForKey:LegacyPreferencesKey]; // legacy
    if (legacyPrefs)
    {
        NSArray* allKeys = [legacyPrefs allKeys];
        for (NSString* key in allKeys)
        {
            if ([prefsByKey objectForKey:key] && ![encounteredKeys member:key] &&
                (!limitToKeys || [limitToKeys member:key]))
            {
                NSString* val = [legacyPrefs objectForKey:key];
                [self setValue:val forKey:key forceUpdate:YES];
                [changedKeys addObject:key];
            }
        }
    }

    // See if any preferences still have nil modified times. If so, this means a value didn't exist on the server, so set them now.
    if (storeModifiedDate)
    {
        NSArray* allKeys = [prefsByKey allKeys];
        for (NSString* key in allKeys)
        {
            if (!limitToKeys || [limitToKeys member:key])
            {
                PreferencesItem* prefItem = [prefsByKey objectForKey:key];
                if (!prefItem.modifiedDate)
                {
                    [prefItem setValue:[prefItem value] storeModifiedDate:storeModifiedDate]; // update the modified time
                }
            }
        }
    }
    
    return changedKeys;
}

// Convenience method to populate a preference in a given dictionary
+ (void)populatePreferenceInDictionary:(NSMutableDictionary*)dict
                                   key:(NSString*)key
                                 value:(NSString*)value
                          modifiedDate:(NSDate*)modifiedDate
                             perDevice:(BOOL)perDevice
{
    if (!dict || !key)
        return;
    
    if (!value)
        value = @"";
    
    NSMutableArray* syncPreferences = [dict objectForKey:SyncPreferencesKey];
    if (!syncPreferences)
        syncPreferences = [[NSMutableArray alloc] init];

    [Preferences removePrefDictForKey:key inArray:syncPreferences]; // make sure we overwrite this pref if it already exists
    
    NSMutableDictionary* thisPrefDict = [[NSMutableDictionary alloc] init];
    [thisPrefDict setObject:key forKey:KeyKey];

    if (modifiedDate)
    {
        NSNumber* modifiedDateNum = [NSNumber numberWithLongLong:(long long)[modifiedDate timeIntervalSince1970]];
        [thisPrefDict setObject:modifiedDateNum forKey:ModifiedDateKey];
    }
    
    [thisPrefDict setObject:value forKey:ValueKey];
    
    [thisPrefDict setObject:[NSNumber numberWithInt:(perDevice ? 1 : 0)] forKey:PerDeviceKey];

    [syncPreferences addObject:thisPrefDict];

    [dict setObject:syncPreferences forKey:SyncPreferencesKey];
}

// Convenience method to read a preference from a given dictionary (if it exists). Returns whether found.
+ (BOOL)readPreferenceFromDictionary:(NSDictionary*)dict
                                 key:(NSString*)key
                               value:(NSString**)value
                        modifiedDate:(NSDate**)modifiedDate
                           perDevice:(BOOL*)perDevice
{
    if (value)
        *value = nil;
    if (modifiedDate)
        *modifiedDate = nil;
    if (perDevice)
        *perDevice = NO;
    
    NSMutableArray* syncPreferences = [dict objectForKey:SyncPreferencesKey];
    if (syncPreferences)
    {
        NSMutableDictionary* thisPrefDict = [Preferences findPrefDictForKey:key inArray:syncPreferences];
        if (thisPrefDict)
        {
            if (modifiedDate)
            {
                NSNumber* modifiedDateNum = [thisPrefDict objectForKey:ModifiedDateKey];
                if (modifiedDateNum && [modifiedDateNum longLongValue] > 0)
                {
                    // Convert to NSDate from UNIX time
                    *modifiedDate = [NSDate dateWithTimeIntervalSince1970:[modifiedDateNum longLongValue]];
                }
            }
            
            if (value)
            {
                *value = [thisPrefDict objectForKey:ValueKey];
                if (*value && [*value length] == 0)
                    *value = nil;
            }
            
            if (perDevice)
            {
                NSNumber* perDeviceNum = [thisPrefDict objectForKey:PerDeviceKey];
                if (perDeviceNum)
                    *perDevice = ([perDeviceNum intValue] == 1 ? YES : NO);
            }
            
            return YES;
        }
    }
    
    // Look for legacy prefs
    NSMutableDictionary* legacyPrefs = [dict objectForKey:LegacyPreferencesKey];
    if (legacyPrefs)
    {
        NSString* legacyVal = [legacyPrefs objectForKey:key];
        if (legacyVal)
        {
            if (value)
            {
                *value = legacyVal;
                if (*value && [*value length] == 0)
                    *value = nil;
            }
            return YES;
        }
    }

    return NO;
}

@end
