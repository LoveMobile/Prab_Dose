//
//  CapletDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "CapletDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Caplet-related names and keys
static NSString *CapletDosageTypeName = @"caplet";
static NSString *NumCapletsQuantityName = @"numCaplets";
static NSString *CapletStrengthQuantityName = @"capletStrength";
static NSString *NumCapletsKey = @"numCaplets";
static NSString *CapletStrengthKey = @"capletStrength";

static float epsilon = 0.0001;

@implementation CapletDrugDosage

- (NSArray*)getPossibleCapletStrengthUnits
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

- (void)populateQuantities:(float)numCaplets
	    capletStrength:(float)capletStrength
	capletStrengthUnit:(NSString*)capletStrengthUnit
{
	// Populate quantities
	
	DrugDosageQuantity* numCapletsQuantity = [[DrugDosageQuantity alloc] init:numCaplets unit:nil possibleUnits:nil];
	[doseQuantities setObject:numCapletsQuantity forKey:NumCapletsQuantityName];
	
	NSArray* possibleCapletStrengthUnits = [self getPossibleCapletStrengthUnits];
	DrugDosageQuantity* capletStrengthQuantity = [[DrugDosageQuantity alloc] init:capletStrength unit:capletStrengthUnit possibleUnits:possibleCapletStrengthUnits];
	[doseQuantities setObject:capletStrengthQuantity forKey:CapletStrengthQuantityName];
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
			[self populateQuantities:0.0f capletStrength:-1.0f capletStrengthUnit:nil];
		}
	}
	return self;			
}

- (id)init:(float)numCapletsPerDose
capletStrength:(float)capletStrength
capletStrengthUnit:(NSString*)capletStrengthUnit
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
		[self populateQuantities:numCapletsPerDose capletStrength:capletStrength capletStrengthUnit:capletStrengthUnit];
		
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
	float numCapletsPerDose = 0.0f;
    NSString* numCapletsPerDoseUnit = nil;
	float capletStrength = -1.0f;
	NSString* capletStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumCapletsKey val:&numCapletsPerDose unit:&numCapletsPerDoseUnit];
	[self readDoseQuantityFromDictionary:dict key:CapletStrengthKey val:&capletStrength unit:&capletStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numCapletsPerDose
       capletStrength:capletStrength
   capletStrengthUnit:capletStrengthUnit
            remaining:remaining
               refill:refill
     refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[CapletDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:CapletDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumCapletsQuantityName key:NumCapletsKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:CapletStrengthQuantityName key:CapletStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCaplet", @"Dosecast", [DosecastUtil getResourceBundle], @"Caplet", @"The display name for caplet drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [CapletDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:CapletDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [CapletDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numCaplets:(NSString*)numCaplets strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numCapletsPerDose;
    NSString* numCapletsUnit = nil;
    [DrugDosage getQuantityFromString:numCaplets val:&numCapletsPerDose unit:&numCapletsUnit];
    
    BOOL multiple = NO;
    
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeCapletNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"caplet", @"The singular name for caplet drug types"]);
    if (numCapletsPerDose > epsilon)
    {
        [doseDescrip appendString:numCaplets];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeCapletNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"caplets", @"The plural name for caplet drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numCapletsPerDose];
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
        
        if (numCapletsPerDose > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", NSLocalizedStringWithDefaultValue(@"DrugTypeCapletQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"per caplet", @"The phrase referring to the caplet quantity for dosages"])];
        else
            [doseDescrip appendString:@")"];
    }
    
	return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numCaplets = [self getDescriptionForDoseQuantity:NumCapletsQuantityName maxNumDecimals:2];
    NSString* strength = [self getDescriptionForDoseQuantity:CapletStrengthQuantityName maxNumDecimals:2];
    return [CapletDrugDosage getDescriptionForDrugDose:drugName numCaplets:numCaplets strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numCaplets = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumCapletsKey value:&numCaplets modifiedDate:nil perDevice:nil];
    numCaplets = [DrugDosage getTrimmedValueInStringAsString:numCaplets maxNumDecimals:2];
    
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:CapletStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];
    
    return [CapletDrugDosage getDescriptionForDrugDose:drugName numCaplets:numCaplets strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumCapletsQuantityName key:NumCapletsKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:CapletStrengthQuantityName key:CapletStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumCapletsQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeCapletQuantityCapletsPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Caplets per Dose", @"The caplets per dose quantity for caplet drug types"]);
	else if ([name caseInsensitiveCompare:CapletStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeCapletQuantityCapletStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Caplet Strength", @"The caplet strength quantity for caplet drug types"]);
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
		*quantityName = NumCapletsQuantityName;
		*sigDigits = 4;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = CapletStrengthQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCapletQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Caplets Remaining", @"The caplets remaining for caplet drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCapletQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Caplets per Refill", @"The caplets per refill for caplet drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [CapletDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumCapletsQuantityName;
}


@end
