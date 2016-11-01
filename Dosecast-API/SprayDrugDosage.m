//
//  SprayDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


#import "SprayDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Spray-related names and keys
static NSString *SprayDosageTypeName = @"spray";

static NSString *NumSpraysQuantityName = @"numSprays";
static NSString *SprayStrengthQuantityName = @"sprayStrength";
static NSString *NumSpraysKey = @"numSprays";
static NSString *SprayStrengthKey = @"sprayStrength";
static NSString *SprayLocationPicklistName = @"sprayLocation";
static NSString *SprayLocationKey = @"sprayLocation";

// Spray Dosage Location
static NSString *SprayDosageLocationMouthName = @"mouth";
static NSString *SprayDosageLocationLeftEyeName = @"leftEye";
static NSString *SprayDosageLocationRightEyeName = @"rightEye";
static NSString *SprayDosageLocationEachEyeName = @"eachEye";
static NSString *SprayDosageLocationLeftEarName = @"leftEar";
static NSString *SprayDosageLocationRightEarName = @"rightEar";
static NSString *SprayDosageLocationEachEarName = @"eachEar";
static NSString *SprayDosageLocationScalpName = @"scalp";
static NSString *SprayDosageLocationLeftNostrilName = @"leftNostril";
static NSString *SprayDosageLocationRightNostrilName = @"rightNostril";
static NSString *SprayDosageLocationEachNostrilName = @"eachNostril";

static float epsilon = 0.0001;

@implementation SprayDrugDosage

 - (void)populateQuantities:(float)numSpraysPerDose
			  sprayStrength:(float)sprayStrength
		  sprayStrengthUnit:(NSString*)sprayStrengthUnit
{
	// Populate quantities
	DrugDosageQuantity* numSpraysPerDoseQuantity = [[DrugDosageQuantity alloc] init:numSpraysPerDose unit:nil possibleUnits:nil];
	[doseQuantities setObject:numSpraysPerDoseQuantity forKey:NumSpraysQuantityName];
	
	NSArray* possibleSprayStrengthUnits = [NSArray arrayWithObjects:
										  DrugDosageUnitMilligrams,
										  DrugDosageUnitMicrograms,
										  DrugDosageUnitMilliliters,
										  nil];
	DrugDosageQuantity* sprayStrengthQuantity = [[DrugDosageQuantity alloc] init:sprayStrength unit:sprayStrengthUnit possibleUnits:possibleSprayStrengthUnits];
	[doseQuantities setObject:sprayStrengthQuantity forKey:SprayStrengthQuantityName];
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
	[dosePicklistOptions setObject:options forKey:SprayLocationPicklistName];
}

