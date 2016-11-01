//
//  CustomDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageQuantity.h"
#import "CustomDrugDosage.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "CustomNameIDList.h"
#import "DrugDosageUnitManager.h"
#import "GlobalSettings.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Custom dosage-related names and keys
static NSString *CustomDosageTypeName = @"custom";
static NSString *CustomDosageNumDosesName = @"customNumDoses";
static NSString *CustomDosageDescriptionName = @"customDescription";
static NSString *CustomDosageDescriptionKey = @"customDescription";
static NSString *CustomDosageIDKey = @"customDosageID";
static NSString *CustomDosageTypeNameKey = @"typeName";

@implementation CustomDrugDosage

- (void)populateQuantities
{
	// Populate quantities
    
    // This is a dummy quantity used to decrement the remaining quantity by 1 on a take pill
	DrugDosageQuantity* numDosesQuantity = [[DrugDosageQuantity alloc] init:1 unit:nil possibleUnits:nil];
	[doseQuantities setObject:numDosesQuantity forKey:CustomDosageNumDosesName];	
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
            [self populateQuantities];
        }
		if (!textValues)
		{
            // Populate defaults
            [doseTextValues setObject:@"" forKey:CustomDosageDescriptionName];
		}
        customDosageID = @"";
	}
	return self;			
}

       - (id)init:(NSString*)dosageID
dosageDescription:(NSString*)dosageDescription
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
        [self populateQuantities];
        if (!dosageDescription)
            dosageDescription = @"";
        [doseTextValues setObject:dosageDescription forKey:CustomDosageDescriptionName];
        if (!dosageID)
            dosageID = @"";
        customDosageID = dosageID;
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
    NSString* description = nil;
    float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;    
    NSString* dosageID = nil;
    
    [Preferences readPreferenceFromDictionary:dict key:CustomDosageDescriptionKey value:&description modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:CustomDosageIDKey value:&dosageID modifiedDate:nil perDevice:nil];
    
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:dosageID
    dosageDescription:description
            remaining:remaining
               refill:refill
     refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    NSString* description = [self getValueForDoseTextValue:CustomDosageDescriptionName];
    float remaining = 0.0f;
    [self getValueForRemainingQuantity:&remaining];
    float refill = 0.0f;
    [self getValueForRefillQuantity:&refill];
    int left = [self getRefillsRemaining];
        
	return [[CustomDrugDosage alloc] init:[customDosageID mutableCopyWithZone:zone]
                        dosageDescription:[description mutableCopyWithZone:zone]
                                remaining:remaining
                                   refill:refill
                         refillsRemaining:left];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
	// Set the type of dosage
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:CustomDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];
	
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:0];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:0];
    
    NSString* description = [self getValueForDoseTextValue:CustomDosageDescriptionName];
    [Preferences populatePreferenceInDictionary:dict key:CustomDosageDescriptionKey value:description modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:CustomDosageIDKey value:customDosageID modifiedDate:nil perDevice:NO];    
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
    DataModel* dataModel = [DataModel getInstance];
    return [dataModel.globalSettings.customDrugDosageNames nameForGuid:customDosageID];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [CustomDrugDosage getFileTypeName];
}

// Returns the total number of inputs for this dosage
- (int) numDoseInputs
{
    // Subtract 1 because we're using a dummy quantity for decrementing the remaining quantity by 1 on a take pill
	return [super numDoseInputs]-1;
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:CustomDosageTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName dosage:(NSString*)dosage typeName:(NSString*)typeName
{
    NSMutableString* description = [NSMutableString stringWithString:@""];
    if (drugName && [drugName length] > 0)
    {
        [description appendString:drugName];
        if (dosage && [dosage length] > 0)
            [description appendFormat:@" (%@)", [dosage lowercaseString]];
        else
            [description appendFormat:@" (%@)", [typeName lowercaseString]];
    }
    else
    {
        if (dosage && [dosage length] > 0)
            [description appendString:dosage];
        else
            [description appendString:typeName];
    }
    
    return description;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{		
    NSString* dosage = [self getValueForDoseTextValue:CustomDosageDescriptionName];
    NSString* typeName = [self getTypeName];
    return [CustomDrugDosage getDescriptionForDrugDose:drugName dosage:dosage typeName:typeName];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];

    NSString* description = [self getValueForDoseTextValue:CustomDosageDescriptionName];
    [Preferences populatePreferenceInDictionary:dict key:CustomDosageDescriptionKey value:description modifiedDate:nil perDevice:NO];

    NSString* typeName = [self getTypeName];
    [Preferences populatePreferenceInDictionary:dict key:CustomDosageTypeNameKey value:typeName modifiedDate:nil perDevice:NO];

    return dict;
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* dosage = nil;
    [Preferences readPreferenceFromDictionary:doseData key:CustomDosageDescriptionKey value:&dosage modifiedDate:nil perDevice:nil];

    NSString* typeName = nil;
    [Preferences readPreferenceFromDictionary:doseData key:CustomDosageTypeNameKey value:&typeName modifiedDate:nil perDevice:nil];

    return [CustomDrugDosage getDescriptionForDrugDose:drugName dosage:dosage typeName:typeName];
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
    return nil;
}

// Returns the input type for the given input number
- (DrugDosageInputType) getDoseInputTypeForInput:(int)inputNum
{
    return DrugDosageInputTypeText;
}

// Returns all the UI settings for the text value with the given input number
- (BOOL) getDoseTextValueUISettingsForInput:(int)inputNum
                              textValueName:(NSString**)textValueName
                                displayNone:(BOOL*)displayNone
{
    *textValueName = CustomDosageDescriptionName;
    *displayNone = NO;
    return YES;
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

// Returns the label for the given text value
- (NSString*)getLabelForDoseTextValue:(NSString*)name
{
    return NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"]);
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCustomQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Doses Remaining", @"The amount remaining for custom drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeCustomQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Doses per Refill", @"The amount per refill for custom drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [CustomDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return CustomDosageNumDosesName;
}

// Returns the custom dosage ID
- (NSString*)getCustomDosageID
{
    return customDosageID;
}


@end
