//
//  DrugDosageQuantity.h
//  Dosecast
//
//  Created by Jonathan Levene on 9/2/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"

@interface DrugDosageQuantity : NSObject<NSMutableCopying>
{
@private
	float value;
	NSString* unit;
	NSMutableArray* possibleUnits;
    BOOL allowNegative;
}

   - (id)init:(float)val
         unit:(NSString*)u
possibleUnits:(NSArray*)possibleU;

- (id)init:(float)val
      unit:(NSString*)u
possibleUnits:(NSArray*)possibleU
allowNegative:(BOOL)negative;

// Returns if the value is valid
- (BOOL)isValidValue;

@property (nonatomic, assign) float value;
@property (nonatomic, strong) NSString* unit;
@property (nonatomic, strong) NSMutableArray* possibleUnits;
@property (nonatomic, assign) BOOL allowNegative;

@end
