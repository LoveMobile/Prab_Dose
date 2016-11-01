//
//  SupplementChewDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "SupplementChewDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Supplement-chew-related names and keys
static NSString *SupplementChewDosageTypeName = @"supplementChew";
static NSString *NumChewsQuantityName = @"numChews";
static NSString *NumChewsKey = @"numChews";

static float epsilon = 0.0001;

@implementation SupplementChewDrugDosage

- (void)populateQuantities:(float)numChews
{
	// Populate quantities
	DrugDosageQuantity* numChewsQuantity = [[DrugDosageQuantity alloc] init:numChews unit:nil possibleUnits:nil];
	[doseQuantities setObject:numChewsQuantity forKey:NumChewsQuantityName];
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
			[self populateQuantities:0.0f];
		}
	}
	return self;			
}

- (id)initWithNumChews:(float)numChews
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
		[self populateQuantities:numChews];
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
	float numChews = 0.0f;
	NSString* numChewsUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumChewsKey val:&numChews unit:&numChewsUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self initWithNumChews:numChews remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementChewDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementChewDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumChewsQuantityName key:NumChewsKey numDecimals:0 alwaysWrite:YES];
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
	return @"Chew";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementChewDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementChewDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementChewDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numChews:(NSString*)numChews
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numChewsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numChews val:&numChewsVal unit:&unit];
    NSString* singularName = @"chew";
    
    BOOL multiple = NO;
    
    if (numChewsVal > epsilon)
    {
        [doseDescrip appendString:numChews];
        
        NSString* pluralName = @"chews";
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numChewsVal];
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
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numChews = [self getDescriptionForDoseQuantity:NumChewsQuantityName maxNumDecimals:0];
    return [SupplementChewDrugDosage getDescriptionForDrugDose:drugName numChews:numChews];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numChews = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumChewsKey value:&numChews modifiedDate:nil perDevice:nil];
    numChews = [DrugDosage getTrimmedValueInStringAsString:numChews maxNumDecimals:1];

    return [SupplementChewDrugDosage getDescriptionForDrugDose:drugName numChews:numChews];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumChewsQuantityName key:NumChewsKey numDecimals:0 alwaysWrite:YES];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumChewsQuantityName] == NSOrderedSame)
		return @"Number of Chews";
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
		*quantityName = NumChewsQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
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
	return @"Chews Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Chews per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementChewDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumChewsQuantityName;
}


@end
