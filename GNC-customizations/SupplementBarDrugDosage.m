//
//  SupplementBarDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "SupplementBarDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// SupplementBar-related names
static NSString *SupplementBarDosageTypeName = @"supplementBar";
static NSString *NumberOfBarsQuantityName = @"numBars";
static NSString *BarVolumeQuantityName = @"barVolume";
static NSString *NumberOfBarsKey = @"numBars";
static NSString *BarVolumeKey = @"barVolume";

static float epsilon = 0.0001;

@implementation SupplementBarDrugDosage

- (void)populateQuantities:(float)numBars
			   barVolume:(float)barVolume
		   barVolumeUnit:(NSString*)barVolumeUnit
{
	// Populate quantities
	DrugDosageQuantity* numBarsQuantity = [[DrugDosageQuantity alloc] init:numBars unit:nil possibleUnits:nil];
	[doseQuantities setObject:numBarsQuantity forKey:NumberOfBarsQuantityName];
	
	NSArray* possibleBarVolumeUnits = [NSArray arrayWithObjects:
										 DrugDosageUnitMilliliters,
										 DrugDosageUnitTeaspoons,
										 DrugDosageUnitTablespoons,
										 DrugDosageUnitOunces,
										 nil];		
	DrugDosageQuantity* barVolumeQuantity = [[DrugDosageQuantity alloc] init:barVolume unit:barVolumeUnit possibleUnits:possibleBarVolumeUnits];
	[doseQuantities setObject:barVolumeQuantity forKey:BarVolumeQuantityName];	
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
			[self populateQuantities:0.0f barVolume:-1.0f barVolumeUnit:nil];
		}
	}
	return self;			
}

	 - (id)init:(float)numBars
	  barVolume:(float)barVolume
  barVolumeUnit:(NSString*)barVolumeUnit
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
		[self populateQuantities:numBars barVolume:barVolume barVolumeUnit:barVolumeUnit];
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
	float numBars = 0.0f;
	NSString* numBarsUnit = nil;
	float barVolume = -1.0f;
	NSString* barVolumeUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumberOfBarsKey val:&numBars unit:&numBarsUnit];
	[self readDoseQuantityFromDictionary:dict key:BarVolumeKey val:&barVolume unit:&barVolumeUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numBars barVolume:barVolume barVolumeUnit:barVolumeUnit remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementBarDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementBarDosageTypeName modifiedDate:nil perDevice:NO];

	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumberOfBarsQuantityName key:NumberOfBarsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:BarVolumeQuantityName key:BarVolumeKey numDecimals:1 alwaysWrite:NO];
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
	return @"Bar";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementBarDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementBarDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementBarDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numBars:(NSString*)numBars volume:(NSString*)volume
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numBarsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numBars val:&numBarsVal unit:&unit];
    NSString* singularName = @"bar";
    
    BOOL multiple = NO;
    
    if (numBarsVal > epsilon)
    {
        [doseDescrip appendString:numBars];
        
        NSString* pluralName = @"bars";
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numBarsVal];
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
        
        if (numBarsVal > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", @"per bar"];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numBars = [self getDescriptionForDoseQuantity:NumberOfBarsQuantityName maxNumDecimals:0];
    NSString* volume = [self getDescriptionForDoseQuantity:BarVolumeQuantityName maxNumDecimals:1];
    return [SupplementBarDrugDosage getDescriptionForDrugDose:drugName numBars:numBars volume:volume];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numBars = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumberOfBarsKey value:&numBars modifiedDate:nil perDevice:nil];
    numBars = [DrugDosage getTrimmedValueInStringAsString:numBars maxNumDecimals:0];

    NSString* volume = nil;
    [Preferences readPreferenceFromDictionary:doseData key:BarVolumeKey value:&volume modifiedDate:nil perDevice:nil];
    volume = [DrugDosage getTrimmedValueInStringAsString:volume maxNumDecimals:1];

    return [SupplementBarDrugDosage getDescriptionForDrugDose:drugName numBars:numBars volume:volume];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumberOfBarsQuantityName key:NumberOfBarsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:BarVolumeQuantityName key:BarVolumeKey numDecimals:1 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumberOfBarsQuantityName] == NSOrderedSame)
		return @"Number of Bars";
	else if ([name caseInsensitiveCompare:BarVolumeQuantityName] == NSOrderedSame)
		return @"Bar Volume";
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
		*quantityName = NumberOfBarsQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = BarVolumeQuantityName;
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
	return @"Bars Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Bars per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementBarDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumberOfBarsQuantityName;
}

@end
