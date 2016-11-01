//
//  OintmentDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "OintmentDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Ointment-related names and keys
static NSString *OintmentDosageTypeName = @"ointment";
static NSString *OintmentStrengthQuantityName = @"ointmentStrength";
static NSString *OintmentStrengthKey = @"ointmentStrength";

@implementation OintmentDrugDosage

- (void)populateQuantities:(float)ointmentStrength
      ointmentStrengthUnit:(NSString*)ointmentStrengthUnit
{
	// Populate quantities
	NSArray* possibleOintmentStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitPercent,
										  nil];
	DrugDosageQuantity* ointmentStrengthQuantity = [[DrugDosageQuantity alloc] init:ointmentStrength unit:ointmentStrengthUnit possibleUnits:possibleOintmentStrengthUnits];
	[doseQuantities setObject:ointmentStrengthQuantity forKey:OintmentStrengthQuantityName];
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
			[self populateQuantities:-1.0f ointmentStrengthUnit:nil];
		}
	}
	return self;			
}

- (id)initWithOintmentStrength:(float)ointmentStrength
          ointmentStrengthUnit:(NSString*)ointmentStrengthUnit
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
		[self populateQuantities:ointmentStrength ointmentStrengthUnit:ointmentStrengthUnit];
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
	float ointmentStrength = -1.0f;
	NSString* ointmentStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:OintmentStrengthKey val:&ointmentStrength unit:&ointmentStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self initWithOintmentStrength:ointmentStrength ointmentStrengthUnit:ointmentStrengthUnit remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[OintmentDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:OintmentDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:OintmentStrengthQuantityName key:OintmentStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeOintment", @"Dosecast", [DosecastUtil getResourceBundle], @"Ointment", @"The display name for ointment drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [OintmentDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:OintmentDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [OintmentDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    NSString* ointmentTypeName = NSLocalizedStringWithDefaultValue(@"DrugTypeOintment", @"Dosecast", [DosecastUtil getResourceBundle], @"Ointment", @"The display name for ointment drug types"]);

	if (drugName && [drugName length] > 0)
		[doseDescrip appendFormat:@"%@ %@", drugName, [ointmentTypeName lowercaseString]];
	else
		[doseDescrip appendString:ointmentTypeName];

    if (strength && [strength length] > 0)
	{
		[doseDescrip appendFormat:@" (%@)", strength];
	}
	
	return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* strength = [self getDescriptionForDoseQuantity:OintmentStrengthQuantityName maxNumDecimals:2];
    return [OintmentDrugDosage getDescriptionForDrugDose:drugName strength:strength];    
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:OintmentStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];
    
    return [OintmentDrugDosage getDescriptionForDrugDose:drugName strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:OintmentStrengthQuantityName key:OintmentStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:OintmentStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeOintmentQuantityOintmentStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Ointment Strength", @"The ointment strength quantity for ointment drug types"]);
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
		*quantityName = OintmentStrengthQuantityName;
		*sigDigits = 4;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeOintmentQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Applications Remaining", @"The number of applications remaining for ointment drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeOintmentQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Applications per Refill", @"The number of applications per refill for ointment drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [OintmentDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return nil;
}


@end
