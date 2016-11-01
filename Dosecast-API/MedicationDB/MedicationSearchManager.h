//
//  MedicationSearchManager.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 9/6/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MedicationConstants.h"

@class NSManagedObjectModel;
@class NSManagedObjectContext;
@class NSPersistentStoreCoordinator;
@class Medication;

@interface MedicationSearchManager : NSObject
{
    NSManagedObjectContext *_managedObjectContext;
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    BOOL _isDebugOn;
    BOOL _shouldReturnResults;
    dispatch_queue_t _medSearchQueue;
    NSString *_searchString;
    NSString *_searchTypeString;
    NSMutableArray* cachedMedicationRoutes;
    NSMutableDictionary* cachedStrengthUnits;
    NSMutableDictionary* cachedDoseAmountUnits;
    NSMutableDictionary* cachedMedicationLocations;
}

//Property for tracking if Debug is on; only available if build is DEBUG
@property(nonatomic, readonly) BOOL isDebugOn;

//CoreData Utilities
@property (nonatomic, strong, readonly) NSManagedObjectModel* managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator* persistentStoreCoordinator;
@property (nonatomic, strong, readonly) NSManagedObjectContext* managedObjectContext;


//Used by the search controller to search for a medication name
-(void) searchForMedicationName:(NSString *)medicationName withSearchType:(MedicationSearchType)searchType  completionBlock:(void (^)(NSArray *resultsArray)) block;

//Used to cancel any running search of searchForMedicationName
-(void)cancelMedicationNameSearch;

//Used by the search results table view when a medication name is selected, this returns an array with all of the Medication.h's that match a name and type
-(void) getMedicationsWithMedicationName:(NSString *)medicationName
                withMedicationTypeString: (NSString *)medSearchTypeString
                         completionBlock:(void (^)(NSArray *resultsArray)) block;

//Asynchronously obtain the list of possible drug types from the database
-(void) getMedicationTypesWithCompletionBlock:(void(^)(NSArray *resultsArray)) block;
-(NSArray *) getMedicationTypes;

//Asynchronously obtain the list of possible drug routes from the database
-(void) getMedicationRoutesWithCompletionBlock:(void(^)(NSArray *resultsArray)) block;
-(NSArray *) getMedicationRoutes;

//Asynchronously obtain the list of possible strength units for a particular drug type from the database
-(void) getStrengthUnitsForFormType:(NSString *)formType withCompletionBlock:(void(^)(NSArray *resultsArray)) block;
-(NSArray *) getStrengthUnitsForFormType:(NSString *)formType;

//Asynchronously obtain the list of possible amount units for a particular drug type from the database
-(void) getDoseAmountUnitsForFormType:(NSString *)formType withCompletionBlock:(void(^)(NSArray *resultsArray)) block;
-(NSArray *) getDoseAmountUnitsForFormType:(NSString *)formType;

//Get locations
-(NSArray *) getMedicationLocationsForFormType:(NSString *) formType;

+(MedicationSearchManager *)sharedManager;

@end
