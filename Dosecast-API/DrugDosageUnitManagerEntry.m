//
//  DrugDosageUnitManagerEntry.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageUnitManagerEntry.h"


@implementation DrugDosageUnitManagerEntry

@synthesize stringTableName;
@synthesize canPluralize;

- (id)init:(NSString*)stringName canPluralize:(BOOL)pluralize
{
	if ((self = [super init]))
    {
		stringTableName = stringName;
        canPluralize = pluralize;
    }
	
    return self;	
}


@end
