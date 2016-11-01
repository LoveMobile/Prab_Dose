//
//  PillDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "PillDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Pill-related names
static NSString *PillDosageTypeName = @"pill";
static NSString *NumPillsQuantityName = @"numpills";
static NSString *PillStrengthQuantityName = @"pillStrength";

static float epsilon = 0.0001;

@implementation PillDrugDosage

- (void)populateQuantities:(float)numPills
			  pillStrength:(float)pillStrength
		 pillStrengthUnit:(NSString*)pillStrengthUnit
{
	// Populate quantities
	DrugDosageQuantity* numPillsQuantity = [[DrugDosageQuantity alloc] init:numPills unit:nil possibleUnits:nil];
	[doseQuantities setObject:numPillsQuantity forKey:NumPillsQuantityName];
	
	NSArray* possiblePillStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitGrams,
										  DrugDosageUnitMilligrams,
										  DrugDosageUnitMicrograms,
										  DrugDosageUnitUnits,
										  DrugDosageUnitIU,
                                          DrugDosageUnitMilliequivalents,
										  nil];
	DrugDosageQuantity* pillStrengthQuantity = [[DrugDosageQuantity alloc] init:pillStrength unit:pillStrengthUnit possibleUnits:possiblePillStrengthUnits];
	[doseQuantities setObject:pillStrengthQuantity forKey:PillStrengthQuantityName];	
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
             withRefillsRemaining:(int)left
{
	if ((self = [super initWithDoseQuantities:quantities
					withDosePicklistOptions:picklistOptions
					 withDosePicklistValues:picklistValues
                           withDoseTextValues:textValues
					  withRemainingQuantity:remaining
						 withRefillQuantity:refill
                              withRefillsRemaining:left]))
    {
		if (!quantities)
		{
			// Populate defaults
			[self populateQuantities:0.0f pillStrength:-1.0f pillStrengthUnit:nil];
		}
	}
	return self;			
}

	  - (id)init:(float)numPills
	pillStrength:(float)pillStrength
pillStrengthUnit:(NSString*)pillStrengthUnit
	   remaining:(float)remaining
		  refill:(float)refill
     refillsRemaining:(int)left
{
	if ((self = [super initWithDoseQuantities:nil
					withDosePicklistOptions:nil
					 withDosePicklistValues:nil
                           withDoseTextValues:nil
					  withRemainingQuantity:nil
						 withRefillQuantity:nil
                              withRefillsRemaining:left]))
    {
		[self populateQuantities:numPills pillStrength:pillStrength pillStrengthUnit:pillStrengthUnit];
		remainingQuantity.value = remaining;
		refillQuantity.value = refill;
	}
	return self;
}

