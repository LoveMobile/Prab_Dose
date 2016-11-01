//
//  PermutationSearchResult.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 9/24/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MedicationConstants.h"

@class Medication;

@interface PermutationSearchResult : NSObject

@property (nonatomic,strong) Medication *medication;
@property (nonatomic) MedicationResultMatch matchType;

-(id)initWithMedication:(Medication *)matchedMedication andMatchType:(MedicationResultMatch) matchType;

@end
