//
//  PreferencesItem.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PreferencesItem : NSObject<NSMutableCopying>
{
@private
    NSDate* modifiedDate;
    BOOL perDevice;
    NSString* value;
    BOOL persistLocally;
    BOOL persistOnServer;
}

- (id)init:(NSDate*)modDate
 perDevice:(BOOL)perDev
persistLocally:(BOOL)persistLocal
persistOnServer:(BOOL)persistServer
     value:(NSString*)val;

// Read all values from the given dictionary
- (void) readFromDictionary:(NSMutableDictionary*)dict storeModifiedDate:(BOOL)storeModifiedDate;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict storeModifiedDate:(BOOL)storeModifiedDate;

// Update from provided server dictionary. Returns whether updated.
- (BOOL) updateFromServerDictionary:(NSMutableDictionary*)dict storeModifiedDate:(BOOL)storeModifiedDate currentServerTime:(NSDate*)currentServerTime;

- (NSString*) value;
- (void) setValue:(NSString*)val storeModifiedDate:(BOOL)storeModifiedDate;

- (BOOL) perDevice;
- (void) setPerDevice:(BOOL)perDev storeModifiedDate:(BOOL)storeModifiedDate;

- (NSDate*) modifiedDate;
- (BOOL) persistLocally;
- (BOOL) persistOnServer;

@end
