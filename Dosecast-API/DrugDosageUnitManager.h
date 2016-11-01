//
//  DrugDosageUnitManager.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DrugDosageUnitManager : NSObject {
@private
	NSMutableDictionary* drugDosageUnitDict;
}

// Singleton methods
+ (DrugDosageUnitManager*) getInstance;

// Returns the localized drug dosage unit
- (NSString*) getLocalizedDrugDosageUnit:(NSString*)drugDosageUnit pluralize:(BOOL)pluralize;

@end

// Available units
extern NSString* DrugDosageUnitGrams;
extern NSString* DrugDosageUnitMilligrams;
extern NSString* DrugDosageUnitMicrograms;
extern NSString* DrugDosageUnitUnits;
extern NSString* DrugDosageUnitMilliliters;
extern NSString* DrugDosageUnitMilligramsPerMilliliter;
extern NSString* DrugDosageUnitUnitsPerMilliliter;
extern NSString* DrugDosageUnitPercent;
extern NSString* DrugDosageUnitMilligramsPerHour;
extern NSString* DrugDosageUnitMicrogramsPerHour;
extern NSString* DrugDosageUnitMilligramsPer24Hours;
extern NSString* DrugDosageUnitGramsPerMilliliter;
extern NSString* DrugDosageUnitTeaspoons;
extern NSString* DrugDosageUnitTablespoons;
extern NSString* DrugDosageUnitMilligramsPerTeaspoon;
extern NSString* DrugDosageUnitMilligramsPerTablespoon;
extern NSString* DrugDosageUnitOunces;
extern NSString* DrugDosageUnitCubicCentimeters;
extern NSString* DrugDosageUnitMilligramsPerOunce;
extern NSString* DrugDosageUnitMilligramsPerCubicCentimeter;
extern NSString* DrugDosageUnitUnitsPerCubicCentimeter;
extern NSString* DrugDosageUnitIU;
extern NSString* DrugDosageUnitIUPerMilliliter;
extern NSString* DrugDosageUnitIUPerCubicCentimeter;
extern NSString* DrugDosageUnitDays;
extern NSString* DrugDosageUnitMilliequivalents;
extern NSString* DrugDosageUnitMilligramsPerUnit;
extern NSString* DrugDosageUnitMillilitersPerDay;
extern NSString* DrugDosageUnitMillilitersPerHour;
extern NSString* DrugDosageUnitMillilitersPerMinute;
extern NSString* DrugDosageUnitCubicCentimetersPerDay;
extern NSString* DrugDosageUnitCubicCentimetersPerHour;
extern NSString* DrugDosageUnitCubicCentimetersPerMinute;
extern NSString* DrugDosageUnitUnitsPerDay;
extern NSString* DrugDosageUnitUnitsPerHour;
extern NSString* DrugDosageUnitUnitsPerMinute;
extern NSString* DrugDosageUnitKilograms;
extern NSString* DrugDosageUnitLiters;