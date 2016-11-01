//
//  Group.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "Group.h"

@implementation Group

@synthesize groupID;
@synthesize displayName;
@synthesize tosAddendum;
@synthesize description;
@synthesize logoGUID;
@synthesize givesPremium;
@synthesize givesSubscription;

- (id)init
{
    return [self init:nil displayName:nil tosAddendum:nil description:nil logoGUID:nil givesPremium:NO givesSubscription:NO];
}

  -(id)init:(NSString*)gID
displayName:(NSString*)name
tosAddendum:(NSString*)tos
description:(NSString*)descrip
   logoGUID:(NSString*)logo
givesPremium:(BOOL)premium
givesSubscription:(BOOL)subscription
{
    if ((self = [super init]))
    {
        groupID = gID;
        displayName = name;
        tosAddendum = tos;
        description = descrip;
        logoGUID = logo;
        givesPremium = premium;
        givesSubscription = subscription;
    }
    
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[Group alloc] init:[groupID mutableCopyWithZone:zone]
                   displayName:[displayName mutableCopyWithZone:zone]
                   tosAddendum:[tosAddendum mutableCopyWithZone:zone]
                   description:[description mutableCopyWithZone:zone]
                      logoGUID:[logoGUID mutableCopyWithZone:zone]
                  givesPremium:givesPremium
            givesSubscription:givesSubscription];
}


@end
