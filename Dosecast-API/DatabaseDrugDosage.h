//
//  DatabaseDrugDosage.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DrugDosage.h"

@interface DatabaseDrugDosage : DrugDosage
{
@private
    NSString* medForm;     // unmapped drug form
    NSString* medFormType; // mapped drug form
    NSString* medType;     // Either "Rx" or "OTC"
    NSString* ndc;         // The drug NDC code
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
        withRefillsRemaining:(int)left
                 medFormType:(NSString*)formType;

		   - (id)init:(NSString*)medForm
          medFormType:(NSString*)medFormType
              medType:(NSString*)medType
                  ndc:(NSString*)ndc
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
     refillsRemaining:(int)left;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Returns a string that describes the dose type
- (NSString*)getTypeName;

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

@property (nonatomic, readonly) NSString *medForm;
@property (nonatomic, readonly) NSString *medFormType;
@property (nonatomic, readonly) NSString *medType;
@property (nonatomic, readonly) NSString *ndc;

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity;

@end
