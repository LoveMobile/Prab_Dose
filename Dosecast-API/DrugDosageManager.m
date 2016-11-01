//
//  DrugDosageManager.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDosageManager.h"
#import "DrugDosageManagerEntry.h"
#import "DataModel.h"
#import "CustomNameIDList.h"
#import "CustomDrugDosage.h"
#import "DropDrugDosage.h"
#import "InhalerDrugDosage.h"
#import "InjectionDrugDosage.h"
#import "LiquidDrugDosage.h"
#import "SprayDrugDosage.h"
#import "OintmentDrugDosage.h"
#import "PatchDrugDosage.h"
#import "PillDrugDosage.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DosecastUtil.h"
#import "DatabaseDrugDosage.h"
#import "MedFormType.h"
#import "MedicationSearchManager.h"
#import "ManagedDrugDosage.h"
#import "CapletDrugDosage.h"
#import "CapsuleDrugDosage.h"
#import "TabletDrugDosage.h"
#import "InfusionDrugDosage.h"
#import "SuppositoryDrugDosage.h"
#import "PowderDrugDosage.h"
#import "GlobalSettings.h"

static DrugDosageManager *gInstance = nil;

NSString *DrugDosageManagerDropDrugDosageTypeName = @"";
NSString *DrugDosageManagerInhalerDrugDosageTypeName = @"";
NSString *DrugDosageManagerInjectionDrugDosageTypeName = @"";
NSString *DrugDosageManagerLiquidDrugDosageTypeName = @"";
NSString *DrugDosageManagerManagedDrugDosageTypeName = @"";
NSString *DrugDosageManagerSprayDrugDosageTypeName = @"";
NSString *DrugDosageManagerOintmentDrugDosageTypeName = @"";
NSString *DrugDosageManagerPatchDrugDosageTypeName = @"";
NSString *DrugDosageManagerPillDrugDosageTypeName = @"";
NSString *DrugDosageManagerCapletDrugDosageTypeName = @"";
NSString *DrugDosageManagerCapsuleDrugDosageTypeName = @"";
NSString *DrugDosageManagerTabletDrugDosageTypeName = @"";
NSString *DrugDosageManagerInfusionDrugDosageTypeName = @"";
NSString *DrugDosageManagerSuppositoryDrugDosageTypeName = @"";
NSString *DrugDosageManagerPowderDrugDosageTypeName = @"";

static NSString *DefaultDatabaseStandardType = @"Tablet";

@implementation DrugDosageManager

@synthesize defaultTypeName;

- (BOOL) areUSDrugDatabaseTypesEnabled:(NSArray*)flags
{
    DataModel* dataModel = [DataModel getInstanceWithAPIFlags:flags];
    NSString* languageCountryCode = [DosecastUtil getLanguageCountryCode];
    return ([dataModel.apiFlags getFlag:DosecastAPIEnableUSDrugDatabaseTypes] && [languageCountryCode compare:@"en_US" options:NSLiteralSearch] == NSOrderedSame);
}

- (id)init
{
    return [self initWithAPIFlags:[[NSArray alloc] init]];
}

