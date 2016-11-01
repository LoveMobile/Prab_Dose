//
//  InfusionDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "InfusionDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Infusion-related names and keys
static NSString *InfusionDosageTypeName = @"infusion";
static NSString *InfusionVolumeQuantityName = @"infusionVolume";
static NSString *InfusionStrengthQuantityName = @"infusionStrength";
static NSString *InfusionRateQuantityName = @"infusionRate";
static NSString *InfusionVolumeKey = @"infusionVolume";
static NSString *InfusionStrengthKey = @"infusionStrength";
static NSString *InfusionRateKey = @"infusionRate";

@implementation InfusionDrugDosage

- (NSArray*)getPossibleInfusionVolumeUnits
{
	return [NSArray arrayWithObjects:
			DrugDosageUnitMilliliters,
            DrugDosageUnitUnits,
            DrugDosageUnitIU,
            DrugDosageUnitCubicCentimeters,
            DrugDosageUnitMilligrams,
            DrugDosageUnitMicrograms,
			nil];
}

- (void)populateQuantities:(float)infusionVolume
	  infusionVolumeUnit:(NSString*)infusionVolumeUnit
	    infusionStrength:(float)infusionStrength
	infusionStrengthUnit:(NSString*)infusionStrengthUnit
          infusionRate:(float)infusionRate
      infusionRateUnit:(NSString*)infusionRateUnit
{
	// Populate quantities
	NSArray* possibleInfusionVolumeUnits = [self getPossibleInfusionVolumeUnits];
	
	DrugDosageQuantity* infusionVolumeQuantity = [[DrugDosageQuantity alloc] init:infusionVolume unit:infusionVolumeUnit possibleUnits:possibleInfusionVolumeUnits];
	[doseQuantities setObject:infusionVolumeQuantity forKey:InfusionVolumeQuantityName];
	
	NSArray* possibleInfusionStrengthUnits = [NSArray arrayWithObjects:
                                              DrugDosageUnitMilligramsPerMilliliter,
                                              DrugDosageUnitUnitsPerMilliliter,
                                              DrugDosageUnitIUPerMilliliter,
                                              DrugDosageUnitMilligramsPerCubicCentimeter,
                                              DrugDosageUnitUnitsPerCubicCentimeter,
                                              DrugDosageUnitIUPerCubicCentimeter,
											   nil];
	DrugDosageQuantity* infusionStrengthQuantity = [[DrugDosageQuantity alloc] init:infusionStrength unit:infusionStrengthUnit possibleUnits:possibleInfusionStrengthUnits];
	[doseQuantities setObject:infusionStrengthQuantity forKey:InfusionStrengthQuantityName];	

	NSArray* possibleInfusionRateUnits = [NSArray arrayWithObjects:
                                              DrugDosageUnitMillilitersPerDay,
                                              DrugDosageUnitMillilitersPerHour,
                                              DrugDosageUnitMillilitersPerMinute,
                                              DrugDosageUnitCubicCentimetersPerDay,
                                              DrugDosageUnitCubicCentimetersPerHour,
                                              DrugDosageUnitCubicCentimetersPerMinute,
                                              DrugDosageUnitUnitsPerDay,
                                              DrugDosageUnitUnitsPerHour,
                                              DrugDosageUnitUnitsPerMinute,
                                              nil];
	DrugDosageQuantity* infusionRateQuantity = [[DrugDosageQuantity alloc] init:infusionRate unit:infusionRateUnit possibleUnits:possibleInfusionRateUnits];
	[doseQuantities setObject:infusionRateQuantity forKey:InfusionRateQuantityName];
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
			[self populateQuantities:-1.0f infusionVolumeUnit:nil infusionStrength:-1.0f infusionStrengthUnit:nil infusionRate:-1.0f infusionRateUnit:nil];
		}
		if (!remaining)
		{
			NSArray* possibleInfusionVolumeUnits = [self getPossibleInfusionVolumeUnits];
			[remainingQuantity.possibleUnits setArray:possibleInfusionVolumeUnits];
		}
		if (!refill)
		{
			NSArray* possibleInfusionVolumeUnits = [self getPossibleInfusionVolumeUnits];
			[refillQuantity.possibleUnits setArray:possibleInfusionVolumeUnits];			
		}
	}
	return self;			
}

