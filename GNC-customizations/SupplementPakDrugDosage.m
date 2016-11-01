//
//  SupplementPakDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "SupplementPakDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// SupplementPak-related names
static NSString *SupplementPakDosageTypeName = @"supplementPak";
static NSString *PaksPerServingQuantityName = @"paksPerServing";
static NSString *PillsPerPakQuantityName = @"pillsPerPak";
static NSString *PaksPerServingKey = @"paksPerServing";
static NSString *PillsPerPakKey = @"pillsPerPak";

static float epsilon = 0.0001;

@implementation SupplementPakDrugDosage

- (void)populateQuantities:(float)paksPerServing
			  pillsPerPak:(float)pillsPerPak
{
	// Populate quantities
	DrugDosageQuantity* paksPerServingQuantity = [[DrugDosageQuantity alloc] init:paksPerServing unit:nil possibleUnits:nil];
	[doseQuantities setObject:paksPerServingQuantity forKey:PaksPerServingQuantityName];
	
	DrugDosageQuantity* pillsPerPakQuantity = [[DrugDosageQuantity alloc] init:pillsPerPak unit:nil possibleUnits:nil];
	[doseQuantities setObject:pillsPerPakQuantity forKey:PillsPerPakQuantityName];	
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
			[self populateQuantities:0.0f pillsPerPak:-1.0f];
		}
	}
	return self;			
}

  - (id)init:(float)paksPerServing
 pillsPerPak:(float)pillsPerPak
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
		[self populateQuantities:paksPerServing pillsPerPak:pillsPerPak];
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
	float paksPerServing = 0.0f;
	NSString* paksPerServingUnit = nil;
	float pillsPerPak = -1.0f;
	NSString* pillsPerPakUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:PaksPerServingKey val:&paksPerServing unit:&paksPerServingUnit];
	[self readDoseQuantityFromDictionary:dict key:PillsPerPakKey val:&pillsPerPak unit:&pillsPerPakUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:paksPerServing pillsPerPak:pillsPerPak remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SupplementPakDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SupplementPakDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:PaksPerServingQuantityName key:PaksPerServingKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:PillsPerPakQuantityName key:PillsPerPakKey numDecimals:0 alwaysWrite:NO];
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
	return @"Pak";
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SupplementPakDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SupplementPakDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SupplementPakDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numPaks:(NSString*)numPaks pillsPerPak:(NSString*)pillsPerPak
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numPaksVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numPaks val:&numPaksVal unit:&unit];
    NSString* singularName = @"pak per serving";

    if (numPaksVal > epsilon)
    {
        [doseDescrip appendString:numPaks];
        
        NSString* pluralName = @"paks per serving";
        
        BOOL multiplePaks = ![DosecastUtil shouldUseSingularForFloat:numPaksVal];
        [doseDescrip appendFormat:@" %@", (multiplePaks ? pluralName : singularName)];
        
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
    
    if (pillsPerPak && [pillsPerPak length] > 0)
    {
        [doseDescrip appendFormat:@" (%@", pillsPerPak];
        
        NSString* pillsPerPakSingularName = @"pill per pak";
        NSString* pillsPerPakPluralName = @"pills per pak";

        float pillsPerPakVal;
        [DrugDosage getQuantityFromString:pillsPerPak val:&pillsPerPakVal unit:&unit];
        
        BOOL multiplePillsPerPak = ![DosecastUtil shouldUseSingularForFloat:pillsPerPakVal];
        [doseDescrip appendFormat:@" %@)", (multiplePillsPerPak ? pillsPerPakPluralName : pillsPerPakSingularName)];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numPaks = [self getDescriptionForDoseQuantity:PaksPerServingQuantityName maxNumDecimals:0];
    NSString* pillsPerPak = [self getDescriptionForDoseQuantity:PillsPerPakQuantityName maxNumDecimals:0];
    return [SupplementPakDrugDosage getDescriptionForDrugDose:drugName numPaks:numPaks pillsPerPak:pillsPerPak];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numPaks = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PaksPerServingKey value:&numPaks modifiedDate:nil perDevice:nil];
    numPaks = [DrugDosage getTrimmedValueInStringAsString:numPaks maxNumDecimals:0];

    NSString* pillsPerPak = nil;
    [Preferences readPreferenceFromDictionary:doseData key:PillsPerPakKey value:&pillsPerPak modifiedDate:nil perDevice:nil];
    pillsPerPak = [DrugDosage getTrimmedValueInStringAsString:pillsPerPak maxNumDecimals:0];

    return [SupplementPakDrugDosage getDescriptionForDrugDose:drugName numPaks:numPaks pillsPerPak:pillsPerPak];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:PaksPerServingQuantityName key:PaksPerServingKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:PillsPerPakQuantityName key:PillsPerPakKey numDecimals:0 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:PaksPerServingQuantityName] == NSOrderedSame)
		return @"Paks Per Serving";
	else if ([name caseInsensitiveCompare:PillsPerPakQuantityName] == NSOrderedSame)
		return @"Pills Per Pak";
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
		*quantityName = PaksPerServingQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = PillsPerPakQuantityName;
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
	return @"Paks Remaining";
}

- (NSString*)getLabelForRefillQuantity
{
	return @"Paks per Refill";
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SupplementPakDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return PaksPerServingQuantityName;
}

@end
