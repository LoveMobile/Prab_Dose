//
//  DrugDosage.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosage.h"
#import "DrugDosageQuantity.h"
#import "DrugDosageUnitManager.h"
#import "DosecastUtil.h"
#import "Preferences.h"

static NSString* RemainingQuantityKey = @"remainingQuantity";
static NSString* RefillQuantityKey = @"refillQuantity";
static NSString* RefillsRemainingKey = @"refillsRemaining";

static float epsilon = 0.0001;

@implementation DrugDosage

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
             withRefillsRemaining:(int)left
{
	if ((self = [super init]))
    {
		doseQuantities = [[NSMutableDictionary alloc] init];
		if (quantities)
			[doseQuantities addEntriesFromDictionary:quantities];
		dosePicklistOptions = [[NSMutableDictionary alloc] init];
		if (picklistOptions)
			[dosePicklistOptions addEntriesFromDictionary:picklistOptions];
		dosePicklistValues = [[NSMutableDictionary alloc] init];
		if (picklistValues)
			[dosePicklistValues addEntriesFromDictionary:picklistValues];	
        doseTextValues = [[NSMutableDictionary alloc] init];
        if (textValues)
            [doseTextValues addEntriesFromDictionary:textValues];
		if (remaining)
		{
            if (!remaining.allowNegative)
                remaining.allowNegative = YES;
			remainingQuantity = remaining;
		}
		else
			remainingQuantity = [[DrugDosageQuantity alloc] init:0.0f unit:nil possibleUnits:nil allowNegative:YES];
		if (refill)
		{
            if (refill.allowNegative)
                refill.allowNegative = NO;
			refillQuantity = refill;
		}
		else
			refillQuantity = [[DrugDosageQuantity alloc] init:0.0f unit:nil possibleUnits:nil allowNegative:NO];
        if (left < 0)
            left = 0;
        refillsRemaining = left;
	}
	return self;			
}

