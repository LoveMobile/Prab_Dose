//
//  DrugDosage.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"

typedef enum {
	DrugDosageInputTypeQuantity	= 0,
	DrugDosageInputTypePicklist	= 1,
    DrugDosageInputTypeText     = 2
} DrugDosageInputType;

@class DrugDosageQuantity;

@interface DrugDosage : NSObject<NSMutableCopying>
{
@protected
	NSMutableDictionary* doseQuantities;
	NSMutableDictionary* dosePicklistOptions;
	NSMutableDictionary* dosePicklistValues;
    NSMutableDictionary* doseTextValues;
	DrugDosageQuantity* remainingQuantity;
	DrugDosageQuantity* refillQuantity;
@private
    int refillsRemaining;
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
             withRefillsRemaining:(int)left;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Parses a quantity string to extract the value and unit
+ (void)getQuantityFromString:(NSString*)quantityStr
						  val:(float*)val
						 unit:(NSString**)unit;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Returns a string that describes the dose type
- (NSString*)getTypeName;

// Returns a string that describes the dose type
- (NSString*)getFileTypeName;

// Returns dictionary of dose data
- (NSDictionary*) getDoseData;

// Returns an array of quantity names, each of which may be used as a key to get/set the value and unit
- (NSArray*)doseQuantityNames;

// Returns an array of picklist names, each of which may be used as a key to get/set the value
- (NSArray*)dosePicklistNames;

// Returns an array of text value names, each of which may be used as a key to get/set the value
- (NSArray*)doseTextValueNames;

// Returns the number of quantities
- (int) numDoseQuantities;

// Returns the number of picklists
- (int) numDosePicklists;

// Returns the number of text values
- (int) numDoseTextValues;

// Returns the total number of inputs for this dosage
- (int) numDoseInputs;

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*)getDoseQuantityToDecrementRemainingQuantity;

// Extracts the floating point value from the given string and trims it as much as possible, recomposing the string (including the units)
+ (NSString*)getTrimmedValueInStringAsString:(NSString*)string maxNumDecimals:(int)maxNumDecimals;

// Returns the input type for the given input number
- (DrugDosageInputType) getDoseInputTypeForInput:(int)inputNum;

// Returns all the UI settings for the quantity with the given input number
- (BOOL) getDoseQuantityUISettingsForInput:(int)inputNum
						  quantityName:(NSString**)quantityName
							 sigDigits:(int*)sigDigits
						   numDecimals:(int*)numDecimals
						   displayNone:(BOOL*)displayNone
							 allowZero:(BOOL*)allowZero;

// Returns all the UI settings for the remaining quantity
- (BOOL) getRemainingQuantityUISettings:(int*)sigDigits
							   numDecimals:(int*)numDecimals
							   displayNone:(BOOL*)displayNone
								 allowZero:(BOOL*)allowZero;

// Returns all the UI settings for the refill quantity
- (BOOL) getRefillQuantityUISettings:(int*)sigDigits
							numDecimals:(int*)numDecimals
							displayNone:(BOOL*)displayNone
							  allowZero:(BOOL*)allowZero;

// Returns all the UI settings for the picklist with the given input number
- (BOOL) getDosePicklistUISettingsForInput:(int)inputNum
						  picklistName:(NSString**)picklistName
						   displayNone:(BOOL*)displayNone;

// Returns all the UI settings for the text value with the given input number
- (BOOL) getDoseTextValueUISettingsForInput:(int)inputNum
                              textValueName:(NSString**)textValueName
                                displayNone:(BOOL*)displayNone;

// Accessors for refills remaining
- (int)getRefillsRemaining;
- (void)setRefillsRemaining:(int)left;

// Returns the value for the given quantity, if it exists
- (BOOL)getValue:(float*)value forDoseQuantity:(NSString*)name;

// Returns if the value is valid for the given quantity
- (BOOL)isValidValueForDoseQuantity:(NSString*)name;

// Sets the value for the given quantity, if it exists
- (BOOL)setValue:(float)value forDoseQuantity:(NSString*)name;

// Returns the options for the given picklist, if it exists
- (NSArray*)possibleOptionsForDosePicklist:(NSString*)name;

// Returns the value for the given picklist, if it exists
- (NSString*) getValueForDosePicklist:(NSString*)name;

// Returns if the value is valid for the given picklist
- (BOOL)isValidValueForDosePicklist:(NSString*)name;

// Sets the value for the given picklist, if it exists
- (BOOL)setValue:(NSString*)value forDosePicklist:(NSString*)name;

// Returns the value for the given text value, if it exists
- (NSString*) getValueForDoseTextValue:(NSString*)name;

// Returns if the value is valid for the given text value
- (BOOL)isValidValueForDoseTextValue:(NSString*)name;

