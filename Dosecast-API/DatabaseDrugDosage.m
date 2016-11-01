//
//  DatabaseDrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DatabaseDrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DosecastUtil.h"
#import "DrugDosageUnitManager.h"
#import "MedicationSearchManager.h"
#import "MedicationRoute.h"
#import "MedApplyLocation.h"
#import "MedDoseUnit.h"
#import "MedStrengthUnit.h"
#import "Preferences.h"

static NSString *DosageTypeKey = @"dosageType";
static NSString *NumPillsKey = @"numpills";
static NSString *PillStrengthKey = @"dose";

// Injection-related names and keys
static NSString *DatabaseDosageTypeName = @"database";
static NSString *DatabaseAmountQuantityName = @"databaseAmount";
static NSString *DatabaseStrengthQuantityName = @"databaseStrength";
static NSString *DatabaseLocationPicklistName = @"databaseLocation";
static NSString *DatabaseRoutePicklistName = @"databaseRoute";
static NSString *DatabaseAmountKey = @"databaseAmount";
static NSString *DatabaseStrengthKey = @"databaseStrength";
static NSString *DatabaseLocationKey = @"databaseLocation";
static NSString *DatabaseRouteKey = @"databaseRoute";
static NSString *DatabaseMedFormKey = @"databaseMedForm";
static NSString *DatabaseMedFormTypeKey = @"databaseMedFormType";
static NSString *DatabaseMedTypeKey = @"databaseMedType";
static NSString *DatabaseNDCKey = @"databaseNDC";

static float epsilon = 0.0001;

@implementation DatabaseDrugDosage

@synthesize medForm;
@synthesize medType;
@synthesize ndc;
@synthesize medFormType;

- (NSArray*)getPossibleDatabaseAmountUnits
{
    // Retrieve amount units from the database
    NSMutableArray *amountUnitOptions = [[NSMutableArray alloc] init];
    if (medFormType)
    {
        NSArray *medDoseUnits = [[MedicationSearchManager sharedManager] getDoseAmountUnitsForFormType:medFormType];
        __block BOOL foundEmptyUnit = NO;
        [medDoseUnits enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            MedDoseUnit *medDoseUnit=(MedDoseUnit *)obj;
            [amountUnitOptions addObject:medDoseUnit.unitDesc];
            if ([medDoseUnit.unitDesc length] == 0)
                foundEmptyUnit = YES;
        }];
        
        // Make sure we have "the empty unit" (representing no unit at all) for amount units
        if ([amountUnitOptions count] > 0 && !foundEmptyUnit)
            [amountUnitOptions insertObject:@"" atIndex:0];
    }
    
    // Don't pass-in an empty array. Instead, make the quantity appear unit-less.
    if ([amountUnitOptions count] == 0)
        amountUnitOptions = nil;

    return amountUnitOptions;    
}

-(void)populateQuantities:(float)databaseAmount
	   databaseAmountUnit:(NSString*)databaseAmountUnit
		 databaseStrength:(float)databaseStrength
	 databaseStrengthUnit:(NSString*)databaseStrengthUnit
possibleDatabaseAmountUnits:(NSArray*)possibleDatabaseAmountUnits
{	
    // If not amount unit is set, set it to "the empty unit"
    if (!databaseAmountUnit)
        databaseAmountUnit = @"";
    
	DrugDosageQuantity* databaseAmountQuantity = [[DrugDosageQuantity alloc] init:databaseAmount unit:databaseAmountUnit possibleUnits:possibleDatabaseAmountUnits];
	[doseQuantities setObject:databaseAmountQuantity forKey:DatabaseAmountQuantityName];
	
    // Retrieve strength units from the database    
    NSMutableArray *possibleDatabaseStrengthUnits = [[NSMutableArray alloc] init];
    if (medFormType)
    {
        NSArray *medStrengthUnits = [[MedicationSearchManager sharedManager] getStrengthUnitsForFormType:medFormType];
        [medStrengthUnits enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            MedStrengthUnit *medStrengthUnit=(MedStrengthUnit *)obj;
            [possibleDatabaseStrengthUnits addObject:medStrengthUnit.unitDesc];
        }];
    }
    
    // Don't bother with strength quantities if no units are available
    if ([possibleDatabaseStrengthUnits count] > 0)
    {    
        DrugDosageQuantity* databaseStrengthQuantity = [[DrugDosageQuantity alloc] init:databaseStrength unit:databaseStrengthUnit possibleUnits:possibleDatabaseStrengthUnits];
        [doseQuantities setObject:databaseStrengthQuantity forKey:DatabaseStrengthQuantityName];	
    }
}

