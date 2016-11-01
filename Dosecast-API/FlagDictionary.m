//
//  FlagDictionary.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 6/23/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "FlagDictionary.h"

@implementation FlagDictionary

-(id)init
{
    return [self initWithFlags:[[NSArray alloc] init]];
}

-(id)initWithFlags:(NSArray*)flags
{
	if ((self = [super init]))
    {
        dict = [[NSMutableDictionary alloc] init];
        
        for (NSString* flag in flags)
            [dict setObject:[NSNumber numberWithBool:YES] forKey:flag];
	}
	
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    FlagDictionary* flagDict = [[FlagDictionary alloc] init];
    flagDict->dict = [dict mutableCopyWithZone:zone];
    return flagDict;
}

// Accessors
- (void) setFlag:(NSString*)flagName value:(BOOL)val
{
    [dict setObject:[NSNumber numberWithBool:val] forKey:flagName];
}

- (BOOL) getFlag:(NSString*)flagName; // Returns NO if flag not found
{
    NSNumber* num = [dict objectForKey:flagName];
    if (num)
    {
        return [num boolValue];
    }
    else
        return NO;
}

// Return list of flag names
- (NSArray*) getFlagNames
{
    return [dict allKeys];
}

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)thisDict
{
    NSArray* persistentFlagNames = [self getFlagNames];
    for (NSString* flagName in persistentFlagNames)
    {
        NSNumber* flagValNum = [thisDict objectForKey:flagName];
        [self setFlag:flagName value:(flagValNum && [flagValNum intValue] == 1)];
    }
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)thisDict
{
    NSArray* persistentFlagNames = [self getFlagNames];
    for (NSString* flagName in persistentFlagNames)
        [thisDict setObject:[NSNumber numberWithInt:([self getFlag:flagName] ? 1 : 0)] forKey:flagName];
}


@end