// Sets the value for the given text value, if it exists
- (BOOL)setValue:(NSString*)value forDoseTextValue:(NSString*)name;

// Returns the unit for the given quantity, if it exists
- (BOOL)getUnit:(NSString**)unit forDoseQuantity:(NSString*)name;

// Sets the unit for the given quantity, if it exists
- (BOOL)setUnit:(NSString*)unit forDoseQuantity:(NSString*)name;

// Returns the value for the remaining quantity
- (BOOL)getValueForRemainingQuantity:(float*)value;

// Sets the value for the remaining quantity
- (BOOL)setValueForRemainingQuantity:(float)value;

// Returns the value for the refill quantity
- (BOOL)getValueForRefillQuantity:(float*)value;

// Returns if the value is valid for the refill quantity
- (BOOL)isValidValueForRefillQuantity;

// Sets the value for the refill quantity
- (BOOL)setValueForRefillQuantity:(float)value;

// Returns the unit for the remaining quantity
- (BOOL)getUnitForRemainingQuantity:(NSString**)unit;

// Sets the unit for the remaining quantity
- (BOOL)setUnitForRemainingQuantity:(NSString*)unit;

// Returns the unit for the refill quantity
- (BOOL)getUnitForRefillQuantity:(NSString**)unit;

// Sets the unit for the refill quantity
- (BOOL)setUnitForRefillQuantity:(NSString*)unit;

// Performs a refill and returns whether successful
- (BOOL)performRefill;

// Returns the quantity consumed when a dose is taken
- (BOOL)getTakeDoseQuantity:(float*)quantity;

// Returns the number of remaining doses left
- (BOOL)getRemainingDoses:(float*)remainingDoses;

// Returns an array of possible units for the given quantity, if it exists
- (NSArray*)possibleUnitsForDoseQuantity:(NSString*)name;

// Returns an array of possible units for the remaining quantity
- (NSArray*)possibleUnitsForRemainingQuantity;

// Returns an array of possible units for the refill quantity
- (NSArray*)possibleUnitsForRefillQuantity;

// Returns a string that describes the dose quantity
- (NSString*)getDescriptionForDoseQuantity:(NSString*)name maxNumDecimals:(int)maxNumDecimals;

// Returns a string that describes the remaining quantity
- (NSString*)getDescriptionForRemainingQuantity:(int)maxNumDecimals;

// Returns a string that describes the refill quantity
- (NSString*)getDescriptionForRefillQuantity:(int)maxNumDecimals;

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName;

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name;

// Returns the label for the given picklist
- (NSString*)getLabelForDosePicklist:(NSString*)name;

// Returns the label for the given text value
- (NSString*)getLabelForDoseTextValue:(NSString*)name;

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity;
- (NSString*)getLabelForRefillQuantity;

// Returns the label for the given unit
+ (NSString*)getLabelForUnit:(NSString*)unit pluralize:(BOOL)pluralize;

// Write the given quantity into the given dictionary
- (void)populateDictionaryForDoseQuantity:(NSMutableDictionary*)dict
						 quantityName:(NSString*)quantityName
								  key:(NSString*)key
						  numDecimals:(int)numDecimals
						  alwaysWrite:(BOOL)alwaysWrite;

// Write the remaining and refill quantities into the given dictionary
- (void)populateDictionaryForRemainingQuantity:(NSMutableDictionary*)dict numDecimals:(int)numDecimals;
- (void)populateDictionaryForRefillQuantity:(NSMutableDictionary*)dict numDecimals:(int)numDecimals;

// Write the refills remaining into the given dictionary
- (void)populateDictionaryForRefillsRemaining:(NSMutableDictionary*)dict;

// Read a quantity from the given dictionary using the given key. Returns whether successful.
- (BOOL)readDoseQuantityFromDictionary:(NSMutableDictionary*)dict
							   key:(NSString*)key
							   val:(float*)val
							  unit:(NSString**)unit;

// Read the remaining and refill quantities from the given dictionary. Returns whether successful.
- (BOOL)readRemainingQuantityFromDictionary:(NSMutableDictionary*)dict
										val:(float*)val
									   unit:(NSString**)unit;
- (BOOL)readRefillQuantityFromDictionary:(NSMutableDictionary*)dict
									 val:(float*)val
									unit:(NSString**)unit;

// Read the refills remaining from the given dictionary. Returns whether successful.
- (BOOL) readRefillsRemainingFromDictionary:(NSMutableDictionary*)dict
                           refillsRemaining:(int*)left;

// Returns the string description for the given quantity and unit
+ (NSString*)getStringFromQuantity:(float)val
							  unit:(NSString*)unit
					   numDecimals:(int)numDecimals;

// Returns a string that describes the refill quantity
+ (NSString*)getDescriptionForQuantity:(float)val
                                  unit:(NSString*)unit
                           numDecimals:(int)numDecimals;

@end