- (id)init
{
	return [self initWithDoseQuantities:nil withDosePicklistOptions:nil withDosePicklistValues:nil withDoseTextValues:nil withRemainingQuantity:nil withRefillQuantity:nil withRefillsRemaining:0];
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{
	return [self initWithDoseQuantities:nil withDosePicklistOptions:nil withDosePicklistValues:nil withDoseTextValues:nil withRemainingQuantity:nil withRefillQuantity:nil withRefillsRemaining:0];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[DrugDosage alloc] initWithDoseQuantities:[doseQuantities mutableCopyWithZone:zone]
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
}

// Returns a string that describes the dose type
- (NSString*)getTypeName
{
	return nil;
}

// Returns a string that describes the dose type
- (NSString*)getFileTypeName
{
	return nil;
}

// Returns dictionary of dose data
- (NSDictionary*) getDoseData
{
    return nil;
}

// Returns an array of quantity names, each of which may be used as a key to get/set the value and unit
- (NSArray*)doseQuantityNames
{
	return [doseQuantities allKeys];
}

// Returns an array of picklist names, each of which may be used as a key to get/set the value
- (NSArray*)dosePicklistNames
{
	return [dosePicklistOptions allKeys];
}

// Returns an array of text value names, each of which may be used as a key to get/set the value
- (NSArray*)doseTextValueNames
{
    return [doseTextValues allKeys];
}

// Returns the number of quantities
- (int) numDoseQuantities
{
	return (int)[[self doseQuantityNames] count];
}

// Returns the number of picklists
- (int) numDosePicklists
{
	return (int)[[self dosePicklistNames] count];
}

// Returns the number of text values
- (int) numDoseTextValues
{
    return (int)[[self doseTextValueNames] count];
}

// Returns the total number of inputs for this dosage
- (int) numDoseInputs
{
	return [self numDoseQuantities] + [self numDosePicklists] + [self numDoseTextValues];
}

// Returns the input type for the given input number
- (DrugDosageInputType) getDoseInputTypeForInput:(int)inputNum
{
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
	return NO;
}

// Returns all the UI settings for the remaining quantity
- (BOOL) getRemainingQuantityUISettings:(int*)sigDigits
							numDecimals:(int*)numDecimals
							displayNone:(BOOL*)displayNone
							  allowZero:(BOOL*)allowZero
{
	return NO;
}

// Returns all the UI settings for the refill quantity
- (BOOL) getRefillQuantityUISettings:(int*)sigDigits
						 numDecimals:(int*)numDecimals
						 displayNone:(BOOL*)displayNone
						   allowZero:(BOOL*)allowZero
{
	return NO;
}

// Returns all the UI settings for the picklist with the given input number
- (BOOL) getDosePicklistUISettingsForInput:(int)inputNum
						  picklistName:(NSString**)picklistName
						   displayNone:(BOOL*)displayNone
{
	return NO;
}

// Returns all the UI settings for the text value with the given input number
- (BOOL) getDoseTextValueUISettingsForInput:(int)inputNum
                              textValueName:(NSString**)textValueName
                                displayNone:(BOOL*)displayNone
{
    return NO;
}

// Accessors for refills remaining
- (int)getRefillsRemaining
{
    return refillsRemaining;
}

- (void)setRefillsRemaining:(int)left
{
    if (left < 0)
        left = 0;
    refillsRemaining = left;
}

// Returns the value for the given quantity, if it exists
- (BOOL)getValue:(float*)value forDoseQuantity:(NSString*)name
{
	*value = -1.0f;
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	if (quantity)
	{
		*value = quantity.value;
		return YES;
	}
	else
		return NO;
}

// Returns if the value is valid for the given quantity
- (BOOL)isValidValueForDoseQuantity:(NSString*)name
{
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	return (quantity && [quantity isValidValue]);
}

// Sets the value for the given quantity, if it exists
- (BOOL)setValue:(float)value forDoseQuantity:(NSString*)name
{
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	if (quantity)
	{
		quantity.value = value;
		return YES;
	}
	else
		return NO;	
}

// Returns the options for the given picklist, if it exists
- (NSArray*)possibleOptionsForDosePicklist:(NSString*)name
{
	NSArray* options = [dosePicklistOptions objectForKey:name];
	return options;	
}

// Returns the value for the given picklist, if it exists
- (NSString*) getValueForDosePicklist:(NSString*)name
{
	NSString* value = [dosePicklistValues objectForKey:name];
	return value;
}

// Returns if the value is valid for the given picklist
- (BOOL)isValidValueForDosePicklist:(NSString*)name
{
	NSString* value = [dosePicklistValues objectForKey:name];
	return value && [value length] > 0;
}

// Sets the value for the given picklist, if it exists
- (BOOL)setValue:(NSString*)value forDosePicklist:(NSString*)name
{
	if (!value)
		return NO;
	
	NSArray* options = [dosePicklistOptions objectForKey:name];
	if (options)
	{
        [dosePicklistValues setObject:value forKey:name];
        return YES;
	}
	else
		return NO;	
}

// Returns the value for the given text value, if it exists
- (NSString*) getValueForDoseTextValue:(NSString*)name
{
 	NSString* value = [doseTextValues objectForKey:name];
	return value;
}

// Returns if the value is valid for the given text value
- (BOOL)isValidValueForDoseTextValue:(NSString*)name
{
    NSString* value = [doseTextValues objectForKey:name];
	return value && [value length] > 0;
}

// Sets the value for the given text value, if it exists
- (BOOL)setValue:(NSString*)value forDoseTextValue:(NSString*)name
{
    if (!value)
		return NO;

	// Make sure this is a valid name
    NSString* existingValue = [doseTextValues objectForKey:name];
    if (existingValue)
    {
        [doseTextValues setObject:value forKey:name];
        return YES;
    }
    else
        return NO;
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity
{
	return nil;
}

// Returns the unit for the given quantity, if it exists
- (BOOL)getUnit:(NSString**)unit forDoseQuantity:(NSString*)name
{
	*unit = nil;
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	if (quantity)
	{
		*unit = quantity.unit;
		return YES;
	}
	else
		return NO;	
}

// Sets the unit for the given quantity, if it exists
- (BOOL)setUnit:(NSString*)unit forDoseQuantity:(NSString*)name
{	
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	if (quantity)
	{
		quantity.unit = unit;
		
		// Make sure unit is consistent between remaining & refill quantities
		NSString* quantityNameToDecrementRemainingQuantity = [self getDoseQuantityToDecrementRemainingQuantity];
		if (quantityNameToDecrementRemainingQuantity && [name caseInsensitiveCompare:quantityNameToDecrementRemainingQuantity] == NSOrderedSame)
		{
			remainingQuantity.unit = unit;
			refillQuantity.unit = unit;
		}

		return YES;
	}
	else
		return NO;		
}

// Performs a refill and returns whether successful
- (BOOL)performRefill
{
	if (![self isValidValueForRefillQuantity])
		return NO;
		
	remainingQuantity.value += refillQuantity.value;
	
	// Make sure we don't exceed the maximum allowable value.
	int sigDigits = 0;
	int numDecimals = 0;
	BOOL displayNone = NO;
	BOOL allowZero = NO;
	[self getRemainingQuantityUISettings:&sigDigits
							 numDecimals:&numDecimals
							 displayNone:&displayNone
							   allowZero:&allowZero];
	
	float maxValue = powf(10.0f, sigDigits-numDecimals)-1.0f;
	if (remainingQuantity.value > maxValue)
		remainingQuantity.value = maxValue;
    
    // Update the refills remaining
    if (refillsRemaining > 0)
        refillsRemaining -= 1;
    
	return YES;
}

// Returns the quantity consumed when a dose is taken
- (BOOL)getTakeDoseQuantity:(float*)quantity
{
    *quantity = 0.0f;
	NSString* quantityName = [self getDoseQuantityToDecrementRemainingQuantity];
	if (quantityName && ![self isValidValueForDoseQuantity:quantityName])
		return NO;
	
	*quantity = 1.0f;	
	if (quantityName)
		[self getValue:quantity forDoseQuantity:quantityName];
	
	return YES;
}

// Returns the number of remaining doses left
- (BOOL)getRemainingDoses:(float*)remainingDoses
{
	float takeDoseQuantity;
	if (![self getTakeDoseQuantity:&takeDoseQuantity] || takeDoseQuantity < epsilon)
		return NO;
	
    double remainingQuantityVal = remainingQuantity.value;
    if (remainingQuantityVal < epsilon)
        remainingQuantityVal = 0.0;
    
	double result = remainingQuantityVal / ((double)takeDoseQuantity);
	*remainingDoses = result;
	return YES;
}

// Returns an array of possible units for the given quantity, if it exists
- (NSArray*)possibleUnitsForDoseQuantity:(NSString*)name
{
	DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
	if (quantity)
	{
		return quantity.possibleUnits;
	}
	else
		return nil;			
}

// Returns an array of possible units for the remaining quantity
- (NSArray*)possibleUnitsForRemainingQuantity
{
	return remainingQuantity.possibleUnits;
}

// Returns an array of possible units for the refill quantity
- (NSArray*)possibleUnitsForRefillQuantity
{
	return refillQuantity.possibleUnits;
}

+ (NSString*)getTrimmedValueAsString:(float)val maxNumDecimals:(int)maxNumDecimals
{		
	// Calculate whether we can remove trailing zeroes for display
	int decimalsToSearch = maxNumDecimals;
	if (decimalsToSearch == 0)
		decimalsToSearch = 1;
	NSString* initialFormatStr = [NSString stringWithFormat:@"%%.%df", decimalsToSearch];
	NSString* valStr = [NSString stringWithFormat:initialFormatStr, val];			
	int numDecimalsToIgnore = 0;
	BOOL foundNonZeroDigit = NO;
	NSRange decRange = [valStr rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
	int decPointLoc = (int)decRange.location;

	for (int pos = (int)[valStr length]-1; pos > decPointLoc && !foundNonZeroDigit; pos--)
	{
		NSString* digitStr = [valStr substringWithRange:NSMakeRange(pos, 1)];
		if ([digitStr intValue] == 0)
			numDecimalsToIgnore += 1;
		else
			foundNonZeroDigit = YES;
	}
	
	int numDecimals = decimalsToSearch-numDecimalsToIgnore;
	if (numDecimals > maxNumDecimals)
		numDecimals = maxNumDecimals;
	
	NSString* formatStr = [NSString stringWithFormat:@"%%.%df", numDecimals];
    NSString* result = [NSString stringWithFormat:formatStr, val];
    // Use locale to determine whether to use '.' or ',' as the decimal separator
    return [result stringByReplacingOccurrencesOfString:@"." withString:[DosecastUtil getDecimalSeparator]];
}

// Extracts the floating point value from the given string and trims it as much as possible, recomposing the string (including the units)
+ (NSString*)getTrimmedValueInStringAsString:(NSString*)string maxNumDecimals:(int)maxNumDecimals
{
    if (!string || [string length] == 0)
        return nil;
    
	float val;
    NSString* unit = nil;
    [DrugDosage getQuantityFromString:string val:&val unit:&unit];
    
    NSMutableString* result = [NSMutableString stringWithString:[DrugDosage getTrimmedValueAsString:val maxNumDecimals:maxNumDecimals]];
    if (unit)
        [result appendFormat:@" %@", unit];
    return result;
}

// Returns the label for the given unit
+ (NSString*)getLabelForUnit:(NSString*)unit pluralize:(BOOL)pluralize
{	
    return [[DrugDosageUnitManager getInstance] getLocalizedDrugDosageUnit:unit pluralize:pluralize];
}

// Returns the string description for the given quantity and unit
+ (NSString*)getStringFromQuantity:(float)val
							  unit:(NSString*)unit
						  numDecimals:(int)numDecimals
{
    NSString* formatStr = [NSString stringWithFormat:@"%%.%df", numDecimals];		
	NSMutableString* quantityStr = [NSMutableString stringWithFormat:formatStr, val];
		
    if (unit && [unit length] > 0)
        [quantityStr appendFormat:@" %@", unit]; 
		
	return quantityStr;
}

// Returns a string that describes the refill quantity
+ (NSString*)getDescriptionForQuantity:(float)val
                                  unit:(NSString*)unit
                           numDecimals:(int)numDecimals
{
    NSMutableString* descrip = [NSMutableString stringWithString:[DrugDosage getTrimmedValueAsString:val maxNumDecimals:numDecimals]];
    
    if (unit)
    {
        BOOL pluralizeUnits = ![DosecastUtil shouldUseSingularForFloat:val];
        NSString* thisUnit = [DrugDosage getLabelForUnit:unit pluralize:pluralizeUnits];
        if (thisUnit && [thisUnit length] > 0)
            [descrip appendFormat:@" %@", thisUnit];
    }
    return descrip;
}

// Write the given quantity into the given dictionary
- (void)populateDictionaryForDoseQuantity:(NSMutableDictionary*)dict
						 quantityName:(NSString*)quantityName
								  key:(NSString*)key
						  numDecimals:(int)numDecimals
						  alwaysWrite:(BOOL)alwaysWrite
{
	if (!dict || !quantityName || !key)
		return;
	
	float val;
	[self getValue:&val forDoseQuantity:quantityName];
	NSString* unit;
	[self getUnit:&unit forDoseQuantity:quantityName];

	NSMutableString* quantityStr = [NSMutableString stringWithString:@""];
	if (alwaysWrite || val > epsilon)
	{
		[quantityStr appendString:[DrugDosage getStringFromQuantity:val unit:unit numDecimals:numDecimals]];
	}
		
    [Preferences populatePreferenceInDictionary:dict key:key value:quantityStr modifiedDate:nil perDevice:NO];
}

// Write the remaining and refill quantities into the given dictionary
- (void)populateDictionaryForRemainingQuantity:(NSMutableDictionary*)dict numDecimals:(int)numDecimals
{
	if (!dict)
		return;
		
    NSString* quantityStr = [DrugDosage getStringFromQuantity:remainingQuantity.value unit:remainingQuantity.unit numDecimals:numDecimals];
	
    [Preferences populatePreferenceInDictionary:dict key:RemainingQuantityKey value:quantityStr modifiedDate:nil perDevice:NO];
}

- (void)populateDictionaryForRefillQuantity:(NSMutableDictionary*)dict numDecimals:(int)numDecimals
{
	if (!dict)
		return;
		
	NSMutableString* quantityStr = [NSMutableString stringWithString:@""];
	if (refillQuantity.value > epsilon)
	{
		[quantityStr appendString:[DrugDosage getStringFromQuantity:refillQuantity.value unit:refillQuantity.unit numDecimals:numDecimals]];
	}
	
    [Preferences populatePreferenceInDictionary:dict key:RefillQuantityKey value:quantityStr modifiedDate:nil perDevice:NO];
}

// Write the refills remaining into the given dictionary
- (void)populateDictionaryForRefillsRemaining:(NSMutableDictionary*)dict
{
    if (!dict)
        return;
    
    NSString* refillsRemainingStr = [NSString stringWithFormat:@"%d", refillsRemaining];
    [Preferences populatePreferenceInDictionary:dict key:RefillsRemainingKey value:refillsRemainingStr modifiedDate:nil perDevice:NO];
}

// Parses a quantity string to extract the value and unit
+ (void)getQuantityFromString:(NSString*)quantityStr
						  val:(float*)val
						 unit:(NSString**)unit
{
		*unit = nil;

		NSRange range = [quantityStr rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
		if (range.location == NSNotFound)
			*val = [quantityStr floatValue];
		else
		{
			NSString* quantityValStr = [quantityStr substringToIndex:range.location];			
			*val = [quantityValStr floatValue];
			*unit = [quantityStr substringFromIndex:(range.location+1)];
		}
	}
	
// Read a quantity from the given dictionary using the given key. Returns whether successful.
- (BOOL)readDoseQuantityFromDictionary:(NSMutableDictionary*)dict
							   key:(NSString*)key
							   val:(float*)val
							  unit:(NSString**)unit
{
	if (!dict || !key)
		return NO;

    NSString* quantityStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:key value:&quantityStr modifiedDate:nil perDevice:nil];
	if (quantityStr && [quantityStr length] > 0)
	{
		[DrugDosage getQuantityFromString:quantityStr val:val unit:unit];
		return YES;
	}
	else
		return NO;
}

// Read the remaining and refill quantities from the given dictionary. Returns whether successful.
- (BOOL)readRemainingQuantityFromDictionary:(NSMutableDictionary*)dict
										val:(float*)val
									   unit:(NSString**)unit
{
	if (!dict)
		return NO;
	
    NSString* quantityStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:RemainingQuantityKey value:&quantityStr modifiedDate:nil perDevice:nil];
	if (quantityStr && [quantityStr length] > 0)
	{
		[DrugDosage getQuantityFromString:quantityStr val:val unit:unit];
		return YES;
	}	
	else
		return NO;
}

- (BOOL)readRefillQuantityFromDictionary:(NSMutableDictionary*)dict
									 val:(float*)val
									unit:(NSString**)unit
{
	if (!dict)
		return NO;
	
    NSString* quantityStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:RefillQuantityKey value:&quantityStr modifiedDate:nil perDevice:nil];
	if (quantityStr && [quantityStr length] > 0)
	{
		[DrugDosage getQuantityFromString:quantityStr val:val unit:unit];
		return YES;
	}		
	else
		return NO;
}

// Read the refills remaining from the given dictionary. Returns whether successful.
- (BOOL) readRefillsRemainingFromDictionary:(NSMutableDictionary*)dict
                           refillsRemaining:(int*)left
{
    if (!dict)
        return NO;
    
    NSString* refillsRemainingStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:RefillsRemainingKey value:&refillsRemainingStr modifiedDate:nil perDevice:nil];
	if (refillsRemainingStr)
	{
        *left = [refillsRemainingStr intValue];
		return YES;
	}		
	else
		return NO;
}

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name
{
	return nil;
}

