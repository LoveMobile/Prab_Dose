//
//  SupplementShotDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "SupplementShotDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Shot-related names and keys
static NSString *SupplementShotDosageTypeName = @"supplementShot";
static NSString *NumShotsQuantityName = @"numShots";
static NSString *ShotStrengthQuantityName = @"shotStrength";
static NSString *NumShotsKey = @"numShots";
static NSString *ShotStrengthKey = @"shotStrength";

static float epsilon = 0.0001;

@implementation SupplementShotDrugDosage

- (void)populateQuantities:(float)numShots
			 shotStrength:(float)shotStrength
		 shotStrengthUnit:(NSString*)shotStrengthUnit
{
	// Populate quantities
	DrugDosageQuantity* numShotsQuantity = [[DrugDosageQuantity alloc] init:numShots unit:nil possibleUnits:nil];
	[doseQuantities setObject:numShotsQuantity forKey:NumShotsQuantityName];
	
	NSArray* possibleShotStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitGramsPerMilliliter,
										  DrugDosageUnitMilligramsPerMilliliter,
										  DrugDosageUnitMilligramsPerTeaspoon,
										  DrugDosageUnitMilligramsPerTablespoon,
										  DrugDosageUnitMilligramsPerOunce,
										  nil];
	DrugDosageQuantity* shotStrengthQuantity = [[DrugDosageQuantity alloc] init:shotStrength unit:shotStrengthUnit possibleUnits:possibleShotStrengthUnits];
	[doseQuantities setObject:shotStrengthQuantity forKey:ShotStrengthQuantityName];
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
			[self populateQuantities:0.0f shotStrength:-1.0f shotStrengthUnit:nil];
		}
	}
	return self;			
}

	   - (id)init:(float)numShots
	shotStrength:(float)shotStrength
shotStrengthUnit:(NSString*)shotStrengthUnit
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
		[self populateQuantities:numShots shotStrength:shotStrength shotStrengthUnit:shotStrengthUnit];
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
	float numShots = 0.0f;
	NSString* numShotsUnit = nil;
	float shotStrength = -1.0f;
	NSString* shotStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumShotsKey val:&numShots unit:&numShotsUnit];
	[self readDoseQuantityFromDictionary:dict key:ShotStrengthKey val:&shotStrength unit:&shotStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numShots
		 shotStrength:shotStrength
	 shotStrengthUnit:shotStrengthUnit
			remaining:remaining
			   refill:refill
          refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementShotDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementShotDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumShotsQuantityName key:NumShotsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:ShotStrengthQuantityName key:ShotStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return @"Shot";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementShotDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementShotDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementShotDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numShots:(NSString*)numShots strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numShotsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numShots val:&numShotsVal unit:&unit];
    NSString* singularName = @"shot";
    
    BOOL multiple = NO;
    
    if (numShotsVal > epsilon)
    {
        [doseDescrip appendString:numShots];
        
        NSString* pluralName = @"shots";
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numShotsVal];
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
    
    if (strength && [strength length] > 0)
    {
        [doseDescrip appendFormat:@" (%@", strength];
        
        if (numShotsVal > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", @"per shot"];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numShots = [self getDescriptionForDoseQuantity:NumShotsQuantityName maxNumDecimals:0];
    NSString* strength = [self getDescriptionForDoseQuantity:ShotStrengthQuantityName maxNumDecimals:2];
    return [SupplementShotDrugDosage getDescriptionForDrugDose:drugName numShots:numShots strength:strength];    
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numShots = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumShotsKey value:&numShots modifiedDate:nil perDevice:nil];
    numShots = [DrugDosage getTrimmedValueInStringAsString:numShots maxNumDecimals:0];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:ShotStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [SupplementShotDrugDosage getDescriptionForDrugDose:drugName numShots:numShots strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumShotsQuantityName key:NumShotsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:ShotStrengthQuantityName key:ShotStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumShotsQuantityName] == NSOrderedSame)
		return @"Number of Shots";
	else if ([name caseInsensitiveCompare:ShotStrengthQuantityName] == NSOrderedSame)
		return @"Shot Strength";
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
		*quantityName = NumShotsQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = ShotStrengthQuantityName;
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
	return @"Shots Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Shots per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementShotDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumShotsQuantityName;
}

@end
