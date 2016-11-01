//
//  PatchDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "PatchDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Patch-related names and keys
static NSString *PatchDosageTypeName = @"patch";
static NSString *NumPatchesQuantityName = @"numPatches";
static NSString *PatchStrengthQuantityName = @"patchStrength";
static NSString *NumPatchesKey = @"numPatches";
static NSString *PatchStrengthKey = @"patchStrength";

static float epsilon = 0.0001;

@implementation PatchDrugDosage

- (void)populateQuantities:(float)numPatches
			 patchStrength:(float)patchStrength
		 patchStrengthUnit:(NSString*)patchStrengthUnit;

{
	// Populate quantities
	DrugDosageQuantity* numPatchesQuantity = [[DrugDosageQuantity alloc] init:numPatches unit:nil possibleUnits:nil];
	[doseQuantities setObject:numPatchesQuantity forKey:NumPatchesQuantityName];
	
	NSArray* possiblePatchStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitMilligramsPerHour,
										  DrugDosageUnitMicrogramsPerHour,
										  DrugDosageUnitMilligramsPer24Hours,
										  DrugDosageUnitMilligrams,
										  nil];
	DrugDosageQuantity* patchStrengthQuantity = [[DrugDosageQuantity alloc] init:patchStrength unit:patchStrengthUnit possibleUnits:possiblePatchStrengthUnits];
	[doseQuantities setObject:patchStrengthQuantity forKey:PatchStrengthQuantityName];
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
			[self populateQuantities:0.0f patchStrength:-1.0f patchStrengthUnit:nil];
		}
	}
	return self;			
}

	   - (id)init:(float)numPatches
	patchStrength:(float)patchStrength
patchStrengthUnit:(NSString*)patchStrengthUnit
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
		[self populateQuantities:numPatches patchStrength:patchStrength patchStrengthUnit:patchStrengthUnit];
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
	float numPatches = 0.0f;
	NSString* numPatchesUnit = nil;
	float patchStrength = -1.0f;
	NSString* patchStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumPatchesKey val:&numPatches unit:&numPatchesUnit];
	[self readDoseQuantityFromDictionary:dict key:PatchStrengthKey val:&patchStrength unit:&patchStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numPatches patchStrength:patchStrength patchStrengthUnit:patchStrengthUnit remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[PatchDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:PatchDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumPatchesQuantityName key:NumPatchesKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:PatchStrengthQuantityName key:PatchStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypePatch", @"Dosecast", [DosecastUtil getResourceBundle], @"Patch", @"The display name for patch drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [PatchDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:PatchDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [PatchDrugDosage getFileTypeName];
}


// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numPatches:(NSString*)numPatches strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numPatchesVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numPatches val:&numPatchesVal unit:&unit];
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypePatchNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"patch", @"The singular name for patch drug types"]);
    
    BOOL multiple = NO;
    
    if (numPatchesVal > epsilon)
    {
        [doseDescrip appendString:numPatches];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypePatchNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"patches", @"The plural name for patch drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numPatchesVal];
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
        
        if (numPatchesVal > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", NSLocalizedStringWithDefaultValue(@"DrugTypePatchQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"per patch", @"The phrase referring to the patch quantity for dosages"])];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{	
	NSString* numPatches = [self getDescriptionForDoseQuantity:NumPatchesQuantityName maxNumDecimals:0];
    NSString* strength = [self getDescriptionForDoseQuantity:PatchStrengthQuantityName maxNumDecimals:2];
	return [PatchDrugDosage getDescriptionForDrugDose:drugName numPatches:numPatches strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numPatches = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumPatchesKey value:&numPatches modifiedDate:nil perDevice:nil];
    numPatches = [DrugDosage getTrimmedValueInStringAsString:numPatches maxNumDecimals:0];
    
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PatchStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [PatchDrugDosage getDescriptionForDrugDose:drugName numPatches:numPatches strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumPatchesQuantityName key:NumPatchesKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:PatchStrengthQuantityName key:PatchStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumPatchesQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePatchQuantityPatchesPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Patches per Dose", @"The patches per dose quantity for patch drug types"]);
	else if ([name caseInsensitiveCompare:PatchStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypePatchQuantityPatchStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Patch Strength", @"The patch strength quantity for patch drug types"]);
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
		*quantityName = NumPatchesQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = PatchStrengthQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypePatchQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Patches Remaining", @"The number of patches remaining for patch drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypePatchQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Patches per Refill", @"The number of patches per refill for patch drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [PatchDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumPatchesQuantityName;
}


@end
