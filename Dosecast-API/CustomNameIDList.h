//
//  CustomNameIDList.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/28/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class StringList;

@interface CustomNameIDList : NSObject<NSMutableCopying>
{
@private
    StringList* prefStore;
}

- (id)init:(NSString*)listName;

- (NSString*) listName;

- (NSArray*) allGuids;
- (void) getSortedListOfNames:(NSArray**)names andCorrespondingGuids:(NSArray**)guids; // returns an array of names and a corresponding array of guids, sorted by name alphabetically
- (NSString*) nameForGuid:(NSString*)guid;
- (NSString*) guidForName:(NSString*)name;
- (void) setName:(NSString*)val forGuid:(NSString*)guid;
- (void) removeNameForGuid:(NSString*)key;

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Update state from provided dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime;

@end
