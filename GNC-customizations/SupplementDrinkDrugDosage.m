//
//  SupplementDrinkDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "SupplementDrinkDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Drink-related names and keys
static NSString *SupplementDrinkDosageTypeName = @"supplementDrink";
static NSString *DrinkVolumeQuantityName = @"drinkVolume";
static NSString *DrinkStrengthQuantityName = @"drinkStrength";
static NSString *DrinkVolumeKey = @"drinkVolume";
static NSString *DrinkStrengthKey = @"drinkStrength";

@implementation SupplementDrinkDrugDosage

- (void)populateQuantities:(float)drinkVolume
	       drinkVolumeUnit:(NSString*)drinkVolumeUnit
	         drinkStrength:(float)drinkStrength
	     drinkStrengthUnit:(NSString*)drinkStrengthUnit
{
	// Populate quantities
	NSArray* possibleDrinkVolumeUnits = [NSArray arrayWithObjects:
											 DrugDosageUnitMilliliters,
											 DrugDosageUnitTeaspoons,
											 DrugDosageUnitTablespoons,
											  DrugDosageUnitOunces,
											 nil];	
	DrugDosageQuantity* drinkVolumeQuantity = [[DrugDosageQuantity alloc] init:drinkVolume unit:drinkVolumeUnit possibleUnits:possibleDrinkVolumeUnits];
	[doseQuantities setObject:drinkVolumeQuantity forKey:DrinkVolumeQuantityName];
	
	NSArray* possibleDrinkStrengthUnits = [NSArray arrayWithObjects:
											   DrugDosageUnitGramsPerMilliliter,
											   DrugDosageUnitMilligramsPerMilliliter,
											   DrugDosageUnitMilligramsPerTeaspoon,
											   DrugDosageUnitMilligramsPerTablespoon,
											   DrugDosageUnitMilligramsPerOunce,
											   nil];
	DrugDosageQuantity* drinkStrengthQuantity = [[DrugDosageQuantity alloc] init:drinkStrength unit:drinkStrengthUnit possibleUnits:possibleDrinkStrengthUnits];
	[doseQuantities setObject:drinkStrengthQuantity forKey:DrinkStrengthQuantityName];	
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
			[self populateQuantities:0.0f drinkVolumeUnit:DrugDosageUnitOunces drinkStrength:-1.0f drinkStrengthUnit:nil];
		}
	}
	return self;			
}

       - (id)init:(float)drinkVolume
  drinkVolumeUnit:(NSString*)drinkVolumeUnit
    drinkStrength:(float)drinkStrength
drinkStrengthUnit:(NSString*)drinkStrengthUnit
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
		[self populateQuantities:drinkVolume drinkVolumeUnit:drinkVolumeUnit drinkStrength:drinkStrength drinkStrengthUnit:drinkStrengthUnit];
		
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
	float drinkVolume = 0.0f;
	NSString* drinkVolumeUnit = DrugDosageUnitOunces;
	float drinkStrength = -1.0f;
	NSString* drinkStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:DrinkVolumeKey val:&drinkVolume unit:&drinkVolumeUnit];
	[self readDoseQuantityFromDictionary:dict key:DrinkStrengthKey val:&drinkStrength unit:&drinkStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:drinkVolume
	  drinkVolumeUnit:drinkVolumeUnit
		drinkStrength:drinkStrength
	drinkStrengthUnit:drinkStrengthUnit
			remaining:remaining
			   refill:refill
          refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementDrinkDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementDrinkDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:DrinkVolumeQuantityName key:DrinkVolumeKey numDecimals:1 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:DrinkStrengthQuantityName key:DrinkStrengthKey numDecimals:2 alwaysWrite:NO];
    if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:0];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:0];
    
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return @"Drink";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementDrinkDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementDrinkDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementDrinkDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName volume:(NSString*)volume strength:(NSString*)strength
{
    NSString* drinkNamePhraseText = @"drink";
    
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    if (volume && [volume length] > 0)
    {
        NSRange range = [volume rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
        if (range.location != NSNotFound)
        {
            volume = [NSString stringWithFormat:@"%@-%@", [volume substringToIndex:range.location],
                      [volume substringFromIndex:(range.location+1)]];
        }
        
        [doseDescrip appendFormat:@"%@ %@", volume, drinkNamePhraseText];
    }
    else
        [doseDescrip appendString:[DosecastUtil capitalizeFirstLetterOfString:drinkNamePhraseText]];
    
    if (drugName && [drugName length] > 0)
    {
        NSString* drugNamePhraseText = @"%@ of %@";
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
    NSString* volume = [self getDescriptionForDoseQuantity:DrinkVolumeQuantityName maxNumDecimals:1];
    NSString* strength = [self getDescriptionForDoseQuantity:DrinkStrengthQuantityName maxNumDecimals:2];
    return [SupplementDrinkDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* volume = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DrinkVolumeKey value:&volume modifiedDate:nil perDevice:nil];
    volume = [DrugDosage getTrimmedValueInStringAsString:volume maxNumDecimals:1];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DrinkStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [SupplementDrinkDrugDosage getDescriptionForDrugDose:drugName volume:volume strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:DrinkVolumeQuantityName key:DrinkVolumeKey numDecimals:1 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:DrinkStrengthQuantityName key:DrinkStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:DrinkVolumeQuantityName] == NSOrderedSame)
		return @"Drink Volume";
	else if ([name caseInsensitiveCompare:DrinkStrengthQuantityName] == NSOrderedSame)
		return @"Drink Strength";
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
		*quantityName = DrinkVolumeQuantityName;
		*sigDigits = 4;
		*numDecimals = 1;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = DrinkStrengthQuantityName;
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
	*sigDigits = 3;
	*numDecimals = 0;
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
	*sigDigits = 3;
	*numDecimals = 0;
	*displayNone = YES;
	*allowZero = YES;
	return YES;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return @"Drinks Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Drinks per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementDrinkDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return nil;
}

@end