// Returns the label for the given picklist
- (NSString*)getLabelForDosePicklist:(NSString*)name
{
	return nil;
}

// Returns the label for the given text value
- (NSString*)getLabelForDoseTextValue:(NSString *)name
{
    return nil;
}

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity
{
	return nil;
}

- (NSString*)getLabelForRefillQuantity
{
	return nil;
}

// Returns a string that describes the dose quantity
- (NSString*)getDescriptionForDoseQuantity:(NSString*)name maxNumDecimals:(int)maxNumDecimals
{
	if ([self isValidValueForDoseQuantity:name])
	{
		DrugDosageQuantity* quantity = [doseQuantities objectForKey:name];
		NSMutableString* descrip = [NSMutableString stringWithString:[DrugDosage getTrimmedValueAsString:quantity.value maxNumDecimals:maxNumDecimals]];
		
		if (quantity.unit)
		{
			BOOL pluralizeUnits = ![DosecastUtil shouldUseSingularForFloat:quantity.value];
            NSString* unit = [DrugDosage getLabelForUnit:quantity.unit pluralize:pluralizeUnits];
            if (unit && [unit length] > 0)
                [descrip appendFormat:@" %@", unit];
		}
		return descrip;
	}
	else
		return nil;
}

// Returns a string that describes the remaining quantity
- (NSString*)getDescriptionForRemainingQuantity:(int)maxNumDecimals
{
    float remainingQuantityVal = remainingQuantity.value;
    if (remainingQuantityVal < epsilon)
        remainingQuantityVal = 0.0f; // don't display negative values
    NSMutableString* descrip = [NSMutableString stringWithString:[DrugDosage getTrimmedValueAsString:remainingQuantityVal maxNumDecimals:maxNumDecimals]];
    
    if (remainingQuantity.unit)
    {
        BOOL pluralizeUnits = ![DosecastUtil shouldUseSingularForFloat:remainingQuantityVal];
        NSString* unit = [DrugDosage getLabelForUnit:remainingQuantity.unit pluralize:pluralizeUnits];
        if (unit && [unit length] > 0)
            [descrip appendFormat:@" %@", unit];
    }
    return descrip;
}

