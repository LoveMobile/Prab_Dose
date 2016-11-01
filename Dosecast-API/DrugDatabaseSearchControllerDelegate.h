//
//  DrugDatabaseSearchControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "MedicationConstants.h"
@class Medication;

@protocol DrugDatabaseSearchControllerDelegate

@required

- (void) handleDrugDatabaseSearchResult:(Medication *)permutation resultMatch:(MedicationResultMatch)resultMatch;

@end
