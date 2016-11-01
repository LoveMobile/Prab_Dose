//
//  LiquidDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "LiquidDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Liquid-related names and keys
static NSString *LiquidDosageTypeName = @"liquidDose";
static NSString *LiquidDoseVolumeQuantityName = @"liquidDoseVolume";
static NSString *LiquidDoseStrengthQuantityName = @"liquidDoseStrength";
static NSString *LiquidDoseVolumeKey = @"liquidDoseVolume";
static NSString *LiquidDoseStrengthKey = @"liquidDoseStrength";

@implementation LiquidDrugDosage

- (NSArray*)getPossibleLiquidDoseVolumeUnits
{
	return [NSArray arrayWithObjects:
			DrugDosageUnitMilliliters,
			DrugDosageUnitTeaspoons,
			DrugDosageUnitTablespoons,
			DrugDosageUnitOunces,
            DrugDosageUnitUnits,
			nil];		
}

- (void)populateQuantities:(float)liquidDoseVolume
	  liquidDoseVolumeUnit:(NSString*)liquidDoseVolumeUnit
	    liquidDoseStrength:(float)liquidDoseStrength
	liquidDoseStrengthUnit:(NSString*)liquidDoseStrengthUnit
{
	// Populate quantities
	NSArray* possibleLiquidDoseVolumeUnits = [self getPossibleLiquidDoseVolumeUnits];
	
	DrugDosageQuantity* liquidDoseVolumeQuantity = [[DrugDosageQuantity alloc] init:liquidDoseVolume unit:liquidDoseVolumeUnit possibleUnits:possibleLiquidDoseVolumeUnits];
	[doseQuantities setObject:liquidDoseVolumeQuantity forKey:LiquidDoseVolumeQuantityName];
	
	NSArray* possibleLiquidDoseStrengthUnits = [NSArray arrayWithObjects:
											   DrugDosageUnitGramsPerMilliliter,
											   DrugDosageUnitMilligramsPerMilliliter,
											   DrugDosageUnitMilligramsPerTeaspoon,
											   DrugDosageUnitMilligramsPerTablespoon,
											   DrugDosageUnitMilligramsPerOunce,
                                               DrugDosageUnitMilligramsPerUnit,
                                               DrugDosageUnitIU,
											   nil];
	DrugDosageQuantity* liquidDoseStrengthQuantity = [[DrugDosageQuantity alloc] init:liquidDoseStrength unit:liquidDoseStrengthUnit possibleUnits:possibleLiquidDoseStrengthUnits];
	[doseQuantities setObject:liquidDoseStrengthQuantity forKey:LiquidDoseStrengthQuantityName];	
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
			[self populateQuantities:-1.0f liquidDoseVolumeUnit:nil liquidDoseStrength:-1.0f liquidDoseStrengthUnit:nil];
		}
		if (!remaining)
		{
			NSArray* possibleLiquidDoseVolumeUnits = [self getPossibleLiquidDoseVolumeUnits];
			[remainingQuantity.possibleUnits setArray:possibleLiquidDoseVolumeUnits];
		}
		if (!refill)
		{
			NSArray* possibleLiquidDoseVolumeUnits = [self getPossibleLiquidDoseVolumeUnits];
			[refillQuantity.possibleUnits setArray:possibleLiquidDoseVolumeUnits];			
		}
	}
	return self;			
}

            - (id)init:(float)liquidDoseVolume
  liquidDoseVolumeUnit:(NSString*)liquidDoseVolumeUnit
    liquidDoseStrength:(float)liquidDoseStrength