- (void)populatePicklistOptions
{
    // Populate location options
    NSMutableArray *locationOptions = [[NSMutableArray alloc] init];
    if (medFormType)
    {
        NSArray *medApplyLocations = [[MedicationSearchManager sharedManager] getMedicationLocationsForFormType:medFormType];
        [medApplyLocations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            MedApplyLocation *medApplyLocation=(MedApplyLocation *)obj;
            [locationOptions addObject:medApplyLocation.locationDesc];
        }];
    }
    // Avoid populating an empty picklist
    if ([locationOptions count] > 0)
        [dosePicklistOptions setObject:locationOptions forKey:DatabaseLocationPicklistName];
    
    // Populate route options
    NSMutableArray *routeOptions = [[NSMutableArray alloc] init];
    NSArray *medRoutes = [[MedicationSearchManager sharedManager] getMedicationRoutes];
    [medRoutes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        MedicationRoute *medRoute=(MedicationRoute *)obj;
        [routeOptions addObject:medRoute.route];
    }];
    
    if ([routeOptions count] > 0)
        [dosePicklistOptions setObject:routeOptions forKey:DatabaseRoutePicklistName];
}

- (void)populatePicklistValues:(NSString*)location
                         route:(NSString*)route
{
    if (location)
        [dosePicklistValues setObject:location forKey:DatabaseLocationPicklistName];
    if (route)
        [dosePicklistValues setObject:route forKey:DatabaseRoutePicklistName];
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
        withRefillsRemaining:(int)left
                 medFormType:(NSString*)formType
{
	if ((self = [super initWithDoseQuantities:quantities
					withDosePicklistOptions:picklistOptions
					 withDosePicklistValues:picklistValues
                           withDoseTextValues:textValues
					  withRemainingQuantity:remaining
						 withRefillQuantity:refill
                              withRefillsRemaining:left]))
    {
        medForm = nil;
        medFormType = formType;
        medType = nil;
        ndc = nil;
        NSArray* possibleDatabaseAmountUnits = [self getPossibleDatabaseAmountUnits];
		if (!quantities)
		{
			// Populate defaults
			[self populateQuantities:0.0f databaseAmountUnit:nil databaseStrength:-1.0f databaseStrengthUnit:nil possibleDatabaseAmountUnits:possibleDatabaseAmountUnits];
		}
		if (!remaining)
		{
			[remainingQuantity.possibleUnits setArray:possibleDatabaseAmountUnits];
		}
		if (!refill)
		{
			[refillQuantity.possibleUnits setArray:possibleDatabaseAmountUnits];
		}
        if (!picklistOptions)
		{
			// Populate defaults
			[self populatePicklistOptions];
		}
		if (!picklistValues)
		{
			// Populate defaults
			[self populatePicklistValues:@"" route:@""];
		}
	}
	return self;			
}

      - (id)init:(NSString*)form
     medFormType:(NSString*)formType
         medType:(NSString*)type
             ndc:(NSString*)ndccode
          amount:(float)amount
      amountUnit:(NSString*)amountUnit
        strength:(float)strength
    strengthUnit:(NSString*)strengthUnit
        location:(NSString*)location
           route:(NSString*)route
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
        medForm = form;
        medFormType = formType;
        medType = type;
        ndc = ndccode;
		NSArray* possibleDatabaseAmountUnits = [self getPossibleDatabaseAmountUnits];

		[self populateQuantities:amount databaseAmountUnit:amountUnit databaseStrength:strength databaseStrengthUnit:strengthUnit possibleDatabaseAmountUnits:possibleDatabaseAmountUnits];
				
		remainingQuantity.value = remaining;
		remainingQuantity.unit = remainingUnit;
		refillQuantity.value = refill;
		refillQuantity.unit = refillUnit;
		[remainingQuantity.possibleUnits setArray:possibleDatabaseAmountUnits];
		[refillQuantity.possibleUnits setArray:possibleDatabaseAmountUnits];
        [self populatePicklistOptions];
		[self populatePicklistValues:location route:route];
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
                        withRefillsRemaining:-1
                            medFormType:nil];
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{	
	float databaseAmount = 0.0f;
	NSString* databaseAmountUnit = nil;
	float databaseStrength = -1.0f;
	NSString* databaseStrengthUnit = nil;
    NSMutableString* databaseLocation = [NSMutableString stringWithString:@""];
    NSMutableString* databaseRoute = [NSMutableString stringWithString:@""];
	float remaining = -1.0f;
	NSString* remainingUnit = nil;
	float refill = -1.0f;
	NSString* refillUnit = nil;
    NSString* form = nil;
    NSString* type = nil;
    NSString* formType = nil;
    NSString* ndccode = nil;
	
	[self readDoseQuantityFromDictionary:dict key:DatabaseAmountKey val:&databaseAmount unit:&databaseAmountUnit];
	[self readDoseQuantityFromDictionary:dict key:DatabaseStrengthKey val:&databaseStrength unit:&databaseStrengthUnit];
	[self readRemainingQuantityFromDictionary:dict val:&remaining unit:&remainingUnit];
	[self readRefillQuantityFromDictionary:dict val:&refill unit:&refillUnit];
	
    // Get the location and route
    NSString* databaseLocationStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:DatabaseLocationKey value:&databaseLocationStr modifiedDate:nil perDevice:nil];
    if (databaseLocationStr && [databaseLocationStr length] > 0)
    {
        [databaseLocation setString:databaseLocationStr];
    }
    NSString* databaseRouteStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:DatabaseRouteKey value:&databaseRouteStr modifiedDate:nil perDevice:nil];
    if (databaseRouteStr && [databaseRouteStr length] > 0)
    {
        [databaseRoute setString:databaseRouteStr];
    }
    // Get the medForm, medFormType, medType, ndc
    [Preferences readPreferenceFromDictionary:dict key:DatabaseMedFormKey value:&form modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:DatabaseMedFormTypeKey value:&formType modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:DatabaseMedTypeKey value:&type modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:DatabaseNDCKey value:&ndccode modifiedDate:nil perDevice:nil];
    
    int left = -1;
    [self readRefillsRemainingFromDictionary:dict refillsRemaining:&left];
    
	return [self init:form
          medFormType:formType
              medType:type
                  ndc:ndccode
               amount:databaseAmount
           amountUnit:databaseAmountUnit
             strength:databaseStrength
         strengthUnit:databaseStrengthUnit
             location:databaseLocation
                route:databaseRoute
            remaining:remaining
        remainingUnit:remainingUnit
               refill:refill
           refillUnit:refillUnit
     refillsRemaining:left];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    float remaining = 0.0f;
    [self getValueForRemainingQuantity:&remaining];
    NSString* remainingUnit = nil;
    [self getUnitForRemainingQuantity:&remainingUnit];
    float refill = 0.0f;
    [self getValueForRefillQuantity:&refill];
    NSString* refillUnit = nil;
    [self getUnitForRefillQuantity:&refillUnit];
    int left = [self getRefillsRemaining];
    float amount = 0.0f;
    [self getValue:&amount forDoseQuantity:DatabaseAmountQuantityName];
    NSString* amountUnit = nil;
    [self getUnit:&amountUnit forDoseQuantity:DatabaseAmountQuantityName];
    float strength = -1.0f;
    [self getValue:&strength forDoseQuantity:DatabaseStrengthQuantityName];
    NSString* strengthUnit = nil;
    [self getUnit:&strengthUnit forDoseQuantity:DatabaseStrengthQuantityName];
    NSString* location = [self getValueForDosePicklist:DatabaseLocationPicklistName];
    NSString* route = [self getValueForDosePicklist:DatabaseRoutePicklistName];
    
	return [[DatabaseDrugDosage alloc] init:[medForm copyWithZone:zone]
                                medFormType:[medFormType copyWithZone:zone]
                                    medType:[medType copyWithZone:zone]
                                        ndc:[ndc copyWithZone:zone]
                                     amount:amount
                                 amountUnit:amountUnit
                                   strength:strength
                               strengthUnit:strengthUnit
                                   location:location
                                      route:route
                                  remaining:remaining
                              remainingUnit:remainingUnit
                                     refill:refill
                                 refillUnit:refillUnit
                           refillsRemaining:left];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{	
	// Set the type of dosage
    [Preferences populatePreferenceInDictionary:dict key:DosageTypeKey value:DatabaseDosageTypeName modifiedDate:nil perDevice:NO];
	
	// Legacy behavior: populate dummy values for pill data
	[dict setObject:@"0.0f" forKey:NumPillsKey];	
	[dict setObject:@"" forKey:PillStrengthKey];		
	
	[self populateDictionaryForDoseQuantity:dict quantityName:DatabaseAmountQuantityName key:DatabaseAmountKey numDecimals:2 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:DatabaseStrengthQuantityName key:DatabaseStrengthKey numDecimals:2 alwaysWrite:NO];	
	if (!forSyncRequest)
    {
        [self populateDictionaryForRemainingQuantity:dict numDecimals:2];
        [self populateDictionaryForRefillsRemaining:dict];
    }
	[self populateDictionaryForRefillQuantity:dict numDecimals:2];
	
    NSString* locationVal = [self getValueForDosePicklist:DatabaseLocationPicklistName];
	if (!locationVal)
		locationVal = @"";
    [Preferences populatePreferenceInDictionary:dict key:DatabaseLocationKey value:locationVal modifiedDate:nil perDevice:NO];

    NSString* routeVal = [self getValueForDosePicklist:DatabaseRoutePicklistName];
	if (!routeVal)
		routeVal = @"";
    [Preferences populatePreferenceInDictionary:dict key:DatabaseRouteKey value:routeVal modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DatabaseMedFormKey value:medForm modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DatabaseMedFormTypeKey value:medFormType modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DatabaseMedTypeKey value:medType modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DatabaseNDCKey value:ndc modifiedDate:nil perDevice:NO];
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return medFormType;
}

