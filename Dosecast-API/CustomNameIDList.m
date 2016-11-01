//
//  CustomNameIDList.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/28/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "CustomNameIDList.h"
#import "StringList.h"
#import "DosecastUtil.h"

@implementation CustomNameIDList

- (id)init
{
    return [self init:nil];
}

- (id)initWithPrefStore:(StringList*)mps
{
    if ((self = [super init]))
    {
        if (!mps)
            mps = [[StringList alloc] init:nil activeGuids:nil deletedGuids:nil];
        prefStore = mps;
    }
    
    return self;
}

- (id)init:(NSString*)listName 
{
    return [self initWithPrefStore:[[StringList alloc] init:listName activeGuids:nil deletedGuids:nil]];
}

// Computes the preference string for the given name & nameID pair
- (NSString*) getPreferenceStringForNameID:(NSString*)nameID andName:(NSString*)name
{
    if (!nameID || !name)
        return nil;

    return [NSString stringWithFormat:@"%@:%@", nameID, name];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
    [prefStore populateDictionary:dict forSyncRequest:forSyncRequest];
}

// Update state from provided dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime
{
    [prefStore updateFromServerDictionary:dict currentServerTime:currentServerTime];
}

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)dict
{
    [prefStore readFromDictionary:dict];
}

- (NSArray*) allGuids
{
    return [prefStore allKeys];
}

// Function to compare two drugs' nextReminder dates
NSComparisonResult compareNames(NSString* guid1, NSString* guid2, void* context)
{
    CustomNameIDList* customNameIDList = (__bridge CustomNameIDList*)context;
    NSString* name1 = [customNameIDList nameForGuid:guid1];
    NSString* name2 = [customNameIDList nameForGuid:guid2];
    return [name1 compare:name2 options:NSLiteralSearch];
}

- (void) getSortedListOfNames:(NSArray**)names andCorrespondingGuids:(NSArray**)guids // returns an array of names and a corresponding array of guids, sorted by name alphabetically
{
    NSMutableArray* allGuids = [NSMutableArray arrayWithArray:[prefStore allKeys]];
    [allGuids sortUsingFunction:compareNames context:(__bridge void*)self];
    
    NSMutableArray* allNames = [[NSMutableArray alloc] init];
    for (NSString* guid in allGuids)
    {
        [allNames addObject:[self nameForGuid:guid]];
    }
    
    if (names)
        *names = allNames;
    if (guids)
        *guids = allGuids;
}

- (NSString*) nameForGuid:(NSString*)guid
{
    return [prefStore valueForKey:guid];
}

- (NSString*) guidForName:(NSString*)name
{
    return [prefStore keyForValue:name];
}

- (void) setName:(NSString*)val forGuid:(NSString*)guid
{
    [prefStore setValue:val forKey:guid];
}

- (void) removeNameForGuid:(NSString*)key
{
    [prefStore removeValueForKey:key];
}

- (NSString*) listName
{
    return [prefStore name];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[CustomNameIDList alloc] initWithPrefStore:[prefStore mutableCopyWithZone:zone]];
}


@end
