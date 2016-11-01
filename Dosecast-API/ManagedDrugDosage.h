//
//  ManagedDrugDosage.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/29/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DrugDosage.h"

@interface ManagedDrugDosage : DrugDosage
{
@private
    NSString* ndc;         // The drug NDC code
    NSString* lastUserNotificationTime; // The last time that the user was notified of the change to the drug made by an external system
    NSString* lastManagedUpdateTime; // The last time that the drug was updated by an external system
    BOOL isDiscontinued;
}

- (id)initWithDoseQuantities:(NSMutableDictionary*)quantities
	 withDosePicklistOptions:(NSMutableDictionary*)picklistOptions
	  withDosePicklistValues:(NSMutableDictionary*)picklistValues
          withDoseTextValues:(NSMutableDictionary*)textValues
	   withRemainingQuantity:(DrugDosageQuantity*)remaining
		  withRefillQuantity:(DrugDosageQuantity*)refill
        withRefillsRemaining:(int)left;

              - (id)init:(NSString*)dosageDescription
                     ndc:(NSString*)ndc
lastUserNotificationTime:(NSString*)lastNotificationTime
   lastManagedUpdateTime:(NSString*)lastUpdateTime
          isDiscontinued:(BOOL)discontinued
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

// Returns the total number of inputs for this dosage
- (int) numDoseInputs;

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

// Returns all the UI settings for the text value with the given input number
- (BOOL) getDoseTextValueUISettingsForInput:(int)inputNum
                              textValueName:(NSString**)textValueName
                                displayNone:(BOOL*)displayNone;

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

- (BOOL) requiresUserNotification; // If an existing managed med has been edited by an external system and the user needs to be notified
- (BOOL) isNew;                    // If a new managed med has been added by an external system and the user needs to be notified
- (void) markAsUserNotified;       // If the user has been notified after an existing managed med has been edited or a new managed med has been added by an external system

@property (nonatomic, readonly) NSString *ndc;
@property (nonatomic, assign) BOOL isDiscontinued;

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
+ (NSString*)getDoseQuantityToDecrementRemainingQuantity;

@end
