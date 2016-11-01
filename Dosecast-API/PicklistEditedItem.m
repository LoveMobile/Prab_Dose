//
//  PicklistEditedItem.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "PicklistEditedItem.h"

@implementation PicklistEditedItem

@synthesize value;
@synthesize index;

- (id)init
{
    return [self init:nil index:-1];
}

- (id)init:(NSString *)val index:(int)i
{
    if ((self = [super init]))
    {
        index = i;
        value = val;
	}	
    return self;	
}


@end