- (id)initWithAPIFlags:(NSArray*)flags
{
    if ((self = [super init]))
    {
        DrugDosageManagerDropDrugDosageTypeName = [DropDrugDosage getTypeName];
        DrugDosageManagerInhalerDrugDosageTypeName = [InhalerDrugDosage getTypeName];
        DrugDosageManagerInjectionDrugDosageTypeName = [InjectionDrugDosage getTypeName];
        DrugDosageManagerLiquidDrugDosageTypeName = [LiquidDrugDosage getTypeName];
        DrugDosageManagerManagedDrugDosageTypeName = [ManagedDrugDosage getTypeName];
        DrugDosageManagerOintmentDrugDosageTypeName = [OintmentDrugDosage getTypeName];
        DrugDosageManagerPatchDrugDosageTypeName = [PatchDrugDosage getTypeName];
        DrugDosageManagerPillDrugDosageTypeName = [PillDrugDosage getTypeName];
        DrugDosageManagerSprayDrugDosageTypeName = [SprayDrugDosage getTypeName];
        DrugDosageManagerCapletDrugDosageTypeName = [CapletDrugDosage getTypeName];
        DrugDosageManagerCapsuleDrugDosageTypeName = [CapsuleDrugDosage getTypeName];
        DrugDosageManagerTabletDrugDosageTypeName = [TabletDrugDosage getTypeName];
        DrugDosageManagerInfusionDrugDosageTypeName = [InfusionDrugDosage getTypeName];
        DrugDosageManagerSuppositoryDrugDosageTypeName = [SuppositoryDrugDosage getTypeName];
        DrugDosageManagerPowderDrugDosageTypeName = [PowderDrugDosage getTypeName];
        
		drugDosageTypeNameDict = [[NSMutableDictionary alloc] init];
        drugDosageFileTypeNameDict = [[NSMutableDictionary alloc] init];
        standardTypeNames = [[NSMutableArray alloc] init];
		defaultTypeName = [[NSMutableString alloc] initWithString:@""];

        // Register file file loading & instantiation of managed drug dosages
        [self registerDrugDosageWithFileTypeName:[ManagedDrugDosage class] fileTypeName:[ManagedDrugDosage getFileTypeName]];
        [self registerDrugDosageWithTypeName:[ManagedDrugDosage class] typeName:DrugDosageManagerManagedDrugDosageTypeName];

        // Register file loading of custom drug dosages
        [self registerDrugDosageWithFileTypeName:[CustomDrugDosage class] fileTypeName:[CustomDrugDosage getFileTypeName]];

        // Register file loading of database drug dosages
        [self registerDrugDosageWithFileTypeName:[DatabaseDrugDosage class] fileTypeName:[DatabaseDrugDosage getFileTypeName]];
        
        NSMutableArray *standardNames = [[NSMutableArray alloc] init];
        NSString* defaultType = nil;
        
        // Register all manually created drug dosages
        if ([self areUSDrugDatabaseTypesEnabled:flags])
        {
            // Register all database mapped drug forms
            NSArray *medFormTypes = [[MedicationSearchManager sharedManager] getMedicationTypes];
            [medFormTypes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                MedFormType *formType=(MedFormType *)obj;
                [standardNames addObject:formType.medFormType];
                [self registerDrugDosageWithTypeName:[DatabaseDrugDosage class] typeName:formType.medFormType];
            }];
            
            defaultType = DefaultDatabaseStandardType;
        }
        else
        {
            [self registerDrugDosageWithTypeName:[DropDrugDosage class] typeName:DrugDosageManagerDropDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[DropDrugDosage class] fileTypeName:[DropDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerDropDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[InhalerDrugDosage class] typeName:DrugDosageManagerInhalerDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[InhalerDrugDosage class] fileTypeName:[InhalerDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerInhalerDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[InjectionDrugDosage class] typeName:DrugDosageManagerInjectionDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[InjectionDrugDosage class] fileTypeName:[InjectionDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerInjectionDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[LiquidDrugDosage class] typeName:DrugDosageManagerLiquidDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[LiquidDrugDosage class] fileTypeName:[LiquidDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerLiquidDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[OintmentDrugDosage class] typeName:DrugDosageManagerOintmentDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[OintmentDrugDosage class] fileTypeName:[OintmentDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerOintmentDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[PatchDrugDosage class] typeName:DrugDosageManagerPatchDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[PatchDrugDosage class] fileTypeName:[PatchDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerPatchDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[PillDrugDosage class] typeName:DrugDosageManagerPillDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[PillDrugDosage class] fileTypeName:[PillDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerPillDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[SprayDrugDosage class] typeName:DrugDosageManagerSprayDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[SprayDrugDosage class] fileTypeName:[SprayDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerSprayDrugDosageTypeName];

            // English-only standard drug types
            NSString* languageCode = [DosecastUtil getLanguageCode];
            if ([languageCode compare:@"en" options:NSLiteralSearch] == NSOrderedSame)
            {
                [self registerDrugDosageWithTypeName:[CapletDrugDosage class] typeName:DrugDosageManagerCapletDrugDosageTypeName];
                [self registerDrugDosageWithFileTypeName:[CapletDrugDosage class] fileTypeName:[CapletDrugDosage getFileTypeName]];
                [standardNames addObject:DrugDosageManagerCapletDrugDosageTypeName];
            }

            [self registerDrugDosageWithTypeName:[CapsuleDrugDosage class] typeName:DrugDosageManagerCapsuleDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[CapsuleDrugDosage class] fileTypeName:[CapsuleDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerCapsuleDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[TabletDrugDosage class] typeName:DrugDosageManagerTabletDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[TabletDrugDosage class] fileTypeName:[TabletDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerTabletDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[InfusionDrugDosage class] typeName:DrugDosageManagerInfusionDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[InfusionDrugDosage class] fileTypeName:[InfusionDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerInfusionDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[SuppositoryDrugDosage class] typeName:DrugDosageManagerSuppositoryDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[SuppositoryDrugDosage class] fileTypeName:[SuppositoryDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerSuppositoryDrugDosageTypeName];

            [self registerDrugDosageWithTypeName:[PowderDrugDosage class] typeName:DrugDosageManagerPowderDrugDosageTypeName];
            [self registerDrugDosageWithFileTypeName:[PowderDrugDosage class] fileTypeName:[PowderDrugDosage getFileTypeName]];
            [standardNames addObject:DrugDosageManagerPowderDrugDosageTypeName];

            defaultType = DrugDosageManagerPillDrugDosageTypeName;
        }
        
        [self setStandardTypeNames:standardNames defaultTypeName:defaultType];
    }
	
    return self;
}


// Singleton methods

+ (DrugDosageManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

+ (DrugDosageManager*) getInstanceWithAPIFlags:(NSArray*)flags
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] initWithAPIFlags:flags];
    }
    
    return(gInstance);
}

// All other methods

// Registers a drug dosage class with a given type name. Returns whether successful
- (BOOL) registerDrugDosageWithTypeName:(Class)c typeName:(NSString*)typeName
{
    if ([c isSubclassOfClass:[DrugDosage class]])
    {
        DrugDosageManagerEntry* entry = [[DrugDosageManagerEntry alloc] initWithClass:c];
        [drugDosageTypeNameDict setObject:entry forKey:typeName];
        return YES;
    }
    else
        return NO;
}

// Registers a drug dosage class with a given file type name. Returns whether successful
- (BOOL) registerDrugDosageWithFileTypeName:(Class)c fileTypeName:(NSString*)typeName
{
    if ([c isSubclassOfClass:[DrugDosage class]])
    {
        DrugDosageManagerEntry* entry = [[DrugDosageManagerEntry alloc] initWithClass:c];
        [drugDosageFileTypeNameDict setObject:entry forKey:typeName];
        return YES;
    }
    else
        return NO;
}

// Sets the list of standard type names
- (void) setStandardTypeNames:(NSArray*)typeNames defaultTypeName:(NSString*)defTypeName
{
    [standardTypeNames setArray:typeNames];
    [defaultTypeName setString:defTypeName];
}

// Returns a sorted list of drug dosage type names
- (NSArray*) getStandardTypeNames
{
    return standardTypeNames;
}

// Returns whether the given type name is standard
- (BOOL) isStandardTypeName:(NSString*)typeName
{
    return ([standardTypeNames indexOfObject:typeName] != NSNotFound);
}

- (DrugDosage*) createDrugDosageWithTypeName:(NSString*)typeName
{
    // Look for standard dosage types
	DrugDosageManagerEntry* entry = [drugDosageTypeNameDict objectForKey:typeName];
	if (entry)
	{
        DrugDosage* result = nil;
        
        if ([entry.dosageClass isSubclassOfClass:[DatabaseDrugDosage class]])
        {
            result = [[entry.dosageClass alloc] initWithDoseQuantities:nil
                                                            withDosePicklistOptions:nil
                                                             withDosePicklistValues:nil
                                                                 withDoseTextValues:nil
                                                              withRemainingQuantity:nil
                                                                 withRefillQuantity:nil
                                                               withRefillsRemaining:-1
                                                                        medFormType:typeName];            
        }
        else
        {  
            result = [[entry.dosageClass alloc] initWithDoseQuantities:nil
										  withDosePicklistOptions:nil
										   withDosePicklistValues:nil
                                               withDoseTextValues:nil
											withRemainingQuantity:nil
											   withRefillQuantity:nil
                                                  withRefillsRemaining:-1];
        }
        
        return result;
	}
	else
    {
        // Look for custom dosage types
        DataModel* dataModel = [DataModel getInstance];
        NSString* customDosageID = [dataModel.globalSettings.customDrugDosageNames guidForName:typeName];
        if (customDosageID)
        {
            return [[CustomDrugDosage alloc] init:customDosageID
                                 dosageDescription:nil
                                         remaining:0.0f
                                            refill:0.0f
                                  refillsRemaining:0];

        }
        else
            return nil;	
    }
}

- (DrugDosage*) createDrugDosageWithTypeName:(NSString*)typeName withDictionary:(NSMutableDictionary*) dict
{
    // Look for standard dosage types
	DrugDosageManagerEntry* entry = [drugDosageTypeNameDict objectForKey:typeName];
	if (entry)
	{
		return [[entry.dosageClass alloc] initWithDictionary:dict];
	}
	else
    {
        // Look for custom dosage types
        DataModel* dataModel = [DataModel getInstance];
        NSString* customDosageID = [dataModel.globalSettings.customDrugDosageNames guidForName:typeName];
        if (customDosageID)
        {
            return [[CustomDrugDosage alloc] initWithDictionary:dict];
        }
        else
            return nil;	
    }
}

- (DrugDosage*) createDrugDosageWithFileTypeName:(NSString*)fileTypeName withDictionary:(NSMutableDictionary*) dict
{
	DrugDosageManagerEntry* entry = [drugDosageFileTypeNameDict objectForKey:fileTypeName];
	if (entry)
	{
		return [[entry.dosageClass alloc] initWithDictionary:dict];
	}
	else
        return nil;	
}

// Get the description for a drug dose with the given dosage type
- (NSString*) getDescriptionForDrugDoseWithFileTypeName:(NSString*)fileTypeName drugName:(NSString*)drugName withDictionary:(NSDictionary*) dict
{
    if (!fileTypeName)
        return nil;

    DrugDosageManagerEntry* entry = [drugDosageFileTypeNameDict objectForKey:fileTypeName];
	if (entry)
	{
		return [entry.dosageClass getDescriptionForDrugDose:drugName doseData:dict];
	}
	else
        return nil;
}

// Returns the name of the dose quantity used to decrement the remaining quantity when a dose is taken
- (NSString*) getDoseQuantityToDecrementRemainingQuantityWithFileTypeName:(NSString*)fileTypeName
{
    if (!fileTypeName)
        return nil;
    
    DrugDosageManagerEntry* entry = [drugDosageFileTypeNameDict objectForKey:fileTypeName];
    if (entry)
    {
        return [entry.dosageClass getDoseQuantityToDecrementRemainingQuantity];
    }
    else
        return nil;
}

@end