- (void)populatePicklistValues:(NSString*)sprayLocation
{
	[dosePicklistValues setObject:sprayLocation forKey:SprayLocationPicklistName];
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
			[self populateQuantities:0.0f sprayStrength:-1.0f sprayStrengthUnit:nil];
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

        - (id)init:(float)numSpraysPerDose
     sprayStrength:(float)sprayStrength
sprayStrengthUnit:(NSString*)sprayStrengthUnit
     sprayLocation:(NSString*)sprayLocation
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
		[self populateQuantities:numSpraysPerDose sprayStrength:sprayStrength sprayStrengthUnit:sprayStrengthUnit];
        [self populatePicklistOptions];
        [self populatePicklistValues:sprayLocation];
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

+ (NSString*) getSprayLocationFromFileRead:(NSString*)sprayLocationStr
{
    NSMutableString* sprayLocation = [NSMutableString stringWithString:@""];
    if (sprayLocationStr && [sprayLocationStr length] > 0)
    {
        if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationMouthName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationMouth", @"Dosecast", [DosecastUtil getResourceBundle], @"Mouth", @"The mouth location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationLeftEyeName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Left eye", @"The left eye location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationRightEyeName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Right eye", @"The right eye location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationEachEyeName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEye", @"Dosecast", [DosecastUtil getResourceBundle], @"Each eye", @"The each eye location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationLeftEarName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Left ear", @"The left ear location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationRightEarName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Right ear", @"The right ear location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationEachEarName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachEar", @"Dosecast", [DosecastUtil getResourceBundle], @"Each ear", @"The each ear location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationScalpName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationScalp", @"Dosecast", [DosecastUtil getResourceBundle], @"Scalp", @"The scalp location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationLeftNostrilName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationLeftNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Left nostril", @"The left nostril location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationRightNostrilName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationRightNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Right nostril", @"The right nostril location for drugs"])];
        else if ([sprayLocationStr caseInsensitiveCompare:SprayDosageLocationEachNostrilName] == NSOrderedSame)
            [sprayLocation setString:NSLocalizedStringWithDefaultValue(@"DrugLocationEachNostril", @"Dosecast", [DosecastUtil getResourceBundle], @"Each nostril", @"The each nostril location for drugs"])];
        else
            [sprayLocation setString:@""];
    }
    return sprayLocation;
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{
	float numSpraysPerDose = 0.0f;
	NSString* numSpraysPerDoseUnit = nil;
    NSMutableString* sprayLocation = [NSMutableString stringWithString:@""];
	float sprayStrength = -1.0f;
	NSString* sprayStrengthUnit = nil;
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
	
    
    [self readDoseQuantityFromDictionary:dict key:NumSpraysKey val:&numSpraysPerDose unit:&numSpraysPerDoseUnit];
	[self readDoseQuantityFromDictionary:dict key:SprayStrengthKey val:&sprayStrength unit:&sprayStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];

    // Get the spray location
    NSString* sprayLocationStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:SprayLocationKey value:&sprayLocationStr modifiedDate:nil perDevice:nil];
    [sprayLocation setString:[SprayDrugDosage getSprayLocationFromFileRead:sprayLocationStr]];
    
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:numSpraysPerDose sprayStrength:sprayStrength sprayStrengthUnit:sprayStrengthUnit sprayLocation:sprayLocation remaining:remaining refill:refill refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[SprayDrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
								   withDosePicklistOptions:[dosePicklistOptions mutableCopyWithZone:zone]
									withDosePicklistValues:[dosePicklistValues mutableCopyWithZone:zone]
                                        withDoseTextValues:[doseTextValues mutableCopyWithZone:zone]
									 withRemainingQuantity:[remainingQuantity mutableCopyWithZone:zone]
										withRefillQuantity:[refillQuantity mutableCopyWithZone:zone]
                                           withRefillsRemaining:[self getRefillsRemaining]];
}

