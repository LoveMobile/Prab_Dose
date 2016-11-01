//
//  DropDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "DropDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Drop-related names and keys
static NSString *DropDosageTypeName = @"drop";
static NSString *NumDropsQuantityName = @"numDrops";
static NSString *DropStrengthQuantityName = @"dropStrength";
static NSString *DropLocationPicklistName = @"dropLocation";
static NSString *NumDropsKey = @"numDrops";
static NSString *DropStrengthKey = @"dropStrength";
static NSString *DropLocationKey = @"dropLocation";

// Drop Dosage Location
static NSString *DropDosageLocationMouthName = @"mouth";
static NSString *DropDosageLocationLeftEyeName = @"leftEye";
static NSString *DropDosageLocationRightEyeName = @"rightEye";
static NSString *DropDosageLocationEachEyeName = @"eachEye";
static NSString *DropDosageLocationLeftEarName = @"leftEar";
static NSString *DropDosageLocationRightEarName = @"rightEar";
static NSString *DropDosageLocationEachEarName = @"eachEar";
static NSString *DropDosageLocationScalpName = @"scalp";
static NSString *DropDosageLocationLeftNostrilName = @"leftNostril";
static NSString *DropDosageLocationRightNostrilName = @"rightNostril";
static NSString *DropDosageLocationEachNostrilName = @"eachNostril";

static float epsilon = 0.0001;

@implementation DropDrugDosage

- (void)populateQuantities:(float)numDrops
			  dropStrength:(float)dropStrength
          dropStrengthUnit:(NSString*)dropStrengthUnit
{
	// Populate quantities
	DrugDosageQuantity* numDropsQuantity = [[DrugDosageQuantity alloc] init:numDrops unit:nil possibleUnits:nil];
	[doseQuantities setObject:numDropsQuantity forKey:NumDropsQuantityName];
	
	NSArray* possibleDropStrengthUnits = [NSArray arrayWithObjects:DrugDosageUnitPercent,
                                               DrugDosageUnitIU,
											   nil];
	DrugDosageQuantity* dropStrengthQuantity = [[DrugDosageQuantity alloc] init:dropStrength unit:dropStrengthUnit possibleUnits:possibleDropStrengthUnits];
	[doseQuantities setObject:dropStrengthQuantity forKey:DropStrengthQuantityName];
}

- (void)populatePicklistOptions
{
	NSMutableArray* options = [[NSMutableArray alloc] init];

	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationMouth", @"Dosecast", [DosecastUtil getResourceBundle], @"Mouth", @"The mouth location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Left eye", @"The left eye location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Right eye", @"The right eye location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Each eye", @"The each eye location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Left ear", @"The left ear location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Right ear", @"The right ear location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Each ear", @"The each ear location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationScalp", @"Dosecast", [DosecastUtil getResourceBundle], @"Scalp", @"The scalp location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Left nostril", @"The left nostril location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationRightNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Right nostril", @"The right nostril location for drugs"])];
	[options addObject:NSLocalizedStringWithDefaultValue(@"DrugLocationEachNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Each nostril", @"The each nostril location for drugs"])];
	[dosePicklistOptions setObject:options forKey:DropLocationPicklistName];
}

- (void)populatePicklistValues:(NSString*)dropLocation
{
	[dosePicklistValues setObject:dropLocation forKey:DropLocationPicklistName];
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
			[self populateQuantities:0.0f dropStrength:-1.0f dropStrengthUnit:nil];
		}
		if (!picklistOptions)
		{
			// Populate defaults
			[self populatePicklistOptions];
		}
		if (!picklistValues)
		{
			// Populate defaults
			[self populatePicklistValues:@""];
		}
	}
	return self;			
}

  - (id)init:(float)numDrops
dropStrength:(float)dropStrength
dropStrengthUnit:(NSString*)dropStrengthUnit
dropLocation:(NSString*)dropLocation
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
		[self populateQuantities:numDrops dropStrength:dropStrength dropStrengthUnit:dropStrengthUnit];
		[self populatePicklistOptions];
		[self populatePicklistValues:dropLocation];
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

