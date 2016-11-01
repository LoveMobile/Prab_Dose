//
//  PillDrugDosage.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DrugDosage.h"

@interface PillDrugDosage : DrugDosage
{
@private
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
             withRefillsRemaining:(int)left;

	  - (id)init:(float)numPills
	pillStrength:(float)pillStrength
pillStrengthUnit:(NSString*)pillStrengthUnit
	   remaining:(float)remaining
		  refill:(float)refill
     refillsRemaining:(int)left;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Returns a string that describes the dose type
- (NSString*)getTypeName;

// Returns a string that describes the dose type
+ (NSString*)getTypeName;

// Returns a string that identifies this type
+ (NSString*)getFileTypeName;

// Returns a string that describes the dose type
- (NSString*)getFileTypeName;

// Returns a string that describes the dose for the given drug name
- (NSString*)getDescriptionForDrugDose:(NSString*)drugName;

// Returns a string that describes the dose for the given drug name and dose data (in key-value form)
+ (NSString*)getDescriptionForDrugDose:(NSString*)drugName doseData:(NSDictionary*)doseData;

// Returns dictionary of dose data
- (NSDictionary*) getDoseData;

// Returns the label for the given quantity
- (NSString*)getLabelForDoseQuantity:(NSString*)name;

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

// Returns the label for the remaining & refill quantities
- (NSString*)getLabelForRemainingQuantity;
- (NSString*)getLabelForRefillQuantity;

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity;

@end
