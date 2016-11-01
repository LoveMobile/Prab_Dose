//
//  TabletDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "TabletDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Tablet-related names and keys
static NSString *TabletDosageTypeName = @"tablet";
static NSString *NumTabletsQuantityName = @"numTablets";
static NSString *TabletStrengthQuantityName = @"tabletStrength";
static NSString *NumTabletsKey = @"numTablets";
static NSString *TabletStrengthKey = @"tabletStrength";

static float epsilon = 0.0001;

@implementation TabletDrugDosage

- (NSArray*)getPossibleTabletStrengthUnits
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

- (void)populateQuantities:(float)numTablets
	    tabletStrength:(float)tabletStrength
	tabletStrengthUnit:(NSString*)tabletStrengthUnit
{
	// Populate quantities
	
	DrugDosageQuantity* numTabletsQuantity = [[DrugDosageQuantity alloc] init:numTablets unit:nil possibleUnits:nil];
	[doseQuantities setObject:numTabletsQuantity forKey:NumTabletsQuantityName];
	
	NSArray* possibleTabletStrengthUnits = [self getPossibleTabletStrengthUnits];
	DrugDosageQuantity* tabletStrengthQuantity = [[DrugDosageQuantity alloc] init:tabletStrength unit:tabletStrengthUnit possibleUnits:possibleTabletStrengthUnits];
	[doseQuantities setObject:tabletStrengthQuantity forKey:TabletStrengthQuantityName];
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
			[self populateQuantities:0.0f tabletStrength:-1.0f tabletStrengthUnit:nil];
		}
	}
	return self;			
}

- (id)init:(float)numTabletsPerDose
tabletStrength:(float)tabletStrength
tabletStrengthUnit:(NSString*)tabletStrengthUnit
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
		[self populateQuantities:numTabletsPerDose tabletStrength:tabletStrength tabletStrengthUnit:tabletStrengthUnit];
		
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
	float numTabletsPerDose = 0.0f;
    NSString* numTabletsPerDoseUnit = nil;
	float tabletStrength = -1.0f;
	NSString* tabletStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
	[self readDoseQuantityFromDictionary:dict key:NumTabletsKey val:&numTabletsPerDose unit:&numTabletsPerDoseUnit];
	[self readDoseQuantityFromDictionary:dict key:TabletStrengthKey val:&tabletStrength unit:&tabletStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numTabletsPerDose
       tabletStrength:tabletStrength
   tabletStrengthUnit:tabletStrengthUnit
            remaining:remaining
               refill:refill
     refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[TabletDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:TabletDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:NumTabletsQuantityName key:NumTabletsKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:TabletStrengthQuantityName key:TabletStrengthKey numDecimals:2 alwaysWrite:NO];
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeTablet", @"Dosecast", [DosecastUtil getResourceBundle], @"Tablet", @"The display name for tablet drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [TabletDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:TabletDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [TabletDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numTablets:(NSString*)numTablets strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numTabletsPerDose;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numTablets val:&numTabletsPerDose unit:&unit];
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeTabletNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"tablet", @"The singular name for tablet drug types"]);
    
    BOOL multiple = NO;
    
    if (numTabletsPerDose > epsilon)
    {
        [doseDescrip appendString:numTablets];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeTabletNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"tablets", @"The plural name for tablet drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numTabletsPerDose];
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
        
        if (numTabletsPerDose > epsilon && multiple)
            [doseDescrip appendFormat:@" %@)", NSLocalizedStringWithDefaultValue(@"DrugTypeTabletQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"per tablet", @"The phrase referring to the tablet quantity for dosages"])];
        else
            [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numTablets = [self getDescriptionForDoseQuantity:NumTabletsQuantityName maxNumDecimals:2];
    NSString* strength = [self getDescriptionForDoseQuantity:TabletStrengthQuantityName maxNumDecimals:2];
    return [TabletDrugDosage getDescriptionForDrugDose:drugName numTablets:numTablets strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numTablets = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumTabletsKey value:&numTablets modifiedDate:nil perDevice:nil];
    numTablets = [DrugDosage getTrimmedValueInStringAsString:numTablets maxNumDecimals:2];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:TabletStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];

    return [TabletDrugDosage getDescriptionForDrugDose:drugName numTablets:numTablets strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumTabletsQuantityName key:NumTabletsKey numDecimals:2 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:TabletStrengthQuantityName key:TabletStrengthKey numDecimals:2 alwaysWrite:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumTabletsQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeTabletQuantityTabletsPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Tablets per Dose", @"The tablets per dose quantity for tablet drug types"]);
	else if ([name caseInsensitiveCompare:TabletStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeTabletQuantityTabletStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Tablet Strength", @"The tablet strength quantity for tablet drug types"]);
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
		*quantityName = NumTabletsQuantityName;
		*sigDigits = 4;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = TabletStrengthQuantityName;
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
	return NSLocalizedStringWithDefaultValue(@"DrugTypeTabletQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Tablets Remaining", @"The tablets remaining for tablet drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeTabletQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Tablets per Refill", @"The tablets per refill for tablet drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [TabletDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumTabletsQuantityName;
}


@end
