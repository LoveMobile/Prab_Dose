//
//  ManagedDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageQuantity.h"
#import "ManagedDrugDosage.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "DrugDosageUnitManager.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Custom dosage-related names and keys
static NSString *ManagedDosageTypeName = @"managed";
static NSString *ManagedDosageNumDosesName = @"managedNumDoses";
static NSString *ManagedDosageDescriptionName = @"managedDescription";
static NSString *ManagedDosageDescriptionKey = @"managedDescription";
static NSString *DatabaseNDCKey = @"databaseNDC";
static NSString *LastUserNotificationTimeKey = @"lastManagedIdNotified";
static NSString *LastManagedUpdateTimeKey = @"lastManagedIdNeedingNotify";
static NSString *IsDiscontinuedKey = @"managedDropped";

@implementation ManagedDrugDosage

@synthesize ndc;
@synthesize isDiscontinued;

- (void)populateQuantities
{
	// Populate quantities
    
    // This is a dummy quantity used to decrement the remaining quantity by 1 on a take pill
	DrugDosageQuantity* numDosesQuantity = [[DrugDosageQuantity alloc] init:1 unit:nil possibleUnits:nil];
	[doseQuantities setObject:numDosesQuantity forKey:ManagedDosageNumDosesName];
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
        ndc = nil;
        lastUserNotificationTime = nil;
        lastManagedUpdateTime = nil;
        isDiscontinued = NO;
        if (!quantities)
        {
            [self populateQuantities];
        }
		if (!textValues)
		{
            // Populate defaults
            [doseTextValues setObject:@"" forKey:ManagedDosageDescriptionName];
		}
	}
	return self;			
}

       - (id)init:(NSString*)dosageDescription
              ndc:(NSString*)ndcCode
lastUserNotificationTime:(NSString*)lastNotificationTime
lastManagedUpdateTime:(NSString*)lastUpdateTime
    isDiscontinued:(BOOL)discontinued
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
        ndc = ndcCode;
        lastUserNotificationTime = lastNotificationTime;
        lastManagedUpdateTime = lastUpdateTime;
        isDiscontinued = discontinued;
        [self populateQuantities];
        if (!dosageDescription)
            dosageDescription = @"";
        [doseTextValues setObject:dosageDescription forKey:ManagedDosageDescriptionName];
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
    NSString* ndccode = nil;
    BOOL discontinued = NO;
    NSString* lastNotificationTime = nil;
    NSString* lastUpdateTime = nil;
    NSString* description = nil;
    float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;    
    
    [Preferences readPreferenceFromDictionary:dict key:ManagedDosageDescriptionKey value:&description modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:DatabaseNDCKey value:&ndccode modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:LastUserNotificationTimeKey value:&lastNotificationTime modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:LastManagedUpdateTimeKey value:&lastUpdateTime modifiedDate:nil perDevice:nil];

    NSString* isDiscontinuedStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:IsDiscontinuedKey value:&isDiscontinuedStr modifiedDate:nil perDevice:nil];
    if (isDiscontinuedStr)
        discontinued = ([isDiscontinuedStr intValue] == 1);

	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	       return [self init:description
                         ndc:ndccode
    lastUserNotificationTime:lastNotificationTime
       lastManagedUpdateTime:lastUpdateTime
              isDiscontinued:discontinued
                   remaining:remaining
                      refill:refill
            refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    NSString* description = [self getValueForDoseTextValue:ManagedDosageDescriptionName];
    float remaining = 0.0f;
    [self getValueForRemainingQuantity:&remaining];
    float refill = 0.0f;
    [self getValueForRefillQuantity:&refill];
    int left = [self getRefillsRemaining];
        
	return [[ManagedDrugDosage alloc] init:[description mutableCopyWithZone:zone]
                                       ndc:[ndc copyWithZone:zone]
                  lastUserNotificationTime:[lastUserNotificationTime copyWithZone:zone]
                     lastManagedUpdateTime:[lastManagedUpdateTime copyWithZone:zone]
                            isDiscontinued:isDiscontinued
                                 remaining:remaining
                                    refill:refill
                          refillsRemaining:left];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
	// Set the type of dosage
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:ManagedDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];
	
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:0];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:0];
    
    NSString* description = [self getValueForDoseTextValue:ManagedDosageDescriptionName];
    [Preferences populatePreferenceInDictionary:dict key:ManagedDosageDescriptionKey value:description modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DatabaseNDCKey value:ndc modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:LastUserNotificationTimeKey value:lastUserNotificationTime modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:LastManagedUpdateTimeKey value:lastManagedUpdateTime modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:IsDiscontinuedKey value:[NSString stringWithFormat:@"%d", (isDiscontinued ? 1 : 0)] modifiedDate:nil perDevice:NO];
}

// Returns a string that describes the dose type
+ (NSString*)getTypeName
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeManaged", @"Dosecast", [DosecastUtil getResourceBundle], @"Managed", @"The display name for managed drug types"]);
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
    return [ManagedDrugDosage getTypeName];
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
	return [NSString stringWithString:ManagedDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [ManagedDrugDosage getFileTypeName];
}


// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName dosage:(NSString*)dosage
{
    NSMutableString* description = [NSMutableString stringWithString:@""];
    if (drugName && [drugName length] > 0)
    {
        [description appendString:drugName];
        if (dosage && [dosage length] > 0)
            [description appendFormat:@" (%@)", [dosage lowercaseString]];
    }
    else
    {
        if (dosage && [dosage length] > 0)
            [description appendString:dosage];
    }
    
    return description;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{		
    NSString* dosage = [self getValueForDoseTextValue:ManagedDosageDescriptionName];
    return [ManagedDrugDosage getDescriptionForDrugDose:drugName dosage:dosage];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* dosage = nil;
    [Preferences readPreferenceFromDictionary:doseData key:ManagedDosageDescriptionKey value:&dosage modifiedDate:nil perDevice:nil];
    
    return [ManagedDrugDosage getDescriptionForDrugDose:drugName dosage:dosage];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
    NSString* description = [self getValueForDoseTextValue:ManagedDosageDescriptionName];
    if (description)
        [Preferences populatePreferenceInDictionary:dict key:ManagedDosageDescriptionKey value:description modifiedDate:nil perDevice:NO];
    
    return dict;
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
    *textValueName = ManagedDosageDescriptionName;
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
    return [ManagedDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return ManagedDosageNumDosesName;
}

// If an existing managed med has been edited by an external system and the user needs to be notified
- (BOOL) requiresUserNotification
{
    return (!isDiscontinued && lastManagedUpdateTime && lastUserNotificationTime && [lastManagedUpdateTime compare:lastUserNotificationTime options:NSLiteralSearch] != NSOrderedSame);
}

// If a new managed med has been added by an external system and the user needs to be notified
- (BOOL) isNew
{
    return (!isDiscontinued && lastManagedUpdateTime && !lastUserNotificationTime);
}

// If the user has been notified after an existing managed med has been edited or a new managed med has been added by an external system
- (void) markAsUserNotified
{
    lastUserNotificationTime = lastManagedUpdateTime;
}

@end
