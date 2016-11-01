//
//  DrugDosageUnitManager.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageUnitManager.h"
#import "DrugDosageUnitManagerEntry.h"
#import "DosecastUtil.h"

static DrugDosageUnitManager *gInstance = nil;

NSString* DrugDosageUnitGrams = @"g";
NSString* DrugDosageUnitMilligrams = @"mg";
NSString* DrugDosageUnitMicrograms = @"mcg";
NSString* DrugDosageUnitUnits = @"unit(s)";
NSString* DrugDosageUnitMilliliters = @"mL";
NSString* DrugDosageUnitMilligramsPerMilliliter = @"mg/mL";
NSString* DrugDosageUnitUnitsPerMilliliter = @"unit(s)/mL";
NSString* DrugDosageUnitPercent = @"%";
NSString* DrugDosageUnitMilligramsPerHour = @"mg/hr";
NSString* DrugDosageUnitMicrogramsPerHour = @"mcg/hr";
NSString* DrugDosageUnitMilligramsPer24Hours = @"mg/24hr";
NSString* DrugDosageUnitGramsPerMilliliter = @"g/mL";
NSString* DrugDosageUnitTeaspoons = @"tsp";
NSString* DrugDosageUnitTablespoons = @"tbsp";
NSString* DrugDosageUnitMilligramsPerTeaspoon = @"mg/tsp";
NSString* DrugDosageUnitMilligramsPerTablespoon = @"mg/tbsp";
NSString* DrugDosageUnitOunces = @"oz";
NSString* DrugDosageUnitCubicCentimeters = @"cc";
NSString* DrugDosageUnitMilligramsPerOunce = @"mg/oz";
NSString* DrugDosageUnitMilligramsPerCubicCentimeter = @"mg/cc";
NSString* DrugDosageUnitUnitsPerCubicCentimeter = @"unit(s)/cc";
NSString* DrugDosageUnitIU = @"IU";
NSString* DrugDosageUnitIUPerMilliliter = @"IU/mL";
NSString* DrugDosageUnitIUPerCubicCentimeter = @"IU/cc";
NSString* DrugDosageUnitDays = @"day(s)";
NSString* DrugDosageUnitMilliequivalents = @"meq";
NSString* DrugDosageUnitMilligramsPerUnit = @"mg/unit";
NSString* DrugDosageUnitMillilitersPerDay = @"mL/day";
NSString* DrugDosageUnitMillilitersPerHour = @"mL/hr";
NSString* DrugDosageUnitMillilitersPerMinute = @"mL/min";
NSString* DrugDosageUnitCubicCentimetersPerDay = @"cc/day";
NSString* DrugDosageUnitCubicCentimetersPerHour = @"cc/hr";
NSString* DrugDosageUnitCubicCentimetersPerMinute = @"cc/min";
NSString* DrugDosageUnitUnitsPerDay = @"unit(s)/day";
NSString* DrugDosageUnitUnitsPerHour = @"unit(s)/hr";
NSString* DrugDosageUnitUnitsPerMinute = @"unit(s)/min";
NSString* DrugDosageUnitKilograms = @"kg";
NSString* DrugDosageUnitLiters = @"L";

@implementation DrugDosageUnitManager

// Registers a string table name for a given drug dosage unit - and whether it can be pluralized
- (void) registerStringTableName:(NSString*)stringTableName forDrugDosageUnit:(NSString*)drugDosageUnit canPluralize:(BOOL)canPluralize
{
    DrugDosageUnitManagerEntry* entry = [[DrugDosageUnitManagerEntry alloc] init:stringTableName canPluralize:canPluralize];
    [drugDosageUnitDict setObject:entry forKey:drugDosageUnit];
}

