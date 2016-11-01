//
//  DrugDosageQuantity.m
//  Dosecast
//
//  Created by Jonathan Levene on 9/2/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageQuantity.h"
#import "DrugDosageUnitManager.h"

static float epsilon = 0.0001;

@implementation DrugDosageQuantity

@synthesize unit;
@synthesize possibleUnits;

- (id)init
{
	return [self init:0.0f unit:nil possibleUnits:[[NSArray alloc] init]];
}

- (id)init:(float)val
	     unit:(NSString*)u
possibleUnits:(NSArray*)possibleU
{
    return [self init:val unit:u possibleUnits:possibleU allowNegative:NO];
}

- (id)init:(float)val
      unit:(NSString*)u
possibleUnits:(NSArray*)possibleU
allowNegative:(BOOL)negative
{
    if ((self = [super init]))
    {
        allowNegative = negative;
        if (!allowNegative && val < epsilon)
            val = 0.0f;
        value = val;
        unit = u;
        possibleUnits = [[NSMutableArray alloc] initWithArray:possibleU];
    }
    return self;
}

// Returns if the value is valid
- (BOOL)isValidValue
{
    if (allowNegative)
        return YES;
    else
        return value > epsilon;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[DrugDosageQuantity alloc] init:value
                                       unit:[unit mutableCopyWithZone:zone]
                              possibleUnits:[possibleUnits mutableCopyWithZone:zone]
                              allowNegative:allowNegative];
}

- (float) value
{
    return value;
}

- (void) setValue:(float)val
{
    if (!allowNegative && val < epsilon)
        val = 0.0f;
    value = val;
}

- (BOOL) allowNegative
{
    return allowNegative;
}

- (void) setAllowNegative:(BOOL)negative
{
    allowNegative = negative;
    if (!allowNegative && value < epsilon)
        value = 0.0f;
}

@end
