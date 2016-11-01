//
//  PermutationSearchResult.m
//  Dosecast-API
//
//  Created by Shawn Grimes on 9/24/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "PermutationSearchResult.h"
#import "Medication.h"

@implementation PermutationSearchResult

@synthesize medication=_medication;
@synthesize matchType=_matchType;

-(id)initWithMedication:(Medication *)matchedMedication andMatchType:(MedicationResultMatch) matchType{
    if((self=[super init])){
        self.medication=matchedMedication;
        self.matchType=matchType;
    }
    return self;
}

-(BOOL)isEqual:(id)object{
    //Return immediately if they are not the same class
    if(![object isKindOfClass:[PermutationSearchResult class]]){
        return NO;
    }

    PermutationSearchResult *compareObject=(PermutationSearchResult *)object;

    //Check if all the permutations are the same
    if(([self.medication.medType caseInsensitiveCompare:compareObject.medication.medType]==NSOrderedSame)
       && ([self.medication.medFormType caseInsensitiveCompare:compareObject.medication.medFormType]==NSOrderedSame)
       && ([self.medication.route caseInsensitiveCompare:compareObject.medication.route]==NSOrderedSame)
       && ([self.medication.strength caseInsensitiveCompare:compareObject.medication.strength]==NSOrderedSame)
       && ([self.medication.unit caseInsensitiveCompare:compareObject.medication.unit]==NSOrderedSame))
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