- (id)init
{
    if ((self = [super init]))
    {
		drugDosageUnitDict = [[NSMutableDictionary alloc] init];
        
        [self registerStringTableName:@"DrugDosageUnitGrams" forDrugDosageUnit:DrugDosageUnitGrams canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligrams" forDrugDosageUnit:DrugDosageUnitMilligrams canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMicrograms" forDrugDosageUnit:DrugDosageUnitMicrograms canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitUnits" forDrugDosageUnit:DrugDosageUnitUnits canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitMilliliters" forDrugDosageUnit:DrugDosageUnitMilliliters canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerMilliliter" forDrugDosageUnit:DrugDosageUnitMilligramsPerMilliliter canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitUnitsPerMilliliter" forDrugDosageUnit:DrugDosageUnitUnitsPerMilliliter canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitPercent" forDrugDosageUnit:DrugDosageUnitPercent canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerHour" forDrugDosageUnit:DrugDosageUnitMilligramsPerHour canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMicrogramsPerHour" forDrugDosageUnit:DrugDosageUnitMicrogramsPerHour canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPer24Hours" forDrugDosageUnit:DrugDosageUnitMilligramsPer24Hours canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitGramsPerMilliliter" forDrugDosageUnit:DrugDosageUnitGramsPerMilliliter canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitTeaspoons" forDrugDosageUnit:DrugDosageUnitTeaspoons canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitTablespoons" forDrugDosageUnit:DrugDosageUnitTablespoons canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerTeaspoon" forDrugDosageUnit:DrugDosageUnitMilligramsPerTeaspoon canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerTablespoon" forDrugDosageUnit:DrugDosageUnitMilligramsPerTablespoon canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitOunces" forDrugDosageUnit:DrugDosageUnitOunces canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitCubicCentimeters" forDrugDosageUnit:DrugDosageUnitCubicCentimeters canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerOunce" forDrugDosageUnit:DrugDosageUnitMilligramsPerOunce canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerCubicCentimeter" forDrugDosageUnit:DrugDosageUnitMilligramsPerCubicCentimeter canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitUnitsPerCubicCentimeter" forDrugDosageUnit:DrugDosageUnitUnitsPerCubicCentimeter canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitIU" forDrugDosageUnit:DrugDosageUnitIU canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitIUPerMilliliter" forDrugDosageUnit:DrugDosageUnitIUPerMilliliter canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitIUPerCubicCentimeter" forDrugDosageUnit:DrugDosageUnitIUPerCubicCentimeter canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitDays" forDrugDosageUnit:DrugDosageUnitDays canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitMilliequivalents" forDrugDosageUnit:DrugDosageUnitMilliequivalents canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMilligramsPerUnit" forDrugDosageUnit:DrugDosageUnitMilligramsPerUnit canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMillilitersPerDay" forDrugDosageUnit:DrugDosageUnitMillilitersPerDay canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMillilitersPerHour" forDrugDosageUnit:DrugDosageUnitMillilitersPerHour canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitMillilitersPerMinute" forDrugDosageUnit:DrugDosageUnitMillilitersPerMinute canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitCubicCentimetersPerDay" forDrugDosageUnit:DrugDosageUnitCubicCentimetersPerDay canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitCubicCentimetersPerHour" forDrugDosageUnit:DrugDosageUnitCubicCentimetersPerHour canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitCubicCentimetersPerMinute" forDrugDosageUnit:DrugDosageUnitCubicCentimetersPerMinute canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitUnitsPerDay" forDrugDosageUnit:DrugDosageUnitUnitsPerDay canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitUnitsPerHour" forDrugDosageUnit:DrugDosageUnitUnitsPerHour canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitUnitsPerMinute" forDrugDosageUnit:DrugDosageUnitUnitsPerMinute canPluralize:YES];
        [self registerStringTableName:@"DrugDosageUnitKilograms" forDrugDosageUnit:DrugDosageUnitKilograms canPluralize:NO];
        [self registerStringTableName:@"DrugDosageUnitLiters" forDrugDosageUnit:DrugDosageUnitLiters canPluralize:NO];
    }
	
    return self;
}


// Singleton methods

+ (DrugDosageUnitManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

// All other methods

// Returns the localized drug dosage unit
- (NSString*) getLocalizedDrugDosageUnit:(NSString*)drugDosageUnit pluralize:(BOOL)pluralize
{
    if (!drugDosageUnit)
        return nil;
    
    DrugDosageUnitManagerEntry* entry = [drugDosageUnitDict objectForKey:drugDosageUnit];
    if (entry)
    {
        // Get the string table name and optionally pluralize it
        NSString* stringTableName = entry.stringTableName;
        if (entry.canPluralize)
        {
            if (pluralize)
                stringTableName = [NSString stringWithFormat:@"%@%@", stringTableName, @"Plural"];
            else
                stringTableName = [NSString stringWithFormat:@"%@%@", stringTableName, @"Singular"];
        }
        
        // Try to find the localized version
        return NSLocalizedStringWithDefaultValue(stringTableName, @"Dosecast", [DosecastUtil getResourceBundle], drugDosageUnit, @""]);
    }
    else
        return drugDosageUnit;
}

@end
