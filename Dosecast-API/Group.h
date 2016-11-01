//
//  Group.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Group : NSObject<NSMutableCopying>
{
@private
    NSString* groupID;
    NSString* displayName;
    NSString* tosAddendum;
    NSString* description;
    NSString* logoGUID;
    BOOL givesPremium;
    BOOL givesSubscription;
}

    -(id)init:(NSString*)gID
  displayName:(NSString*)name
  tosAddendum:(NSString*)tos
  description:(NSString*)descrip
     logoGUID:(NSString*)logo
 givesPremium:(BOOL)premium
givesSubscription:(BOOL)subscription;

@property (nonatomic, readonly) NSString* groupID;
@property (nonatomic, readonly) NSString* displayName;
@property (nonatomic, readonly) NSString* tosAddendum;
@property (nonatomic, readonly) NSString* description;
@property (nonatomic, readonly) NSString* logoGUID;
@property (nonatomic, readonly) BOOL givesPremium;
@property (nonatomic, readonly) BOOL givesSubscription;

@end
