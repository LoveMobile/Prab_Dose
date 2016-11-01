//
//  Preferences.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Preferences : NSObject<NSMutableCopying>
{
@private
    NSMutableDictionary* prefsByKey;
    BOOL storeModifiedDate;
}

- (id)init:(NSDictionary*)prefDict storeModifiedDate:(BOOL)storeModified;

// Read all values from the given dictionary. Returns the keys that were read.
- (NSSet*)readFromDictionary:(NSMutableDictionary*)dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Update from provided server dictionary. Returns a set of keys whose values were updated.
- (NSSet*) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime limitToKeys:(NSSet*)limitToKeys;

- (NSString*) valueForKey:(NSString*)key;
- (NSString*) valueForKey:(NSString*)key isPerDevice:(BOOL*)perDevice;
- (BOOL) setValue:(NSString*)val forKey:(NSString*)key;
- (void) addPreference:(NSString*)key
                 value:(NSString*)val
             perDevice:(BOOL)perDevice
        persistLocally:(BOOL)persistLocally
       persistOnServer:(BOOL)persistOnServer
sendAfterCompletedFirstSync:(BOOL)sendAfterCompletedFirstSync;

- (NSArray*) allKeys;

// Convenience method to populate a preference in a given dictionary
+ (void)populatePreferenceInDictionary:(NSMutableDictionary*)dict
                                   key:(NSString*)key
                                 value:(NSString*)value
                          modifiedDate:(NSDate*)modifiedDate
                             perDevice:(BOOL)perDevice;

// Convenience method to read a preference from a given dictionary (if it exists). Returns whether found.
+ (BOOL)readPreferenceFromDictionary:(NSDictionary*)dict
                                 key:(NSString*)key
                               value:(NSString**)value
                        modifiedDate:(NSDate**)modifiedDate
                           perDevice:(BOOL*)perDevice;

@end