- (id)init
{
	return [self initWithDoseQuantities:nil
				withDosePicklistOptions:nil
				 withDosePicklistValues:nil
                     withDoseTextValues:nil
				  withRemainingQuantity:nil
					 withRefillQuantity:nil
                        withRefillsRemaining:-1];
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{	
	float numPills = 0.0f;
	NSString* numPillsUnit = nil;
	float pillStrength = -1.0f;
	NSString* pillStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
    NSString* numPillsStr = [dict objectForKey:NumPillsKey];
    if (numPillsStr && [numPillsStr length] > 0)
        [DrugDosage getQuantityFromString:numPillsStr val:&numPills unit:&numPillsUnit];
    
    NSString* pillStrengthStr = [dict objectForKey:PillStrengthKey];
    if (pillStrengthStr && [pillStrengthStr length] > 0)
        [DrugDosage getQuantityFromString:pillStrengthStr val:&pillStrength unit:&pillStrengthUnit];
	
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numPills pillStrength:pillStrength pillStrengthUnit:pillStrengthUnit remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[PillDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
								  withDosePicklistOptions:[dosePicklistOptions mutableCopyWithZone:zone]
								   withDosePicklistValues:[dosePicklistValues mutableCopyWithZone:zone]
                                       withDoseTextValues:[doseTextValues mutableCopyWithZone:zone]
									withRemainingQuantity:[remainingQuantity mutableCopyWithZone:zone]
									   withRefillQuantity:[refillQuantity mutableCopyWithZone:zone]
                                          withRefillsRemaining:[self getRefillsRemaining]];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
	// Set the type of dosage
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:PillDosageTypeName modifiedDate:nil perDevice:NO];
	
    float numPills;
    [self getValue:&numPills forDoseQuantity:NumPillsQuantityName];
    NSString* numPillsUnit;
    [self getUnit:&numPillsUnit forDoseQuantity:NumPillsQuantityName];
    NSString* numPillsStr = [DrugDosage getStringFromQuantity:numPills unit:numPillsUnit numDecimals:2];
    [dict setObject:numPillsStr forKey:NumPillsKey];

    float pillStrength;
    [self getValue:&pillStrength forDoseQuantity:PillStrengthQuantityName];
    NSString* pillStrengthUnit;
    [self getUnit:&pillStrengthUnit forDoseQuantity:PillStrengthQuantityName];
    NSMutableString* pillStrengthStr = [NSMutableString stringWithString:@""];
    if (pillStrength > -epsilon)
        [pillStrengthStr appendString:[DrugDosage getStringFromQuantity:pillStrength unit:pillStrengthUnit numDecimals:2]];
    [dict setObject:pillStrengthStr forKey:PillStrengthKey];
    
    if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:2];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:2];
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypePill", @"Dosecast", [DosecastUtil getResourceBundle], @"Pill", @"The display name for pill drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [PillDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:PillDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [PillDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numPills:(NSString*)numPills strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numPillsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numPills val:&numPillsVal unit:&unit];
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypePillNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"pill", @"The singular name for pill drug types"]);
    
    BOOL multiple = NO;
    
    if (numPillsVal > epsilon)
    {
        [doseDescrip appendString:numPills];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypePillNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"pills", @"The plural name for pill drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numPillsVal];
        [doseDescrip appendFormat:@" %@", (multiple ? pluralName : singularName)];
        
        if (drugName && [drugName length] > 0)
        {
            NSString* drugNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ of %@", @"The phrase referring to the drug name for dosages"]);
            [doseDescrip setString:[NSString stringWithFormat:drugNamePhraseText, doseDescrip, drugName]];
        }
    }
    else if (drugName && [drugName length] > 0)
        [doseDescrip appendString:drugName];
    else
        [doseDescrip appendString:[singularName capitalizedString]];
    
    if (strength && [strength length] > 0)
    {
        [doseDescrip appendFormat:@" (%@", strength];
        
        if (numPillsVal > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", NSLocalizedStringWithDefaultValue(@"DrugTypePillQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"per pill", @"The phrase referring to the pill quantity for dosages"])];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numPills = [self getDescriptionForDoseQuantity:NumPillsQuantityName maxNumDecimals:2];
    NSString* strength = [self getDescriptionForDoseQuantity:PillStrengthQuantityName maxNumDecimals:2];
    return [PillDrugDosage getDescriptionForDrugDose:drugName numPills:numPills strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numPills = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumPillsKey value:&numPills modifiedDate:nil perDevice:nil];
    numPills = [DrugDosage getTrimmedValueInStringAsString:numPills maxNumDecimals:2];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PillStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [PillDrugDosage getDescriptionForDrugDose:drugName numPills:numPills strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumPillsQuantityName key:NumPillsKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:PillStrengthQuantityName key:PillStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumPillsQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePillQuantityPillsPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Pills per Dose", @"The pills per dose quantity for pill drug types"]);
	else if ([name caseInsensitiveCompare:PillStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePillQuantityPillStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Pill Strength", @"The pill strength quantity for pill drug types"]);
	else
		return nil;
}

// Returns all the UI settings for the quantity with the given input number
- (BOOL) getDoseQuantityUISettingsForInput:(int)inputNum
						  quantityName:(NSString**)quantityName
							 sigDigits:(int*)sigDigits
						   numDecimals:(int*)numDecimals
						   displayNone:(BOOL*)displayNone
							 allowZero:(BOOL*)allowZero
{
	if (inputNum == 0)
	{
		*quantityName = NumPillsQuantityName;
		*sigDigits = 4;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = PillStrengthQuantityName;
		*sigDigits = 7;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;		
		return YES;
	}
	else
		return NO;
}

// Returns all the UI settings for the remaining quantity
- (BOOL) getRemainingQuantityUISettings:(int*)sigDigits
							numDecimals:(int*)numDecimals
							displayNone:(BOOL*)displayNone
							  allowZero:(BOOL*)allowZero
{
	*sigDigits = 6;
	*numDecimals = 2;
	*displayNone = YES;
	*allowZero = YES;
	return YES;
}

// Returns all the UI settings for the refill quantity
- (BOOL) getRefillQuantityUISettings:(int*)sigDigits
						 numDecimals:(int*)numDecimals
						 displayNone:(BOOL*)displayNone
						   allowZero:(BOOL*)allowZero
{
	*sigDigits = 6;
	*numDecimals = 2;
	*displayNone = YES;
	*allowZero = YES;
	return YES;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypePillQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Pills Remaining", @"The number of pills remaining for pill drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypePillQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Pills per Refill", @"The number of pills per refill for pill drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [PillDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumPillsQuantityName;
}


@end
