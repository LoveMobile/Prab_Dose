//
//  CapsuleDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "CapsuleDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Capsule-related names and keys
static NSString *CapsuleDosageTypeName = @"capsule";
static NSString *NumCapsulesQuantityName = @"numCapsules";
static NSString *CapsuleStrengthQuantityName = @"capsuleStrength";
static NSString *NumCapsulesKey = @"numCapsules";
static NSString *CapsuleStrengthKey = @"capsuleStrength";

static float epsilon = 0.0001;

@implementation CapsuleDrugDosage

- (NSArray*)getPossibleCapsuleStrengthUnits
{
	return [NSArray arrayWithObjects:
			DrugDosageUnitGrams,
			DrugDosageUnitMilligrams,
			DrugDosageUnitMicrograms,
			DrugDosageUnitUnits,
            DrugDosageUnitIU,
            DrugDosageUnitMilliequivalents,
			nil];
}

- (void)populateQuantities:(float)numCapsules
	    capsuleStrength:(float)capsuleStrength
	capsuleStrengthUnit:(NSString*)capsuleStrengthUnit
{
	// Populate quantities
	
	DrugDosageQuantity* numCapsulesQuantity = [[DrugDosageQuantity alloc] init:numCapsules unit:nil possibleUnits:nil];
	[doseQuantities setObject:numCapsulesQuantity forKey:NumCapsulesQuantityName];
	
	NSArray* possibleCapsuleStrengthUnits = [self getPossibleCapsuleStrengthUnits];
	DrugDosageQuantity* capsuleStrengthQuantity = [[DrugDosageQuantity alloc] init:capsuleStrength unit:capsuleStrengthUnit possibleUnits:possibleCapsuleStrengthUnits];
	[doseQuantities setObject:capsuleStrengthQuantity forKey:CapsuleStrengthQuantityName];
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
			[self populateQuantities:0.0f capsuleStrength:-1.0f capsuleStrengthUnit:nil];
		}
	}
	return self;			
}

- (id)init:(float)numCapsulesPerDose
capsuleStrength:(float)capsuleStrength
capsuleStrengthUnit:(NSString*)capsuleStrengthUnit
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
		[self populateQuantities:numCapsulesPerDose capsuleStrength:capsuleStrength capsuleStrengthUnit:capsuleStrengthUnit];
		
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
	float numCapsulesPerDose = 0.0f;
    NSString* numCapsulesPerDoseUnit = nil;
	float capsuleStrength = -1.0f;
	NSString* capsuleStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumCapsulesKey val:&numCapsulesPerDose unit:&numCapsulesPerDoseUnit];
	[self readDoseQuantityFromDictionary:dict key:CapsuleStrengthKey val:&capsuleStrength unit:&capsuleStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numCapsulesPerDose
       capsuleStrength:capsuleStrength
   capsuleStrengthUnit:capsuleStrengthUnit
            remaining:remaining
               refill:refill
     refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[CapsuleDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:CapsuleDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumCapsulesQuantityName key:NumCapsulesKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:CapsuleStrengthQuantityName key:CapsuleStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCapsule", @"Dosecast", [DosecastUtil getResourceBundle], @"Capsule", @"The display name for capsule drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [CapsuleDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:CapsuleDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [CapsuleDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numCapsules:(NSString*)numCapsules strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numCapsulesPerDose;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numCapsules val:&numCapsulesPerDose unit:&unit];
    
    BOOL multiple = NO;
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"capsule", @"The singular name for capsule drug types"]);
    
    if (numCapsulesPerDose > epsilon)
    {
        [doseDescrip appendString:numCapsules];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"capsules", @"The plural name for capsule drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numCapsulesPerDose];
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
        
        if (numCapsulesPerDose > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"per capsule", @"The phrase referring to the capsule quantity for dosages"])];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numCapsules = [self getDescriptionForDoseQuantity:NumCapsulesQuantityName maxNumDecimals:2];
    NSString* strength = [self getDescriptionForDoseQuantity:CapsuleStrengthQuantityName maxNumDecimals:2];
    return [CapsuleDrugDosage getDescriptionForDrugDose:drugName numCapsules:numCapsules strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numCapsules = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumCapsulesKey value:&numCapsules modifiedDate:nil perDevice:nil];
    numCapsules = [DrugDosage getTrimmedValueInStringAsString:numCapsules maxNumDecimals:2];
    
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:CapsuleStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [CapsuleDrugDosage getDescriptionForDrugDose:drugName numCapsules:numCapsules strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumCapsulesQuantityName key:NumCapsulesKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:CapsuleStrengthQuantityName key:CapsuleStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumCapsulesQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleQuantityCapsulesPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Capsules per Dose", @"The capsules per dose quantity for capsule drug types"]);
	else if ([name caseInsensitiveCompare:CapsuleStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleQuantityCapsuleStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Capsule Strength", @"The capsule strength quantity for capsule drug types"]);
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
		*quantityName = NumCapsulesQuantityName;
		*sigDigits = 4;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = CapsuleStrengthQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Capsules Remaining", @"The capsules remaining for capsule drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCapsuleQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Capsules per Refill", @"The capsules per refill for capsule drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [CapsuleDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumCapsulesQuantityName;
}


@end
