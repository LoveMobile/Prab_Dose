//
//  StringList.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "StringList.h"
#import "StringListItem.h"
#import "DosecastUtil.h"
#import "Preferences.h"

static NSString *StringListsKey = @"stringLists";
static NSString *ActiveGuidsKey = @"activeGuids";
static NSString *DeletedGuidsKey = @"deletedGuids";
static NSString *GuidKey = @"guid";

@implementation StringList

- (id)init
{
	return [self init:nil activeGuids:nil deletedGuids:nil];
}

- (id)init:(NSString*)n
activeGuids:(NSDictionary*)active
deletedGuids:(NSSet*)deleted
{
    if ((self = [super init]))
    {
        if (!n)
            n = @"";
        if (!active)
            active = [NSDictionary dictionary];
        if (!deleted)
            deleted = [NSSet set];
        
        name = n;
        activeGuids = [[NSMutableDictionary alloc] initWithDictionary:active];
        deletedGuids = [[NSMutableSet alloc] initWithSet:deleted];
    }
    
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[StringList alloc] init:[name mutableCopyWithZone:zone]
                        activeGuids:[activeGuids mutableCopyWithZone:zone]
                       deletedGuids:[deletedGuids mutableCopyWithZone:zone]];
}

// Parses the given preference string for a nameID and name. Returns whether successful.
- (BOOL) parseLegacyPreferenceString:(NSString*)prefString // legacy
                          guid:(NSString**)guid
                         value:(NSString**)value
{
    if (!prefString || !guid || !value)
        return NO;
    
    *guid = nil;
    *value = nil;
    
    NSRange colonRange = [prefString rangeOfString:@":"];
    if (colonRange.location == NSNotFound)
        return NO;
    
    NSRange guidRange = NSMakeRange(0, colonRange.location);
    *guid = [prefString substringWithRange:guidRange];
    NSRange valueRange = NSMakeRange(colonRange.location+1, [prefString length]-[(*guid) length]-1);
    *value = [prefString substringWithRange:valueRange];
    return YES;
}

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)dict
{
    BOOL foundName = NO;
    NSMutableDictionary* stringLists = [dict objectForKey:StringListsKey];
    if (stringLists)
    {
        NSMutableDictionary *dictName = [stringLists objectForKey:name];
        if (dictName)
        {
            foundName = YES;
            NSMutableArray* deletedArray = [dictName objectForKey:DeletedGuidsKey];
            if (deletedArray)
                deletedGuids = [NSMutableSet setWithArray:deletedArray];
            NSMutableArray* dictArray = [dictName objectForKey:ActiveGuidsKey];
            for (NSMutableDictionary* guidDict in dictArray)
            {
                NSString* guid = [guidDict objectForKey:GuidKey];
                if (guid)
                    [activeGuids setObject:[[StringListItem alloc] initWithDictionary:guidDict] forKey:guid];
            }
        }
    }
    
    if (!foundName) // legacy
    {
        [self readLegacyStringListFromDict:dict];
    }
}

- (void) readLegacyStringListFromDict:(NSMutableDictionary*)dict // legacy
{
    NSString* countKey = [NSString stringWithFormat:@"%@%@", name, @"Count"];
    NSString* countVal = nil;
    [Preferences readPreferenceFromDictionary:dict key:countKey value:&countVal modifiedDate:nil perDevice:nil];
    
    if (countVal)
    {
        int numItems = [countVal intValue];
        
        for (int i = 0; i < numItems; i++)
        {
            NSString* itemKey = [NSString stringWithFormat:@"%@%d", name, i];
            NSString* value = nil;
            [Preferences readPreferenceFromDictionary:dict key:itemKey value:&value modifiedDate:nil perDevice:nil];
            if (!value)
                value = @"";
            NSString* guid = [DosecastUtil createGUID];
            NSString* legacyGuid = nil;
            NSString* legacyValue = nil;
            BOOL foundOldPrefString = [self parseLegacyPreferenceString:value guid:&legacyGuid value:&legacyValue];
            if (foundOldPrefString)
            {
                guid = legacyGuid;
                value = legacyValue;
            }
            [activeGuids setObject:[[StringListItem alloc] init:nil value:value] forKey:guid];
        }
    }
}


// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
    // Don't bother to output nothing, as this could stop us from migrated legacy string lists (because we'd see the string list name)
    if (!dict || ([activeGuids count] == 0 && [deletedGuids count] == 0))
        return;
    
    NSMutableDictionary* stringLists = [dict objectForKey:StringListsKey];
    if (!stringLists)
        stringLists = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary* thisStringList = [[NSMutableDictionary alloc] init];
    
    NSArray* allGuids = [activeGuids allKeys];
    NSMutableArray* active = [[NSMutableArray alloc] init];
    for (NSString* guid in allGuids)
    {
        NSMutableDictionary* thisGuidDict = [[NSMutableDictionary alloc] init];
        [thisGuidDict setObject:guid forKey:GuidKey];
        
        StringListItem* i = [activeGuids objectForKey:guid];
        [i populateDictionary:thisGuidDict];
        [active addObject:thisGuidDict];
    }
    
    [thisStringList setObject:active forKey:ActiveGuidsKey];
    [thisStringList setObject:[deletedGuids allObjects] forKey:DeletedGuidsKey];
    [stringLists setObject:thisStringList forKey:name];
    
    [dict setObject:stringLists forKey:StringListsKey];
}


// Update from provided server dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime
{
    BOOL foundName = NO;
    NSMutableDictionary* stringLists = [dict objectForKey:StringListsKey];
    if (stringLists)
    {
        NSMutableDictionary *dictName = [stringLists objectForKey:name];
        if (dictName)
        {
            foundName = YES;
            
            // Handle deleted string list items
            NSMutableArray* deletedArray = [dictName objectForKey:DeletedGuidsKey];
            if (deletedArray)
            {
                NSMutableSet* deleted = [NSMutableSet setWithArray:deletedArray];
                
                [deleted minusSet:deletedGuids];
                NSArray* guidsToDelete = [deleted allObjects];
                for (NSString* guid in guidsToDelete)
                {
                    [activeGuids removeObjectForKey:guid];
                    [deletedGuids addObject:guid];
                }
            }
            
            // Handle new & updated string list items
            NSMutableArray* dictArray = [dictName objectForKey:ActiveGuidsKey];
            if (dictArray)
            {
                for (NSMutableDictionary* guidDict in dictArray)
                {
                    NSString* guid = [guidDict objectForKey:GuidKey];
                    StringListItem* i = [activeGuids objectForKey:guid];
                    if (i)
                        [i updateFromServerDictionary:guidDict currentServerTime:currentServerTime];
                    else
                        [activeGuids setObject:[[StringListItem alloc] initWithDictionary:guidDict] forKey:guid];
                }
            }
        }
    }
    
    // If we didn't find ourselves in the new format, check for legacy preferences
    if (!foundName)
    {
        [self readLegacyStringListFromDict:dict];
    }
}

- (NSString*) name
{
    return name;
}

- (NSArray*) allKeys
{
    return [activeGuids allKeys];
}

- (NSString*) valueForKey:(NSString*)key
{
    if (!key)
        return nil;
    
    StringListItem* i = [activeGuids objectForKey:key];
    if (i)
        return i.value;
    else
        return nil;
}

- (NSString*) keyForValue:(NSString*)value
{
    if (!value)
        return nil;
    
    NSArray* allKeys = [activeGuids allKeys];
    for (NSString* key in allKeys)
    {
        StringListItem* i = [activeGuids objectForKey:key];
        if ([value isEqualToString:i.value])
            return key;
    }
    
    return nil;
}

- (void) setValue:(NSString*)val forKey:(NSString*)key // will add new string value if it doesn't exist
{
    if (key)
    {
        StringListItem* i = [activeGuids objectForKey:key];
        if (i)
            i.value = val;
        else
        {
            [activeGuids setObject:[[StringListItem alloc] init:nil value:val] forKey:key];
        }
    }
    else
        [activeGuids setObject:[[StringListItem alloc] init:nil value:val] forKey:[DosecastUtil createGUID]];
}

- (void) removeValueForKey:(NSString*)key
{
    if (!key)
        return;
    
    if ([activeGuids objectForKey:key])
    {
        [activeGuids removeObjectForKey:key];
        [deletedGuids addObject:key];
    }
}


@end
