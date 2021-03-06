//
//  InhalerDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "InhalerDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Inhaler-related names and keys
static NSString *InhalerDosageTypeName = @"inhaler";
static NSString *NumPuffsQuantityName = @"numPuffs";
static NSString *NumPuffsKey = @"numPuffs";
static NSString *InhalerStrengthQuantityName = @"inhalerStrength";
static NSString *InhalerStrengthKey = @"inhalerStrength";

static float epsilon = 0.0001;

@implementation InhalerDrugDosage

- (void)populateQuantities:(float)numPuffs
           inhalerStrength:(float)inhalerStrength
       inhalerStrengthUnit:(NSString*)inhalerStrengthUnit
{
	// Populate quantities
	DrugDosageQuantity* numPuffsQuantity = [[DrugDosageQuantity alloc] init:numPuffs unit:nil possibleUnits:nil];
	[doseQuantities setObject:numPuffsQuantity forKey:NumPuffsQuantityName];
	
    NSArray* possibleInhalerStrengthUnits = [NSArray arrayWithObjects:
            DrugDosageUnitMicrograms,
            DrugDosageUnitMilligramsPerMilliliter,
            DrugDosageUnitGramsPerMilliliter,
            DrugDosageUnitMilligrams,
            nil];		
	DrugDosageQuantity* inhalerStrengthQuantity = [[DrugDosageQuantity alloc] init:inhalerStrength unit:inhalerStrengthUnit possibleUnits:possibleInhalerStrengthUnits];
	[doseQuantities setObject:inhalerStrengthQuantity forKey:InhalerStrengthQuantityName];	
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
			[self populateQuantities:0.0f inhalerStrength:-1.0f inhalerStrengthUnit:nil];
		}
	}
	return self;			
}

- (id)initWithPuffs:(float)numPuffs
    inhalerStrength:(float)inhalerStrength
inhalerStrengthUnit:(NSString*)inhalerStrengthUnit
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
		[self populateQuantities:numPuffs inhalerStrength:inhalerStrength inhalerStrengthUnit:inhalerStrengthUnit];
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
	float numPuffs = 0.0f;
	NSString* numPuffsUnit = nil;
    float inhalerStrength = -1.0f;
	NSString* inhalerStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumPuffsKey val:&numPuffs unit:&numPuffsUnit];
    [self readDoseQuantityFromDictionary:dict key:InhalerStrengthKey val:&inhalerStrength unit:&inhalerStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
		
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self initWithPuffs:numPuffs
               inhalerStrength:inhalerStrength
           inhalerStrengthUnit:inhalerStrengthUnit
                     remaining:remaining
                        refill:refill
              refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[InhalerDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:InhalerDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumPuffsQuantityName key:NumPuffsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:InhalerStrengthQuantityName key:InhalerStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInhaler", @"Dosecast", [DosecastUtil getResourceBundle], @"Inhaler", @"The display name for inhaler drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [InhalerDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:InhalerDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [InhalerDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numPuffs:(NSString*)numPuffs strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numPuffsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numPuffs val:&numPuffsVal unit:&unit];
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"puff", @"The singular name for inhaler drug types"]);
    
    BOOL multiple = NO;
    
    if (numPuffsVal > epsilon)
    {
        [doseDescrip appendString:numPuffs];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"puffs", @"The plural name for inhaler drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numPuffsVal];
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
        [doseDescrip appendFormat:@" (%@)", strength];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{		
    NSString* numPuffs = [self getDescriptionForDoseQuantity:NumPuffsQuantityName maxNumDecimals:0];
    NSString* strength = [self getDescriptionForDoseQuantity:InhalerStrengthQuantityName maxNumDecimals:2];
    return [InhalerDrugDosage getDescriptionForDrugDose:drugName numPuffs:numPuffs strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numPuffs = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumPuffsKey value:&numPuffs modifiedDate:nil perDevice:nil];
    numPuffs = [DrugDosage getTrimmedValueInStringAsString:numPuffs maxNumDecimals:0];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InhalerStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [InhalerDrugDosage getDescriptionForDrugDose:drugName numPuffs:numPuffs strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];

    [self populateDictionaryForDoseQuantity:dict quantityName:NumPuffsQuantityName key:NumPuffsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:InhalerStrengthQuantityName key:InhalerStrengthKey numDecimals:2 alwaysWrite:NO];

    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumPuffsQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerQuantityPuffsPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Puffs per Dose", @"The puffs per dose quantity for inhaler drug types"]);
	else if ([name caseInsensitiveCompare:InhalerStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerQuantityInhalerStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Inhaler Strength", @"The inhaler strength quantity for inhaler drug types"]);
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
		*quantityName = NumPuffsQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
    else if (inputNum == 1)
	{
		*quantityName = InhalerStrengthQuantityName;
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
	*sigDigits = 4;
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
	*sigDigits = 4;
	*numDecimals = 0;
	*displayNone = YES;
	*allowZero = YES;
	return YES;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Puffs Remaining", @"The number of puffs remaining for inhaler drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInhalerQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Puffs per Refill", @"The number of puffs per refill for inhaler drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [InhalerDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumPuffsQuantityName;
}


@end
