//
//  StringList.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StringList : NSObject<NSMutableCopying>
{
@private
    NSString* name;
    NSMutableDictionary* activeGuids;
    NSMutableSet* deletedGuids;
}

- (id)init:(NSString*)n
activeGuids:(NSDictionary*)active
deletedGuids:(NSSet*)deleted;

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Update from provided server dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime;

- (NSString*) name;
- (NSArray*) allKeys;
- (NSString*) valueForKey:(NSString*)key;
- (NSString*) keyForValue:(NSString*)value;
- (void) setValue:(NSString*)val forKey:(NSString*)key; // will add new string value if it doesn't exist
- (void) removeValueForKey:(NSString*)key;

@end