- (id)init:(float)infusionVolume
infusionVolumeUnit:(NSString*)infusionVolumeUnit
infusionStrength:(float)infusionStrength
infusionStrengthUnit:(NSString*)infusionStrengthUnit
infusionRate:(float)infusionRate
infusionRateUnit:(NSString*)infusionRateUnit
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
		[self populateQuantities:infusionVolume infusionVolumeUnit:infusionVolumeUnit infusionStrength:infusionStrength infusionStrengthUnit:infusionStrengthUnit infusionRate:infusionRate infusionRateUnit:infusionRateUnit];
		
		NSArray* possibleInfusionVolumeUnits = [self getPossibleInfusionVolumeUnits];
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		[remainingQuantity.possibleUnits setArray:possibleInfusionVolumeUnits];
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[refillQuantity.possibleUnits setArray:possibleInfusionVolumeUnits];
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
	float infusionVolume = -1.0f;
	NSString* infusionVolumeUnit = nil;
	float infusionStrength = -1.0f;
	NSString* infusionStrengthUnit = nil;
	float infusionRate = -1.0f;
	NSString* infusionRateUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:InfusionVolumeKey val:&infusionVolume unit:&infusionVolumeUnit];
	[self readDoseQuantityFromDictionary:dict key:InfusionStrengthKey val:&infusionStrength unit:&infusionStrengthUnit];
	[self readDoseQuantityFromDictionary:dict key:InfusionRateKey val:&infusionRate unit:&infusionRateUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:infusionVolume
 infusionVolumeUnit:infusionVolumeUnit
   infusionStrength:infusionStrength
infusionStrengthUnit:infusionStrengthUnit
         infusionRate:infusionRate
     infusionRateUnit:infusionRateUnit
			remaining:remaining
		remainingUnit:remainingUnit
			   refill:refill
		   refillUnit:refillUnit
          refillsRemaining:left];	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[InfusionDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:InfusionDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:InfusionVolumeQuantityName key:InfusionVolumeKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:InfusionStrengthQuantityName key:InfusionStrengthKey numDecimals:2 alwaysWrite:NO];
    [self populateDictionaryForDoseQuantity:dict quantityName:InfusionRateQuantityName key:InfusionRateKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusion", @"Dosecast", [DosecastUtil getResourceBundle], @"Infusion", @"The display name for infusion drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [InfusionDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:InfusionDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [InfusionDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName volume:(NSString*)volume strength:(NSString*)strength rate:(NSString*)rate
{
	NSString* infusionNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"infusion", @"The name phrase for infusion drug types"]);
    
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    if (volume && [volume length] > 0)
    {
		NSRange range = [volume rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
		if (range.location != NSNotFound)
		{
			volume = [NSString stringWithFormat:@"%@-%@", [volume substringToIndex:range.location],
                                   [volume substringFromIndex:(range.location+1)]];
		}
		
		[doseDescrip appendFormat:@"%@ %@", volume, infusionNamePhraseText];
	}
	else
		[doseDescrip appendString:[DosecastUtil capitalizeFirstLetterOfString:infusionNamePhraseText]];
    
    if (drugName && [drugName length] > 0)
	{
		NSString* drugNamePhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageNamePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ of %@", @"The phrase referring to the drug name for dosages"]);
		[doseDescrip setString:[NSString stringWithFormat:drugNamePhraseText, doseDescrip, drugName]];
	}
    
    if ((strength && [strength length] > 0) ||
        (rate && [rate length] > 0))
    {
        NSMutableString* strengthRateStr = [NSMutableString stringWithString:@""];
        
        if (strength && [strength length] > 0)
        {
            [strengthRateStr appendFormat:@"(%@", strength];
        }
        
        if (rate && [rate length] > 0)
        {
            if ([strengthRateStr length] == 0)
                [strengthRateStr appendString:@"("];
            else
                [strengthRateStr appendString:@", "];

            [strengthRateStr appendString:rate];
        }

        [strengthRateStr appendString:@")"];
        
        [doseDescrip appendFormat:@" %@", strengthRateStr];
    }
    
	return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* volume = [self getDescriptionForDoseQuantity:InfusionVolumeQuantityName maxNumDecimals:1];
    NSString* strength = [self getDescriptionForDoseQuantity:InfusionStrengthQuantityName maxNumDecimals:2];
    NSString* rate = [self getDescriptionForDoseQuantity:InfusionRateQuantityName maxNumDecimals:2];
    return [InfusionDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength rate:rate];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* volume = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InfusionVolumeKey value:&volume modifiedDate:nil perDevice:nil];
    volume = [DrugDosage getTrimmedValueInStringAsString:volume maxNumDecimals:1];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InfusionStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    NSString* rate = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InfusionRateKey value:&rate modifiedDate:nil perDevice:nil];
    rate = [DrugDosage getTrimmedValueInStringAsString:rate maxNumDecimals:2];

    return [InfusionDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength rate:rate];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:InfusionVolumeQuantityName key:InfusionVolumeKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:InfusionStrengthQuantityName key:InfusionStrengthKey numDecimals:2 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:InfusionRateQuantityName key:InfusionRateKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:InfusionVolumeQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionQuantityInfusionVolume", @"Dosecast", [DosecastUtil getResourceBundle], @"Infusion Volume", @"The infusion volume quantity for infusion drug types"]);
	else if ([name caseInsensitiveCompare:InfusionStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionQuantityInfusionStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Infusion Strength", @"The infusion strength quantity for infusion drug types"]);
    else if ([name caseInsensitiveCompare:InfusionRateQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionQuantityInfusionRate", @"Dosecast", [DosecastUtil getResourceBundle], @"Infusion Rate", @"The infusion rate quantity for infusion drug types"]);
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
		*quantityName = InfusionVolumeQuantityName;
		*sigDigits = 4;
		*numDecimals = 1;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = InfusionStrengthQuantityName;
		*sigDigits = 6;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;		
		return YES;
	}
	else if (inputNum == 2)
	{
		*quantityName = InfusionRateQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Volume Remaining", @"The volume remaining for infusion drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInfusionQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Volume per Refill", @"The volume per refill for infusion drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [InfusionDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return InfusionVolumeQuantityName;
}


@end