// Returns a string that describes the refill quantity
- (NSString*)getDescriptionForRefillQuantity:(int)maxNumDecimals
{
    if ([self isValidValueForRefillQuantity])
    {
        NSMutableString* descrip = [NSMutableString stringWithString:[DrugDosage getTrimmedValueAsString:refillQuantity.value maxNumDecimals:maxNumDecimals]];
        
        if (refillQuantity.unit)
        {
            BOOL pluralizeUnits = ![DosecastUtil shouldUseSingularForFloat:refillQuantity.value];
            NSString* unit = [DrugDosage getLabelForUnit:refillQuantity.unit pluralize:pluralizeUnits];
            if (unit && [unit length] > 0)
                [descrip appendFormat:@" %@", unit];
        }
        return descrip;
    }
    else
        return nil;
}

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName
{
	return nil;
}

// Returns the value for the remaining quantity
- (BOOL)getValueForRemainingQuantity:(float*)value
{
	*value = remainingQuantity.value;
	return YES;
}

// Sets the value for the remaining quantity
- (BOOL)setValueForRemainingQuantity:(float)value
{
	remainingQuantity.value = value;
	return YES;
}

// Returns the value for the refill quantity
- (BOOL)getValueForRefillQuantity:(float*)value
{
	*value = refillQuantity.value;
	return YES;
}