+ (NSString*) getDropLocationFromFileRead:(NSString*)dropLocationStr
{
    NSMutableString* dropLocation = [NSMutableString stringWithString:@""];
    if (dropLocationStr && [dropLocationStr length] > 0)
    {
        if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationMouthName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationMouth", @"Dosecast", [DosecastUtil getResourceBundle], @"Mouth", @"The mouth location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationLeftEyeName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Left eye", @"The left eye location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationRightEyeName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Right eye", @"The right eye location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationEachEyeName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Each eye", @"The each eye location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationLeftEarName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Left ear", @"The left ear location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationRightEarName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Right ear", @"The right ear location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationEachEarName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Each ear", @"The each ear location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationScalpName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationScalp", @"Dosecast", [DosecastUtil getResourceBundle], @"Scalp", @"The scalp location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationLeftNostrilName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Left nostril", @"The left nostril location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationRightNostrilName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Right nostril", @"The right nostril location for drugs"])];
        else if ([dropLocationStr caseInsensitiveCompare:DropDosageLocationEachNostrilName] == NSOrderedSame)
            [dropLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Each nostril", @"The each nostril location for drugs"])];
        else
            [dropLocation setString:@""];
    }
    return dropLocation;
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{
	float numDrops = 0.0f;
	NSString* numDropsUnit = nil;
	float dropStrength = -1.0f;
	NSString* dropStrengthUnit = nil;
	NSMutableString* dropLocation = [NSMutableString stringWithString:@""];
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
		
	[self readDoseQuantityFromDictionary:dict key:NumDropsKey val:&numDrops unit:&numDropsUnit];
	[self readDoseQuantityFromDictionary:dict key:DropStrengthKey val:&dropStrength unit:&dropStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    // Get the drop location
    NSString* dropLocationStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:DropLocationKey value:&dropLocationStr modifiedDate:nil perDevice:nil];
    [dropLocation setString:[DropDrugDosage getDropLocationFromFileRead:dropLocationStr]];
    
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
		
	return [self init:numDrops
		 dropStrength:dropStrength
     dropStrengthUnit:dropStrengthUnit
		 dropLocation:dropLocation
			remaining:remaining
			   refill:refill
          refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[DropDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
								  withDosePicklistOptions:[dosePicklistOptions mutableCopyWithZone:zone]
								   withDosePicklistValues:[dosePicklistValues mutableCopyWithZone:zone]
                                       withDoseTextValues:[doseTextValues mutableCopyWithZone:zone]
									withRemainingQuantity:[remainingQuantity mutableCopyWithZone:zone]
									   withRefillQuantity:[refillQuantity mutableCopyWithZone:zone]
                                          withRefillsRemaining:[self getRefillsRemaining]];
}

- (NSString*) getDropLocationForFileWrite
{
    NSString* dropLocationVal = [self getValueForDosePicklist:DropLocationPicklistName];
	if (!dropLocationVal)
		dropLocationVal = @"";
    
	NSString* mouthStr = NSLocalizedStringWithDefaultValue(@"DrugLocationMouth", @"Dosecast", [DosecastUtil getResourceBundle], @"Mouth", @"The mouth location for drugs"]);
	NSString* leftEyeStr = NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Left eye", @"The left eye location for drugs"]);
	NSString* rightEyeStr = NSLocalizedStringWithDefaultValue(@"DrugLocationRightEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Right eye", @"The right eye location for drugs"]);
	NSString* eachEyeStr = NSLocalizedStringWithDefaultValue(@"DrugLocationEachEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Each eye", @"The each eye location for drugs"]);
	NSString* leftEarStr = NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Left ear", @"The left ear location for drugs"]);
	NSString* rightEarStr = NSLocalizedStringWithDefaultValue(@"DrugLocationRightEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Right ear", @"The right ear location for drugs"]);
	NSString* eachEarStr = NSLocalizedStringWithDefaultValue(@"DrugLocationEachEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Each ear", @"The each ear location for drugs"]);
    NSString* scalpStr = NSLocalizedStringWithDefaultValue(@"DrugLocationScalp", @"Dosecast", [DosecastUtil getResourceBundle], @"Scalp", @"The scalp location for drugs"]);
	NSString* leftNostrilStr = NSLocalizedStringWithDefaultValue(@"DrugLocationLeftNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Left nostril", @"The left nostril location for drugs"]);
	NSString* rightNostrilStr = NSLocalizedStringWithDefaultValue(@"DrugLocationRightNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Right nostril", @"The right nostril location for drugs"]);
	NSString* eachNostrilStr = NSLocalizedStringWithDefaultValue(@"DrugLocationEachNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Each nostril", @"The each nostril location for drugs"]);
    
	NSString* dropLocationStr = nil;
	if ([dropLocationVal caseInsensitiveCompare:mouthStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationMouthName;
	else if ([dropLocationVal caseInsensitiveCompare:leftEyeStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationLeftEyeName;
	else if ([dropLocationVal caseInsensitiveCompare:rightEyeStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationRightEyeName;
	else if ([dropLocationVal caseInsensitiveCompare:eachEyeStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationEachEyeName;
	else if ([dropLocationVal caseInsensitiveCompare:leftEarStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationLeftEarName;
	else if ([dropLocationVal caseInsensitiveCompare:rightEarStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationRightEarName;
	else if ([dropLocationVal caseInsensitiveCompare:eachEarStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationEachEarName;
	else if ([dropLocationVal caseInsensitiveCompare:scalpStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationScalpName;
	else if ([dropLocationVal caseInsensitiveCompare:leftNostrilStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationLeftNostrilName;
	else if ([dropLocationVal caseInsensitiveCompare:rightNostrilStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationRightNostrilName;
	else if ([dropLocationVal caseInsensitiveCompare:eachNostrilStr] == NSOrderedSame)
		dropLocationStr = DropDosageLocationEachNostrilName;
	else
		dropLocationStr = @"";
    
    return dropLocationStr;
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:DropDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		

	[self populateDictionaryForDoseQuantity:dict quantityName:NumDropsQuantityName key:NumDropsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:DropStrengthQuantityName key:DropStrengthKey numDecimals:3 alwaysWrite:NO];
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:0];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:0];
    
    [Preferences populatePreferenceInDictionary:dict key:DropLocationKey value:[self getDropLocationForFileWrite] modifiedDate:nil perDevice:NO];
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeDrop", @"Dosecast", [DosecastUtil getResourceBundle], @"Drop", @"The display name for drop drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [DropDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:DropDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [DropDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numDrops:(NSString*)numDrops location:(NSString*)location strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numDropsVal;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numDrops val:&numDropsVal unit:&unit];
    
    BOOL multiple = NO;
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeDropNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"drop", @"The singular name for drop drug types"]);
    
    if (numDropsVal > epsilon)
    {
        [doseDescrip appendString:numDrops];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeDropNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"drops", @"The plural name for drop drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numDropsVal];
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
    
    if (location && [location length] > 0)
    {
        NSString* locationPhraseText = nil;
        if ([location caseInsensitiveCompare:NSLocalizedStringWithDefaultValue(@"DrugLocationScalp", @"Dosecast", [DosecastUtil getResourceBundle], @"Scalp", @"The scalp location for drugs"])] == NSOrderedSame)
            locationPhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageLocationOnPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ on %@", @"The phrase referring to the location for dosages"]);
        else
            locationPhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageLocationInPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ in %@", @"The phrase referring to the location for dosages"]);
        
        [doseDescrip setString:[NSString stringWithFormat:locationPhraseText, doseDescrip, [location lowercaseString]]];
    }

    if (strength && [strength length] > 0)
    {
        [doseDescrip appendFormat:@" (%@", strength];
        
        if (multiple)
        {
            NSString* quantityPhraseText = NSLocalizedStringWithDefaultValue(@"DrugDosageQuantityPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ per %@", @"The phrase referring to the quantity for dosages"]);
            [doseDescrip setString:[NSString stringWithFormat:quantityPhraseText, doseDescrip, singularName]];
        }
        [doseDescrip appendString:@")"];
    }
    
    return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
    NSString* numDrops = [self getDescriptionForDoseQuantity:NumDropsQuantityName maxNumDecimals:0];
    NSString* location = [self getValueForDosePicklist:DropLocationPicklistName];
    NSString* strength = [self getDescriptionForDoseQuantity:DropStrengthQuantityName maxNumDecimals:3];
    return [DropDrugDosage getDescriptionForDrugDose:drugName numDrops:numDrops location:location strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numDrops = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumDropsKey value:&numDrops modifiedDate:nil perDevice:nil];
    numDrops = [DrugDosage getTrimmedValueInStringAsString:numDrops maxNumDecimals:0];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DropStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:3];
    
    NSString* location = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DropLocationKey value:&location modifiedDate:nil perDevice:nil];
    location = [DropDrugDosage getDropLocationFromFileRead:location];
    
    return [DropDrugDosage getDescriptionForDrugDose:drugName numDrops:numDrops location:location strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
    [self populateDictionaryForDoseQuantity:dict quantityName:NumDropsQuantityName key:NumDropsKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:DropStrengthQuantityName key:DropStrengthKey numDecimals:3 alwaysWrite:NO];
    [Preferences populatePreferenceInDictionary:dict key:DropLocationKey value:[self getDropLocationForFileWrite] modifiedDate:nil perDevice:NO];

    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumDropsQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDropQuantityDropsPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Drops per Dose", @"The drops per dose quantity for drop drug types"]);
	else if ([name caseInsensitiveCompare:DropStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDropQuantityDropStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Drop Strength", @"The drop strength quantity for drop drug types"]);
	else
		return nil;
}

// Returns the label for the given picklist
- (NSString*)getLabelForDosePicklist:(NSString*)name
{
	if ([name caseInsensitiveCompare:DropLocationPicklistName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDropPicklistDropLocation", @"Dosecast", [DosecastUtil getResourceBundle], @"Drop Location", @"The drop location picklist for drop drug types"]);
	else
		return nil;
}

// Returns the input type for the given input number
- (DrugDosageInputType) getDoseInputTypeForInput:(int)inputNum
{
	if (inputNum == 2)
		return DrugDosageInputTypePicklist;
	else
		return DrugDosageInputTypeQuantity;
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
		*quantityName = NumDropsQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = DropStrengthQuantityName;
		*sigDigits = 6;
		*numDecimals = 3;
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

// Returns all the UI settings for the picklist with the given input number
- (BOOL) getDosePicklistUISettingsForInput:(int)inputNum
						  picklistName:(NSString**)picklistName
						   displayNone:(BOOL*)displayNone
{
	if (inputNum == 2)
	{
		*picklistName = DropLocationPicklistName;
		*displayNone = YES;
		return YES;
	}
	else
		return NO;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeDropQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Drops Remaining", @"The number of drops remaining for drop drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeDropQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Drops per Refill", @"The number of drops per refill for drop drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [DropDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumDropsQuantityName;
}

@end
