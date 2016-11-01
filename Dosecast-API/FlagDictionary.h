//
//  FlagDictionary.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 6/23/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// This class stores a dictionary of boolean flags, which can be used as switches
@interface FlagDictionary : NSObject<NSMutableCopying>
{
@private
    NSMutableDictionary *dict;
}

-(id)initWithFlags:(NSArray*)flags;

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)thisDict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)thisDict;

// Accessors
- (void) setFlag:(NSString*)flagName value:(BOOL)val;
- (BOOL) getFlag:(NSString*)flagName; // Returns NO if flag not found

// Return list of flag names
- (NSArray*) getFlagNames;

@end