liquidDoseStrengthUnit:(NSString*)liquidDoseStrengthUnit
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
		[self populateQuantities:liquidDoseVolume liquidDoseVolumeUnit:liquidDoseVolumeUnit liquidDoseStrength:liquidDoseStrength liquidDoseStrengthUnit:liquidDoseStrengthUnit];
		
		NSArray* possibleLiquidDoseVolumeUnits = [self getPossibleLiquidDoseVolumeUnits];
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		[remainingQuantity.possibleUnits setArray:possibleLiquidDoseVolumeUnits];
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[refillQuantity.possibleUnits setArray:possibleLiquidDoseVolumeUnits];
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
	float liquidDoseVolume = -1.0f;
	NSString* liquidDoseVolumeUnit = nil;
	float liquidDoseStrength = -1.0f;
	NSString* liquidDoseStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:LiquidDoseVolumeKey val:&liquidDoseVolume unit:&liquidDoseVolumeUnit];
	[self readDoseQuantityFromDictionary:dict key:LiquidDoseStrengthKey val:&liquidDoseStrength unit:&liquidDoseStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:liquidDoseVolume
 liquidDoseVolumeUnit:liquidDoseVolumeUnit
   liquidDoseStrength:liquidDoseStrength
liquidDoseStrengthUnit:liquidDoseStrengthUnit
			remaining:remaining
		remainingUnit:remainingUnit
			   refill:refill
		   refillUnit:refillUnit
          refillsRemaining:left];	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[LiquidDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:LiquidDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:LiquidDoseVolumeQuantityName key:LiquidDoseVolumeKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:LiquidDoseStrengthQuantityName key:LiquidDoseStrengthKey numDecimals:2 alwaysWrite:NO];
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:1];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:1];
    
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeLiquid", @"Dosecast", [DosecastUtil getResourceBundle], @"Liquid", @"The display name for liquid drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [LiquidDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:LiquidDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [LiquidDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName volume:(NSString*)volume strength:(NSString*)strength
{
	NSString* liquidNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugTypeLiquidNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"liquid dose", @"The name phrase for liquid drug types"]);
    
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    if (volume && [volume length] > 0)
    {
		NSRange range = [volume rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
		if (range.location != NSNotFound)
		{
			volume = [NSString stringWithFormat:@"%@-%@", [volume substringToIndex:range.location],
                                   [volume substringFromIndex:(range.location+1)]];
		}
		
		[doseDescrip appendFormat:@"%@ %@", volume, liquidNamePhraseText];
	}
	else
		[doseDescrip appendString:[DosecastUtil capitalizeFirstLetterOfString:liquidNamePhraseText]];
    
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
    NSString* volume = [self getDescriptionForDoseQuantity:LiquidDoseVolumeQuantityName maxNumDecimals:1];
    NSString* strength = [self getDescriptionForDoseQuantity:LiquidDoseStrengthQuantityName maxNumDecimals:2];
    return [LiquidDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* volume = nil;
    [Preferences readPreferenceFromDictionary:doseData key:LiquidDoseVolumeKey value:&volume modifiedDate:nil perDevice:nil];
    volume = [DrugDosage getTrimmedValueInStringAsString:volume maxNumDecimals:1];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:LiquidDoseStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [LiquidDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:LiquidDoseVolumeQuantityName key:LiquidDoseVolumeKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:LiquidDoseStrengthQuantityName key:LiquidDoseStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:LiquidDoseVolumeQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeLiquidQuantityDoseVolume", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose Volume", @"The dose volume quantity for liquid drug types"]);
	else if ([name caseInsensitiveCompare:LiquidDoseStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeLiquidQuantityDoseStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose Strength", @"The dose strength quantity for liquid drug types"]);
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
		*quantityName = LiquidDoseVolumeQuantityName;
		*sigDigits = 4;
		*numDecimals = 1;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = LiquidDoseStrengthQuantityName;
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
	*sigDigits = 5;
	*numDecimals = 1;
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
	*sigDigits = 5;
	*numDecimals = 1;
	*displayNone = YES;
	*allowZero = YES;
	return YES;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeLiquidQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Volume Remaining", @"The volume remaining for liquid drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeLiquidQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Volume per Refill", @"The volume per refill for liquid drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [LiquidDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return LiquidDoseVolumeQuantityName;
}


@end
