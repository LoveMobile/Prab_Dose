//
//  InjectionDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "InjectionDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Injection-related names and keys
static NSString *InjectionDosageTypeName = @"injection";
static NSString *InjectionAmountQuantityName = @"injectionAmount";
static NSString *InjectionStrengthQuantityName = @"injectionStrength";
static NSString *InjectionAmountKey = @"injectionAmount";
static NSString *InjectionStrengthKey = @"injectionStrength";

@implementation InjectionDrugDosage

- (NSArray*)getPossibleInjectionAmountUnits
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

- (void)populateQuantities:(float)injectionAmount
	   injectionAmountUnit:(NSString*)injectionAmountUnit
		 injectionStrength:(float)injectionStrength
	 injectionStrengthUnit:(NSString*)injectionStrengthUnit
{
	// Populate quantities
	NSArray* possibleInjectionAmountUnits = [self getPossibleInjectionAmountUnits];
	
	DrugDosageQuantity* injectionAmountQuantity = [[DrugDosageQuantity alloc] init:injectionAmount unit:injectionAmountUnit possibleUnits:possibleInjectionAmountUnits];
	[doseQuantities setObject:injectionAmountQuantity forKey:InjectionAmountQuantityName];
	
	NSArray* possibleInjectionStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitMilligramsPerMilliliter,
										  DrugDosageUnitUnitsPerMilliliter,
										  DrugDosageUnitIUPerMilliliter,   
										  DrugDosageUnitMilligramsPerCubicCentimeter,
										  DrugDosageUnitUnitsPerCubicCentimeter,
										  DrugDosageUnitIUPerCubicCentimeter,
										  nil];
	DrugDosageQuantity* injectionStrengthQuantity = [[DrugDosageQuantity alloc] init:injectionStrength unit:injectionStrengthUnit possibleUnits:possibleInjectionStrengthUnits];
	[doseQuantities setObject:injectionStrengthQuantity forKey:InjectionStrengthQuantityName];	
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
			[self populateQuantities:-1.0f injectionAmountUnit:nil injectionStrength:-1.0f injectionStrengthUnit:nil];
		}
		if (!remaining)
		{
			NSArray* possibleInjectionAmountUnits = [self getPossibleInjectionAmountUnits];
			[remainingQuantity.possibleUnits setArray:possibleInjectionAmountUnits];
		}
		if (!refill)
		{
			NSArray* possibleInjectionAmountUnits = [self getPossibleInjectionAmountUnits];
			[refillQuantity.possibleUnits setArray:possibleInjectionAmountUnits];
		}		
	}
	return self;			
}

           - (id)init:(float)injectionAmount
  injectionAmountUnit:(NSString*)injectionAmountUnit
    injectionStrength:(float)injectionStrength
injectionStrengthUnit:(NSString*)injectionStrengthUnit
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
		[self populateQuantities:injectionAmount injectionAmountUnit:injectionAmountUnit injectionStrength:injectionStrength injectionStrengthUnit:injectionStrengthUnit];
				
		NSArray* possibleInjectionAmountUnits = [self getPossibleInjectionAmountUnits];
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[remainingQuantity.possibleUnits setArray:possibleInjectionAmountUnits];
		[refillQuantity.possibleUnits setArray:possibleInjectionAmountUnits];
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
	float injectionAmount = -1.0f;
	NSString* injectionAmountUnit = nil;
	float injectionStrength = -1.0f;
	NSString* injectionStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:InjectionAmountKey val:&injectionAmount unit:&injectionAmountUnit];
	[self readDoseQuantityFromDictionary:dict key:InjectionStrengthKey val:&injectionStrength unit:&injectionStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:injectionAmount
  injectionAmountUnit:injectionAmountUnit
	injectionStrength:injectionStrength
injectionStrengthUnit:injectionStrengthUnit
			remaining:remaining
		remainingUnit:remainingUnit
			   refill:refill
		   refillUnit:refillUnit
            refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[InjectionDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:InjectionDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:InjectionAmountQuantityName key:InjectionAmountKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:InjectionStrengthQuantityName key:InjectionStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInjection", @"Dosecast", [DosecastUtil getResourceBundle], @"Injection", @"The display name for injection drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [InjectionDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:InjectionDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [InjectionDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName amount:(NSString*)amount strength:(NSString*)strength
{
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeInjectionNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"injection", @"The singular name for injection drug types"]);

    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    if (amount && [amount length] > 0)
    {
		NSRange range = [amount rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
		if (range.location != NSNotFound)
		{
			amount = [NSString stringWithFormat:@"%@-%@", [amount substringToIndex:range.location],
                                  [amount substringFromIndex:(range.location+1)]];
		}
        
		[doseDescrip appendFormat:@"%@ %@", amount, singularName];
	}
	else
        [doseDescrip appendString:[DosecastUtil capitalizeFirstLetterOfString:singularName]];
    
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
    NSString* amount = [self getDescriptionForDoseQuantity:InjectionAmountQuantityName maxNumDecimals:1];
    NSString* strength = [self getDescriptionForDoseQuantity:InjectionStrengthQuantityName maxNumDecimals:2];
    return [InjectionDrugDosage getDescriptionForDrugDose:drugName amount:amount strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* amount = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InjectionAmountKey value:&amount modifiedDate:nil perDevice:nil];
    amount = [DrugDosage getTrimmedValueInStringAsString:amount maxNumDecimals:1];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:InjectionStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [InjectionDrugDosage getDescriptionForDrugDose:drugName amount:amount strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:InjectionAmountQuantityName key:InjectionAmountKey numDecimals:1 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:InjectionStrengthQuantityName key:InjectionStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:InjectionAmountQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInjectionQuantityInjectionAmount", @"Dosecast", [DosecastUtil getResourceBundle], @"Injection Amount", @"The injection amount quantity for injection drug types"]);
	else if ([name caseInsensitiveCompare:InjectionStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeInjectionQuantityInjectionStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Injection Strength", @"The injection strength quantity for injection drug types"]);
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
		*quantityName = InjectionAmountQuantityName;
		*sigDigits = 4;
		*numDecimals = 1;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = InjectionStrengthQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInjectionQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Amount Remaining", @"The amount remaining for injection drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeInjectionQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Amount per Refill", @"The amount per refill for injection drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [InjectionDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return InjectionAmountQuantityName;
}


@end
