//
//  DrugDosageManager.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DrugDosage;

@interface DrugDosageManager : NSObject {
@private
	NSMutableDictionary* drugDosageTypeNameDict;
    NSMutableDictionary* drugDosageFileTypeNameDict;
    NSMutableArray* standardTypeNames;
	NSMutableString* defaultTypeName;
}

// Singleton methods
+ (DrugDosageManager*) getInstance;
+ (DrugDosageManager*) getInstanceWithAPIFlags:(NSArray*)flags;

// Registers a drug dosage class with a given type name. Returns whether successful
- (BOOL) registerDrugDosageWithTypeName:(Class)c typeName:(NSString*)typeName;

// Registers a drug dosage class with a given file type name. Returns whether successful
- (BOOL) registerDrugDosageWithFileTypeName:(Class)c fileTypeName:(NSString*)typeName;

// Returns a sorted list of drug dosage type names
- (NSArray*) getStandardTypeNames;

// Returns whether the given type name is standard
- (BOOL) isStandardTypeName:(NSString*)typeName;

// Sets the list of standard type names
- (void) setStandardTypeNames:(NSArray*)typeNames defaultTypeName:(NSString*)defTypeName;

// Instantiate Drug Dosage instances
- (DrugDosage*) createDrugDosageWithTypeName:(NSString*)typeName;
- (DrugDosage*) createDrugDosageWithTypeName:(NSString*)typeName withDictionary:(NSMutableDictionary*) dict;
- (DrugDosage*) createDrugDosageWithFileTypeName:(NSString*)fileTypeName withDictionary:(NSMutableDictionary*) dict;

// Get the description for a drug dose with the given dosage type
- (NSString*) getDescriptionForDrugDoseWithFileTypeName:(NSString*)fileTypeName drugName:(NSString*)drugName withDictionary:(NSDictionary*) dict;

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*) getDoseQuantityToDecrementRemainingQuantityWithFileTypeName:(NSString*)fileTypeName;

@property (nonatomic, readonly) NSString* defaultTypeName;

@end

// Built-in drug dosage type names
extern NSString *DrugDosageManagerDropDrugDosageTypeName;
extern NSString *DrugDosageManagerInhalerDrugDosageTypeName;
extern NSString *DrugDosageManagerInjectionDrugDosageTypeName;
extern NSString *DrugDosageManagerLiquidDrugDosageTypeName;
extern NSString *DrugDosageManagerManagedDrugDosageTypeName;
extern NSString *DrugDosageManagerSprayDrugDosageTypeName;
extern NSString *DrugDosageManagerOintmentDrugDosageTypeName;
extern NSString *DrugDosageManagerPatchDrugDosageTypeName;
extern NSString *DrugDosageManagerPillDrugDosageTypeName;
extern NSString *DrugDosageManagerCapletDrugDosageTypeName;
extern NSString *DrugDosageManagerCapsuleDrugDosageTypeName;
extern NSString *DrugDosageManagerTabletDrugDosageTypeName;
extern NSString *DrugDosageManagerInfusionDrugDosageTypeName;
extern NSString *DrugDosageManagerSuppositoryDrugDosageTypeName;
extern NSString *DrugDosageManagerPowderDrugDosageTypeName;