- (NSString*) getSprayLocationForFileWrite
{
    NSString* sprayLocationVal = [self getValueForDosePicklist:SprayLocationPicklistName];
	if (!sprayLocationVal)
		sprayLocationVal = @"";
    
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
    
	NSString* sprayLocationStr = nil;
	if ([sprayLocationVal caseInsensitiveCompare:mouthStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationMouthName;
	else if ([sprayLocationVal caseInsensitiveCompare:leftEyeStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationLeftEyeName;
	else if ([sprayLocationVal caseInsensitiveCompare:rightEyeStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationRightEyeName;
	else if ([sprayLocationVal caseInsensitiveCompare:eachEyeStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationEachEyeName;
	else if ([sprayLocationVal caseInsensitiveCompare:leftEarStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationLeftEarName;
	else if ([sprayLocationVal caseInsensitiveCompare:rightEarStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationRightEarName;
	else if ([sprayLocationVal caseInsensitiveCompare:eachEarStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationEachEarName;
	else if ([sprayLocationVal caseInsensitiveCompare:scalpStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationScalpName;
	else if ([sprayLocationVal caseInsensitiveCompare:leftNostrilStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationLeftNostrilName;
	else if ([sprayLocationVal caseInsensitiveCompare:rightNostrilStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationRightNostrilName;
	else if ([sprayLocationVal caseInsensitiveCompare:eachNostrilStr] == NSOrderedSame)
		sprayLocationStr = SprayDosageLocationEachNostrilName;
	else
		sprayLocationStr = @"";

    return sprayLocationStr;
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
	// Set the type of dosage
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:SprayDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	    
	[self populateDictionaryForDoseQuantity:dict quantityName:NumSpraysQuantityName key:NumSpraysKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:SprayStrengthQuantityName key:SprayStrengthKey numDecimals:3 alwaysWrite:NO];
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:0];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:0];

    [Preferences populatePreferenceInDictionary:dict key:SprayLocationKey value:[self getSprayLocationForFileWrite] modifiedDate:nil perDevice:NO];
    
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeSpray", @"Dosecast", [DosecastUtil getResourceBundle], @"Nasal spray", @"The display name for spray drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return [SprayDrugDosage getTypeName];
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:SprayDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [SprayDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName numSprays:(NSString*)numSprays location:(NSString*)location strength:(NSString*)strength
{
    NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
    
    float numSpraysPerDose;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:numSprays val:&numSpraysPerDose unit:&unit];
    NSString* singularName = NSLocalizedStringWithDefaultValue(@"DrugTypeSprayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"spray", @"The singular name for spray drug types"]);
    
    BOOL multiple = NO;
    
    if (numSpraysPerDose > epsilon)
    {
        [doseDescrip appendString:numSprays];
        
        NSString* pluralName = NSLocalizedStringWithDefaultValue(@"DrugTypeSprayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"sprays", @"The plural name for spray drug types"]);
        
        multiple = ![DosecastUtil shouldUseSingularForFloat:numSpraysPerDose];
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
    NSString* numSprays = [self getDescriptionForDoseQuantity:NumSpraysQuantityName maxNumDecimals:0];
    NSString* location = [self getValueForDosePicklist:SprayLocationPicklistName];
    NSString* strength = [self getDescriptionForDoseQuantity:SprayStrengthQuantityName maxNumDecimals:3];
    return [SprayDrugDosage getDescriptionForDrugDose:drugName numSprays:numSprays location:location strength:strength];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* numSprays = nil;
    [Preferences readPreferenceFromDictionary:doseData key:NumSpraysKey value:&numSprays modifiedDate:nil perDevice:nil];
    numSprays = [DrugDosage getTrimmedValueInStringAsString:numSprays maxNumDecimals:0];

    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:SprayStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:3];

    NSString* location = nil;
    [Preferences readPreferenceFromDictionary:doseData key:SprayLocationKey value:&location modifiedDate:nil perDevice:nil];
    location = [SprayDrugDosage getSprayLocationFromFileRead:location];

    return [SprayDrugDosage getDescriptionForDrugDose:drugName numSprays:numSprays location:location strength:strength];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
    [self populateDictionaryForDoseQuantity:dict quantityName:NumSpraysQuantityName key:NumSpraysKey numDecimals:0 alwaysWrite:YES];
	[self populateDictionaryForDoseQuantity:dict quantityName:SprayStrengthQuantityName key:SprayStrengthKey numDecimals:3 alwaysWrite:NO];
    [Preferences populatePreferenceInDictionary:dict key:SprayLocationKey value:[self getSprayLocationForFileWrite] modifiedDate:nil perDevice:NO];
    
    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:NumSpraysQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeSprayQuantitySpraysPerDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Sprays per Dose", @"The sprays per dose quantity for spray drug types"]);
	else if ([name caseInsensitiveCompare:SprayStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeSprayQuantitySprayStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Spray Strength", @"The spray strength quantity for spray drug types"]);
	else
		return nil;
}

// Returns the label for the given picklist
- (NSString*)getLabelForDosePicklist:(NSString*)name
{
	if ([name caseInsensitiveCompare:SprayLocationPicklistName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeSprayPicklistSprayLocation", @"Dosecast", [DosecastUtil getResourceBundle], @"Spray Location", @"The spray location picklist for spray drug types"]);
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
		*quantityName = NumSpraysQuantityName;
		*sigDigits = 2;
		*numDecimals = 0;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (inputNum == 1)
	{
		*quantityName = SprayStrengthQuantityName;
		*sigDigits = 5;
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
	*sigDigits = 4;
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
	*sigDigits = 4;
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
		*picklistName = SprayLocationPicklistName;
		*displayNone = YES;
		return YES;
	}
	else
		return NO;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeSprayQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Sprays Remaining", @"The number of sprays remaining for spray drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeSprayQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Sprays per Refill", @"The number of sprays per refill for spray drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [SprayDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return NumSpraysQuantityName;
}


@end