// Returns a string that identifies this type
+ (NSString*)getFileTypeName
{
	return [NSString stringWithString:DatabaseDosageTypeName];
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
    return [DatabaseDrugDosage getFileTypeName];
}

// Returns a string that describes the dose for the given drug name
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName amount:(NSString*)amount strength:(NSString*)strength location:(NSString*)location route:(NSString*)route medFormType:(NSString*)medFormType
{
	NSMutableString* doseDescrip = [NSMutableString stringWithString:@""];
	        
	if (amount && [amount length] > 0 && [amount floatValue] > epsilon)
		[doseDescrip appendFormat:@"%@", amount];
    
    if (drugName && [drugName length] > 0)
	{
        if ([doseDescrip length] > 0)
            [doseDescrip appendString:@" "];
		[doseDescrip appendFormat:@"%@", drugName];
	}
    
    if (strength && [strength length] > 0 && [strength floatValue] > epsilon)
	{
        if ([doseDescrip length] > 0)
            [doseDescrip appendString:@", "];
		[doseDescrip appendFormat:@"%@", strength];
	}
	
    if (location && [location length] > 0)
    {
        if ([doseDescrip length] > 0)
            [doseDescrip appendString:@", "];
		[doseDescrip appendFormat:@"%@", location];
    }
    
    if (route && [route length] > 0)
    {
        if ([doseDescrip length] > 0)
            [doseDescrip appendString:@", "];
		[doseDescrip appendFormat:@"%@", route];
    }
    
    if (medFormType && [medFormType length] > 0)
    {
        if ([doseDescrip length] > 0)
            [doseDescrip appendString:@" "];
		[doseDescrip appendFormat:@"%@", medFormType];
    }
    
	return doseDescrip;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
	NSString* amount = nil;
	if ([self isValidValueForDoseQuantity:DatabaseAmountQuantityName])
        amount = [self getDescriptionForDoseQuantity:DatabaseAmountQuantityName maxNumDecimals:2];

    NSString* strength = nil;
    if ([self isValidValueForDoseQuantity:DatabaseStrengthQuantityName])
        strength = [self getDescriptionForDoseQuantity:DatabaseStrengthQuantityName maxNumDecimals:2];

	NSString* location = nil;
    if ([self isValidValueForDosePicklist:DatabaseLocationPicklistName])
        location = [self getValueForDosePicklist:DatabaseLocationPicklistName];

    NSString* route = nil;
    if ([self isValidValueForDosePicklist:DatabaseRoutePicklistName])
        route = [self getValueForDosePicklist:DatabaseRoutePicklistName];

	return [DatabaseDrugDosage getDescriptionForDrugDose:drugName amount:amount strength:strength location:location route:route medFormType:medFormType];
}

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData
{
    NSString* amount = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DatabaseAmountKey value:&amount modifiedDate:nil perDevice:nil];
    amount = [DrugDosage getTrimmedValueInStringAsString:amount maxNumDecimals:2];
    
    NSString* strength = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DatabaseStrengthKey value:&strength modifiedDate:nil perDevice:nil];
    strength = [DrugDosage getTrimmedValueInStringAsString:strength maxNumDecimals:2];
    
    NSString* location = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DatabaseLocationKey value:&location modifiedDate:nil perDevice:nil];
    
    NSString* route = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DatabaseRouteKey value:&route modifiedDate:nil perDevice:nil];
    
    NSString* medFormType = nil;
    [Preferences readPreferenceFromDictionary:doseData key:DatabaseMedFormTypeKey value:&medFormType modifiedDate:nil perDevice:nil];

	return [DatabaseDrugDosage getDescriptionForDrugDose:drugName amount:amount strength:strength location:location route:route medFormType:medFormType];
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];

    [self populateDictionaryForDoseQuantity:dict quantityName:DatabaseAmountQuantityName key:DatabaseAmountKey numDecimals:2 alwaysWrite:NO];
	[self populateDictionaryForDoseQuantity:dict quantityName:DatabaseStrengthQuantityName key:DatabaseStrengthKey numDecimals:2 alwaysWrite:NO];

    NSString* locationVal = [self getValueForDosePicklist:DatabaseLocationPicklistName];
	if (!locationVal)
		locationVal = @"";
    [Preferences populatePreferenceInDictionary:dict key:DatabaseLocationKey value:locationVal modifiedDate:nil perDevice:NO];
    
    NSString* routeVal = [self getValueForDosePicklist:DatabaseRoutePicklistName];
	if (!routeVal)
		routeVal = @"";
    [Preferences populatePreferenceInDictionary:dict key:DatabaseRouteKey value:routeVal modifiedDate:nil perDevice:NO];

    if (medFormType)
        [Preferences populatePreferenceInDictionary:dict key:DatabaseMedFormTypeKey value:medFormType modifiedDate:nil perDevice:NO];

    return dict;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	if ([name caseInsensitiveCompare:DatabaseAmountQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabaseQuantityAmount", @"Dosecast", [DosecastUtil getResourceBundle], @"Amount", @"The amount quantity for database drug types"]);
	else if ([name caseInsensitiveCompare:DatabaseStrengthQuantityName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabaseQuantityStrength", @"Dosecast", [DosecastUtil getResourceBundle], @"Strength", @"The strength quantity for database drug types"]);
	else
		return nil;
}

// Returns the label for the given picklist
- (NSString*)getLabelForDosePicklist:(NSString*)name
{
	if ([name caseInsensitiveCompare:DatabaseLocationPicklistName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabasePicklistLocation", @"Dosecast", [DosecastUtil getResourceBundle], @"Location", @"The location picklist for database drug types"]);
	else if ([name caseInsensitiveCompare:DatabaseRoutePicklistName] == NSOrderedSame)
		return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabasePicklistRoute", @"Dosecast", [DosecastUtil getResourceBundle], @"Route", @"The route picklist for database drug types"]);
	else
		return nil;
}

// Returns the input type for the given input number
- (DrugDosageInputType) getDoseInputTypeForInput:(int)inputNum
{
    BOOL hasStrengthQuantity = ([self possibleUnitsForDoseQuantity:DatabaseStrengthQuantityName] != nil);
    int lastQuantityIndex = 1;
    if (hasStrengthQuantity)
        lastQuantityIndex++;
    
	if (inputNum < lastQuantityIndex)
		return DrugDosageInputTypeQuantity;
	else
		return DrugDosageInputTypePicklist;
}

// Returns all the UI settings for the quantity with the given input number
- (BOOL) getDoseQuantityUISettingsForInput:(int)inputNum
						  quantityName:(NSString**)quantityName
							 sigDigits:(int*)sigDigits
						   numDecimals:(int*)numDecimals
						   displayNone:(BOOL*)displayNone
							 allowZero:(BOOL*)allowZero
{
    BOOL hasStrengthQuantity = ([self possibleUnitsForDoseQuantity:DatabaseStrengthQuantityName] != nil);

	if (inputNum == 0)
	{
		*quantityName = DatabaseAmountQuantityName;
		*sigDigits = 6;
		*numDecimals = 2;
		*displayNone = YES;
		*allowZero = YES;
		return YES;
	}
	else if (hasStrengthQuantity && inputNum == 1)
	{
		*quantityName = DatabaseStrengthQuantityName;
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

// Returns all the UI settings for the picklist with the given input number
- (BOOL) getDosePicklistUISettingsForInput:(int)inputNum
                              picklistName:(NSString**)picklistName
                               displayNone:(BOOL*)displayNone
{
    BOOL hasStrengthQuantity = ([self possibleUnitsForDoseQuantity:DatabaseStrengthQuantityName] != nil);
    BOOL hasLocationOptions = ([self possibleOptionsForDosePicklist:DatabaseLocationPicklistName] != nil);
    BOOL hasRouteOptions = ([self possibleOptionsForDosePicklist:DatabaseRoutePicklistName] != nil);
    int locationPicklistNum = 1;
    if (hasStrengthQuantity)
        locationPicklistNum++;
    int routePicklistNum = locationPicklistNum;
    if (hasLocationOptions)
        routePicklistNum++;
    
	if (hasLocationOptions && inputNum == locationPicklistNum)
	{
		*picklistName = DatabaseLocationPicklistName;
		*displayNone = YES;
		return YES;
	}
	else if (hasRouteOptions && inputNum == routePicklistNum)
	{
		*picklistName = DatabaseRoutePicklistName;
		*displayNone = YES;
		return YES;
	}
	else
		return NO;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabaseQuantityRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Amount Remaining", @"The amount remaining for database drug types"]);
}

- (NSString*)getLabelForRefillQuantity
{
	return NSLocalizedStringWithDefaultValue(@"DrugTypeDatabaseQuantityRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Amount per Refill", @"The amount per refill for database drug types"]);
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return [DatabaseDrugDosage getDoseQuantityToDecrementRemainingQuantity];
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
    return DatabaseAmountQuantityName;
}


@end
