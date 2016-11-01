//
//  DrugNameViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//
#import "MedicationConstants.h"
@class Medication;

@protocol DrugNameViewControllerDelegate

@required

// Callback for entry of the drug name.
- (void)handleDrugNameEntryDone:(NSString*)drugName;

// Callback for entry of the drug from a database.
- (void)handleDrugDatabaseEntryDone:(Medication*)drug resultMatch:(MedicationResultMatch)resultMatch;

@end