// Returns if the value is valid for the refill quantity
- (BOOL)isValidValueForRefillQuantity
{
    return ([refillQuantity isValidValue]);
}

// Sets the value for the refill quantity
- (BOOL)setValueForRefillQuantity:(float)value
{
	refillQuantity.value = value;
	return YES;
}

// Returns the unit for the remaining quantity
- (BOOL)getUnitForRemainingQuantity:(NSString**)unit
{
	*unit = remainingQuantity.unit;
	return YES;
}

// Sets the unit for the remaining quantity
- (BOOL)setUnitForRemainingQuantity:(NSString*)unit
{
	// Make sure unit is consistent between remaining & refill quantities
	NSString* quantityNameToDecrementRemainingQuantity = [self getDoseQuantityToDecrementRemainingQuantity];
	if (quantityNameToDecrementRemainingQuantity)
	{
		DrugDosageQuantity* quantity = [doseQuantities objectForKey:quantityNameToDecrementRemainingQuantity];
		if (quantity)
			quantity.unit = unit;
	}	

	refillQuantity.unit = unit;
	remainingQuantity.unit = unit;
	return YES;
}

// Returns the unit for the refill quantity
- (BOOL)getUnitForRefillQuantity:(NSString**)unit
{
	*unit = refillQuantity.unit;
	return YES;
}

// Sets the unit for the refill quantity
- (BOOL)setUnitForRefillQuantity:(NSString*)unit
{
	// Make sure unit is consistent between remaining & refill quantities
	NSString* quantityNameToDecrementRemainingQuantity = [self getDoseQuantityToDecrementRemainingQuantity];
	if (quantityNameToDecrementRemainingQuantity)
	{
		DrugDosageQuantity* quantity = [doseQuantities objectForKey:quantityNameToDecrementRemainingQuantity];
		if (quantity)
			quantity.unit = unit;
	}	
	
	remainingQuantity.unit = unit;
	refillQuantity.unit = unit;
	return YES;
}


@end
