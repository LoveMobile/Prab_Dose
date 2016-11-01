//
//  DrugDosageManagerEntry.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageManagerEntry.h"


@implementation DrugDosageManagerEntry

@synthesize dosageClass;

- (id)initWithClass:(Class)cl
{
	if ((self = [super init]))
    {
		dosageClass = cl;
    }
	
    return self;	
}


@end
