//
//  PowderDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "PowderDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Powder-related names and keys
static NSString *PowderDosageTypeName = @"powder";
static NSString *PowderPerDoseQuantityName = @"powderPerDose";
static NSString *PowderStrengthQuantityName = @"powderStrength";
static NSString *PowderPerDoseKey = @"powderPerDose";
static NSString *PowderStrengthKey = @"powderStrength";

@implementation PowderDrugDosage

- (NSArray*)getPossiblePowderPerDoseUnits
{
	return [NSArray arrayWithObjects:
			DrugDosageUnitMicrograms,
            DrugDosageUnitMilligrams,
			DrugDosageUnitGrams,
			DrugDosageUnitKilograms,
			DrugDosageUnitMilliliters,
            DrugDosageUnitLiters,
            DrugDosageUnitMilliequivalents,
			nil];		
}

- (void)populateQuantities:(float)powderPerDose
	  powderPerDoseUnit:(NSString*)powderPerDoseUnit
	    powderStrength:(float)powderStrength
	powderStrengthUnit:(NSString*)powderStrengthUnit
{
	// Populate quantities
	NSArray* possiblePowderPerDoseUnits = [self getPossiblePowderPerDoseUnits];
	
	DrugDosageQuantity* powderPerDoseQuantity = [[DrugDosageQuantity alloc] init:powderPerDose unit:powderPerDoseUnit possibleUnits:possiblePowderPerDoseUnits];
	[doseQuantities setObject:powderPerDoseQuantity forKey:PowderPerDoseQuantityName];
	
	NSArray* possiblePowderStrengthUnits = [NSArray arrayWithObjects:
											   DrugDosageUnitMilligrams,
											   DrugDosageUnitGrams,
											   DrugDosageUnitMilliequivalents,
                                               DrugDosageUnitIU,
											   nil];
	DrugDosageQuantity* powderStrengthQuantity = [[DrugDosageQuantity alloc] init:powderStrength unit:powderStrengthUnit possibleUnits:possiblePowderStrengthUnits];
	[doseQuantities setObject:powderStrengthQuantity forKey:PowderStrengthQuantityName];	
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
			[self populateQuantities:-1.0f powderPerDoseUnit:nil powderStrength:-1.0f powderStrengthUnit:nil];
		}
		if (!remaining)
		{
			NSArray* possiblePowderPerDoseUnits = [self getPossiblePowderPerDoseUnits];
			[remainingQuantity.possibleUnits setArray:possiblePowderPerDoseUnits];
		}
		if (!refill)
		{
			NSArray* possiblePowderPerDoseUnits = [self getPossiblePowderPerDoseUnits];
			[refillQuantity.possibleUnits setArray:possiblePowderPerDoseUnits];			
		}
	}
	return self;			
}

            - (id)init:(float)powderPerDose
  powderPerDoseUnit:(NSString*)powderPerDoseUnit
    powderStrength:(float)powderStrength
powderStrengthUnit:(NSString*)powderStrengthUnit
			 remaining:(float)remaining
		 remainingUnit:(NSString*)remainingUnit
				refill:(float)refill
			refillUnit:(NSString*)refillUnit
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
		[self populateQuantities:powderPerDose powderPerDoseUnit:powderPerDoseUnit powderStrength:powderStrength powderStrengthUnit:powderStrengthUnit];
		
		NSArray* possiblePowderPerDoseUnits = [self getPossiblePowderPerDoseUnits];
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		[remainingQuantity.possibleUnits setArray:possiblePowderPerDoseUnits];
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[refillQuantity.possibleUnits setArray:possiblePowderPerDoseUnits];
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
	float powderPerDose = -1.0f;
	NSString* powderPerDoseUnit = nil;
	float powderStrength = -1.0f;
	NSString* powderStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:PowderPerDoseKey val:&powderPerDose unit:&powderPerDoseUnit];
	[self readDoseQuantityFromDictionary:dict key:PowderStrengthKey val:&powderStrength unit:&powderStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:powderPerDose
 powderPerDoseUnit:powderPerDoseUnit
   powderStrength:powderStrength
powderStrengthUnit:powderStrengthUnit
			remaining:remaining
		remainingUnit:remainingUnit
			   refill:refill
		   refillUnit:refillUnit
          refillsRemaining:left];	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[PowderDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:PowderDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:PowderPerDoseQuantityName key:PowderPerDoseKey numDecimals:2 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:PowderStrengthQuantityName key:PowderStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypePowder", @"Dosecast", [DosecastUtil getResourceBundle], @"Powder", @"The display name for powder drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [PowderDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:PowderDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [PowderDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName powderPerDose:(NSString*)powderPerDose strength:(NSString*)strength
{
	NSString* powderNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugTypePowderNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"powder dose", @"The name phrase for powder drug types"]);
    
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    if (powderPerDose && [powderPerDose length] > 0)
    {
		NSRange range = [powderPerDose rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
		if (range.location != NSNotFound)
		{
			powderPerDose = [NSString stringWithFormat:@"%@-%@", [powderPerDose substringToIndex:range.location],
                                   [powderPerDose substringFromIndex:(range.location+1)]];
		}
		
		[doseDescrip appendFormat:@"%@ %@", powderPerDose, powderNamePhraseText];
	}
	else
		[doseDescrip appendString:[DosecastUtil capitalizeFirstLetterOfString:powderNamePhraseText]];
    
    if (drugName && [drugName length] > 0)
	{
		NSString* drugNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ of %@", @"The phrase referring to the drug name for dosages"]);
		[doseDescrip setString:[NSString stringWithFormat:drugNamePhraseText, doseDescrip, drugName]];
	}
    
    if (strength && [strength length] > 0)
	{
		[doseDescrip appendFormat:@" (%@)", strength];
	}
	
	return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* powderPerDose = [self getDescriptionForDoseQuantity:PowderPerDoseQuantityName maxNumDecimals:2];
    NSString* strength = [self getDescriptionForDoseQuantity:PowderStrengthQuantityName maxNumDecimals:2];
    return [PowderDrugDosage getDescriptionForDrugDose:drugName powderPerDose:powderPerDose strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* powderPerDose = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PowderPerDoseKey value:&powderPerDose modifiedDate:nil perDevice:nil];
    powderPerDose = [DrugDosage getTrimmedValueInStringAsString:powderPerDose maxNumDecimals:2];
    
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PowderStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];
    
    return [PowderDrugDosage getDescriptionForDrugDose:drugName powderPerDose:powderPerDose strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:PowderPerDoseQuantityName key:PowderPerDoseKey numDecimals:2 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:PowderStrengthQuantityName key:PowderStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:PowderPerDoseQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePowderQuantityPowderPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Powder per Dose", @"The powder per dose quantity for powder drug types"]);
	else if ([name caseInsensitiveCompare:PowderStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePowderQuantityPowderStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Powder Strength", @"The powder strength quantity for powder drug types"]);
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
		*quantityName = PowderPerDoseQuantityName;
		*sigDigits = 5;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = PowderStrengthQuantityName;
		*sigDigits = 6;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypePowderQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Powder Remaining", @"The powder remaining for powder drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypePowderQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Powder per Refill", @"The powder per refill for powder drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [PowderDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return PowderPerDoseQuantityName;
}


@end
