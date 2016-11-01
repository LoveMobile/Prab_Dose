//
//  StringListItem.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/21/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StringListItem : NSObject<NSMutableCopying>
{
@private
    NSDate* modifiedDate;
    NSString* value;
}

- (id)init:(NSDate*)m value:(NSString*)v;

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*)dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict;

// Update from provided server dictionary
- (void) updateFromServerDictionary:(NSMutableDictionary*)dict currentServerTime:(NSDate*)currentServerTime;

@property (nonatomic, readonly) NSDate* modifiedDate;
@property (nonatomic, strong) NSString* value;

@end
