//
//  SupplementScoopDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "SupplementScoopDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// SupplementScoop-related names
static NSString *SupplementScoopDosageTypeName = @"supplementScoop";
static NSString *ScoopsPerServingQuantityName = @"scoopsPerServing";
static NSString *ScoopVolumeQuantityName = @"scoopVolume";
static NSString *ScoopsPerServingKey = @"scoopsPerServing";
static NSString *ScoopVolumeKey = @"scoopVolume";

static float epsilon = 0.0001;

@implementation SupplementScoopDrugDosage

- (NSArray*)getPossibleScoopVolumeUnits
{
	return [NSArray arrayWithObjects:
			DrugDosageUnitMilliliters,
			DrugDosageUnitTeaspoons,
			DrugDosageUnitTablespoons,
			DrugDosageUnitOunces,
			DrugDosageUnitGrams,
			nil];		
}

- (void)populateQuantities:(float)scoopsPerServing
			   scoopVolume:(float)scoopVolume
		   scoopVolumeUnit:(NSString*)scoopVolumeUnit
{
	// Populate quantities
	DrugDosageQuantity* scoopsPerServingQuantity = [[DrugDosageQuantity alloc] init:scoopsPerServing unit:nil possibleUnits:nil];
	[doseQuantities setObject:scoopsPerServingQuantity forKey:ScoopsPerServingQuantityName];
	
	NSArray* possibleScoopVolumeUnits = [self getPossibleScoopVolumeUnits];
	
	DrugDosageQuantity* scoopVolumeQuantity = [[DrugDosageQuantity alloc] init:scoopVolume unit:scoopVolumeUnit possibleUnits:possibleScoopVolumeUnits];
	[doseQuantities setObject:scoopVolumeQuantity forKey:ScoopVolumeQuantityName];	
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
			[self populateQuantities:0.0f scoopVolume:-1.0f scoopVolumeUnit:nil];
		}
		if (!remaining)
		{
			NSArray* possibleScoopVolumeUnits = [self getPossibleScoopVolumeUnits];
			[remainingQuantity.possibleUnits setArray:possibleScoopVolumeUnits];
		}
		if (!refill)
		{
			NSArray* possibleScoopVolumeUnits = [self getPossibleScoopVolumeUnits];
			[refillQuantity.possibleUnits setArray:possibleScoopVolumeUnits];
		}
	}
	return self;			
}

	 - (id)init:(float)scoopsPerServing
	scoopVolume:(float)scoopVolume
scoopVolumeUnit:(NSString*)scoopVolumeUnit
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
		[self populateQuantities:scoopsPerServing scoopVolume:scoopVolume scoopVolumeUnit:scoopVolumeUnit];
		
		NSArray* possibleScoopVolumeUnits = [self getPossibleScoopVolumeUnits];
		
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		[remainingQuantity.possibleUnits setArray:possibleScoopVolumeUnits];
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[refillQuantity.possibleUnits setArray:possibleScoopVolumeUnits];				
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
	float scoopsPerServing = 0.0f;
	NSString* scoopsPerServingUnit = nil;
	float scoopVolume = -1.0f;
	NSString* scoopVolumeUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:ScoopsPerServingKey val:&scoopsPerServing unit:&scoopsPerServingUnit];
	[self readDoseQuantityFromDictionary:dict key:ScoopVolumeKey val:&scoopVolume unit:&scoopVolumeUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:scoopsPerServing
		  scoopVolume:scoopVolume
	  scoopVolumeUnit:scoopVolumeUnit
			remaining:remaining
		remainingUnit:remainingUnit
			   refill:refill
		   refillUnit:refillUnit
            refillsRemaining:left];	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementScoopDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementScoopDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:ScoopsPerServingQuantityName key:ScoopsPerServingKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:ScoopVolumeQuantityName key:ScoopVolumeKey numDecimals:1 alwaysWrite:NO];
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
	return @"Scoop";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementScoopDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementScoopDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementScoopDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numScoops:(NSString*)numScoops volume:(NSString*)volume
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numScoopsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numScoops val:&numScoopsVal unit:&unit];
    
    BOOL multiple = NO;
    NSString* singularName = @"scoop per serving";
    
    if (numScoopsVal > epsilon)
    {
        [doseDescrip appendString:numScoops];
        
        NSString* pluralName = @"scoops per serving";
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numScoopsVal];
        [doseDescrip appendFormat:@" %@", (multiple ? pluralName : singularName)];
        
        if (drugName && [drugName length] > 0)
        {
            NSString* drugNamePhraseText = @"%@ of %@";
            [doseDescrip setString:[NSString stringWithFormat:drugNamePhraseText, doseDescrip, drugName]];
        }
    }
    else if (drugName && [drugName length] > 0)
        [doseDescrip appendString:drugName];
    else
        [doseDescrip appendString:[singularName capitalizedString]];
    
    if (volume && [volume length] > 0)
    {
        [doseDescrip appendFormat:@" (%@", volume];
        
        if (numScoopsVal > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", @"per scoop"];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numScoops = [self getDescriptionForDoseQuantity:ScoopsPerServingQuantityName maxNumDecimals:0];
    NSString* volume = [self getDescriptionForDoseQuantity:ScoopVolumeQuantityName maxNumDecimals:1];
	return [SupplementScoopDrugDosage getDescriptionForDrugDose:drugName numScoops:numScoops volume:volume];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numScoops = nil;
    [Preferences readPreferenceFromDictionary:doseData key:ScoopsPerServingKey value:&numScoops modifiedDate:nil perDevice:nil];
    numScoops = [DrugDosage getTrimmedValueInStringAsString:numScoops maxNumDecimals:0];

    NSString* volume = nil;
    [Preferences readPreferenceFromDictionary:doseData key:ScoopVolumeKey value:&volume modifiedDate:nil perDevice:nil];
    volume = [DrugDosage getTrimmedValueInStringAsString:volume maxNumDecimals:1];

	return [SupplementScoopDrugDosage getDescriptionForDrugDose:drugName numScoops:numScoops volume:volume];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:ScoopsPerServingQuantityName key:ScoopsPerServingKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:ScoopVolumeQuantityName key:ScoopVolumeKey numDecimals:1 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:ScoopsPerServingQuantityName] == NSOrderedSame)
		return @"Scoops Per Serving";
	else if ([name caseInsensitiveCompare:ScoopVolumeQuantityName] == NSOrderedSame)
		return @"Scoop Volume";
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
		*quantityName = ScoopsPerServingQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = ScoopVolumeQuantityName;
		*sigDigits = 4;
		*numDecimals = 1;
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
	return @"Volume Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Volume per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementScoopDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return ScoopVolumeQuantityName;
}

@end
