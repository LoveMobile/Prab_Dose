//
//  MedicationSearchManager.m
//  Dosecast-API
//
//  Created by Shawn Grimes on 9/6/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "MedicationSearchManager.h"
#import <CoreData/CoreData.h>
#import "DosecastUtil.h"
#import "HistoryManager.h"
#import "Medication.h"
#import "MedFormType.h"
#import "MedicationRoute.h"
#import "MedStrengthUnit.h"
#import "MedDoseUnit.h"
#import "PermutationSearchResult.h"

@implementation MedicationSearchManager
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator=_persistentStoreCoordinator;
@synthesize managedObjectContext=_managedObjectContext;



#pragma mark - Setup
+(MedicationSearchManager *)sharedManager{
    static dispatch_once_t pred;
    static id sharedManager = nil;
    
    dispatch_once( &pred, ^{
        sharedManager = [[[self class] alloc] init];
    });
    
    return sharedManager;
}

-(id) init{
    if((self=[super init])){
        //Turn DEBUG off by default, must be manually turned on
        _isDebugOn=NO;
        _medSearchQueue=createSearchQueue();
        cachedMedicationRoutes = [[NSMutableArray alloc] init];
        cachedStrengthUnits = [[NSMutableDictionary alloc] init];
        cachedDoseAmountUnits = [[NSMutableDictionary alloc] init];
        cachedMedicationLocations = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Current Search Parameters
//These properties allow you to set and retrieve the current search parameters (SearchType and String)
-(NSString *)currentSearchTypeString {
    @synchronized(self) {
        return [_searchTypeString copy];
    }
}

-(void)updateCurrentSearchType:(MedicationSearchType) newSearchType{
    @synchronized(self){
        //Get the string that represents the SearchType, either Rx or OTC
        NSString *newSearchTypeString=[self getSearchTypeStringForSearchType:newSearchType];
        if(newSearchTypeString != _searchTypeString){
            [self setCurrentSearchTypeString:newSearchTypeString];
        }
    }    
}

-(void)setCurrentSearchTypeString:(NSString *) newSearchTypeString{
    @synchronized(self){
        if(newSearchTypeString != _searchTypeString){
            _searchTypeString=[newSearchTypeString copy];
        }
    }
}

-(NSString *)currentSearchString {
    //Perform a mutext lock
    @synchronized(self) {
        return [_searchString copy];
    }
}

-(void)setCurrentSearchString:(NSString *)searchString{
    //Perform a mutext lock
    @synchronized(self){
        [self showAlertWithString:[NSString stringWithFormat:@"Old Search String: %@, New Search String: %@", _searchString, searchString]];
        if(searchString != _searchString){
            _searchString=[searchString copy];
        }
    }
}

//By setting the current search string to blank,
//We ensure that no results are returned.
-(void)cancelMedicationNameSearch{
    [self setCurrentSearchString:@""];
}

//Function to return if the passed parameters are the most current search string
-(BOOL) isSearchCurrent:(NSString *)medicationName withSearchType:(MedicationSearchType)searchType{
    //Check if currentSearchString is blank and return NO immediately
    //This is how any search can be cancelled
    if(([[self currentSearchString] isEqualToString:@""]))
        return NO;
    
    NSString *searchTypeString=[self getSearchTypeStringForSearchType:searchType];
    if(([medicationName isEqualToString:[self currentSearchString]])
       && ([searchTypeString isEqualToString:[self currentSearchTypeString]])){
        return YES;
    }
    return NO;
}

#pragma mark - Searches
//This is the main search for a medication name that should be called by implementing view controllers
-(void) searchForMedicationName:(NSString *)passedMedicationName
        withSearchType:(MedicationSearchType)searchType
        completionBlock:(void (^)(NSArray *resultsArray)) block{

    NSString *medicationName=[NSString stringWithString:passedMedicationName];
    NSString *medicationSearchType=[self getSearchTypeStringForSearchType:searchType];
    
    [self showAlertWithString:[NSString stringWithFormat:@"Starting new search: %@ (%@)", medicationName, medicationSearchType]];
    
    
    //The search is done in two parts
    //First, we update the local properties for the currentSearchString and currentSearchTypeString,
    //this allows us to compare it with any new search string and cancel the search
    [self setCurrentSearchString:medicationName];
    [self setCurrentSearchTypeString:medicationSearchType];

    //Second, we kick off the search
    dispatch_async(_medSearchQueue, ^{
        [self performSearchForMedicationName:medicationName withSearchType:searchType completionBlock:block];
    });
}

-(void) performSearchForMedicationName:(NSString *)passedMedicationName
        withSearchType:(MedicationSearchType)searchType
        completionBlock:(void (^)(NSArray *resultsArray)) block{
    
    //Make a copy of the string so we can compare it with the original search string
    NSString *medicationName=[NSString stringWithString:passedMedicationName];
    
    //Verify the search string is still the current search string, this is how we can cancel a search, if the search string has changed.
    if([self isSearchCurrent:medicationName withSearchType:searchType]){
        
        [self showAlertWithString:[NSString stringWithFormat:@"Starting search for: %@", medicationName]];

        //Set up a mutable array to hold the results
        NSMutableSet *setResults = [NSMutableSet setWithCapacity:1];
        NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"Medication"];
        NSError *error=nil;
        
        NSPredicate *predicate;
        
        //The searchType tells us if we are searching for OTC or Rx
        switch (searchType) {
            case MedicationSearchTypeAll:
                predicate=[NSPredicate predicateWithFormat:@"brandName beginswith[cd] %@ OR genericName beginswith[cd] %@", medicationName, medicationName];
                break;
            case MedicationSearchTypeOTC:
                predicate=[NSPredicate predicateWithFormat:@"(brandName beginswith[cd] %@ OR genericName beginswith[cd] %@) AND medType matches[cd] 'OTC'", medicationName, medicationName];
                break;
            case MedicationSearchTypeRX:
                predicate=[NSPredicate predicateWithFormat:@"(brandName beginswith[cd] %@ OR genericName beginswith[cd] %@) AND medType matches[cd] 'Rx'", medicationName, medicationName];
                break;
            default:
                break;
        }
        [fetchRequest setPredicate:predicate];
        
        
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (fetchResults == nil)
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Error fetching log entries: %@", [error localizedDescription]]];
        }


        //Verify the search string is still the current search string, return if it has changed without calling the block
        if(![self isSearchCurrent:medicationName withSearchType:searchType])
            return;
        
        //Clean out any duplicate results
        //Iterate through results to filter out duplicates
        [fetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
           
            //Iterate through results to filter out duplicates

            Medication *foundMedication=(Medication *)obj;

            //Determine what matched, brand name, generic name or both
            NSRange brandRange = [foundMedication.brandName rangeOfString:medicationName options:NSCaseInsensitiveSearch];
            NSRange genericRange = [foundMedication.genericName rangeOfString:medicationName options:NSCaseInsensitiveSearch];
            
            if (brandRange.location == 0)
                [setResults addObject:foundMedication.brandName];
            if (genericRange.location == 0)
                [setResults addObject:foundMedication.genericName];
        }];
        
        //Verify the search string is still the current search string, return if it has changed without calling the block
        if(![self isSearchCurrent:medicationName withSearchType:searchType])
            return;
        
        NSMutableArray* arrayResults = [NSMutableArray arrayWithArray:[setResults allObjects]];
        
        //Sort the array results by name
        [arrayResults sortUsingSelector:@selector(caseInsensitiveCompare:)];
        
        //Verify the search string is still the current search string
        if([self isSearchCurrent:medicationName withSearchType:searchType]){
            [self showAlertWithString:@"Returning results"];
            [self showAlertWithString:[NSString stringWithFormat:@"Results for: %@ is %@", medicationName, [self currentSearchString]]];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                block([NSArray arrayWithArray:arrayResults]);
            });
        }else{
            // return if it has changed without calling the block
            [self showAlertWithString:@"Do NOT return results"];
            [self showAlertWithString:[NSString stringWithFormat:@"Do NOT return results: %@ is NOT %@", medicationName, [self currentSearchString]]];
        }
    }else{
        [self showAlertWithString:@"Do NOT return results"];
        [self showAlertWithString:[NSString stringWithFormat:@"Do NOT return results: %@ is NOT %@", medicationName, [self currentSearchString]]];
    }
}

//This search method is used when getting drug permutations from a search result in step 1
-(void) getMedicationsWithMedicationName:(NSString *)medicationName
                withMedicationTypeString:(NSString *)medSearchTypeString
                         completionBlock:(void (^)(NSArray *resultsArray)) block{
    dispatch_async(_medSearchQueue, ^{
        NSMutableArray *arrayResults = [NSMutableArray arrayWithCapacity:1];
        NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"Medication"];
        NSError *error=nil;
        
        MedicationSearchType medSearchType=[self getMedicationSearchTypeForString:medSearchTypeString];
        NSString *medSearchTypeString=[self getSearchTypeStringForSearchType:medSearchType];

        NSPredicate *mainpredicate=[NSPredicate predicateWithFormat:@"brandName matches[cd] %@ or genericName matches[cd] %@", medicationName, medicationName];

        //Define a serach type if one was specified
        NSPredicate *subPredicate=nil;
        if(medSearchType==MedicationSearchTypeRX || medSearchType==MedicationSearchTypeOTC) {
            subPredicate=[NSPredicate predicateWithFormat:@"medType matches[cd] %@", medSearchTypeString];
        }
        
        //Combine the mainpredicate (searchString) and subpredicate
        if(mainpredicate && subPredicate){
            NSPredicate *compPredicate=[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:mainpredicate,subPredicate, nil]];
            [fetchRequest setPredicate:compPredicate];
        }else if (mainpredicate){
            [fetchRequest setPredicate:mainpredicate];
        }
        
        [self showAlertWithString:[fetchRequest.predicate predicateFormat]];
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (fetchResults == nil)
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Error fetching log entries: %@", [error localizedDescription]]];
        }
        
        [self showAlertWithString:[NSString stringWithFormat:@"Fetch Results Count: %i", (int)[fetchResults count]]];

        //Iterate through results to look for duplicates
        [fetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            //Iterate through results to filter out duplicates
            Medication *foundMedication=(Medication *)obj;
            
            //We need to add the medication permutation to a custom class so that we can track how it was matched, brand name or generic name
            PermutationSearchResult *newResult;
            if([foundMedication.brandName caseInsensitiveCompare:medicationName]==NSOrderedSame){
                newResult=[[PermutationSearchResult alloc] initWithMedication:foundMedication andMatchType:MedicationResultMatchBrandName];
            }else{
                newResult=[[PermutationSearchResult alloc] initWithMedication:foundMedication andMatchType:MedicationResultMatchGenericName];
            }

            //Check if result already in array
            //containsObject will use the :isEqual method in PermutationSearchResult class
            if(![arrayResults containsObject:newResult]){
                //If the results array does not contain that object, add it
                [arrayResults addObject:newResult];
            }

        }];
        
        //Return the results
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            block([NSArray arrayWithArray:arrayResults]);
        });
    });
}

//Asynchronously obtain the list of possible drug types from the database
-(void) getMedicationTypesWithCompletionBlock:(void(^)(NSArray *resultsArray)) block{
    dispatch_async(_medSearchQueue, ^{
        NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedFormType"];
        NSError *error=nil;
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (fetchResults == nil)
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication form types: %@", [error localizedDescription]]];
        }

        [self showAlertWithString:[NSString stringWithFormat:@"medication form types Count: %i", (int)[fetchResults count]]];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            block([NSArray arrayWithArray:fetchResults]);
        });
    });
}

-(NSArray *) getMedicationTypes{
    __block NSArray *fetchResults;
    
    dispatch_sync(_medSearchQueue, ^{

        NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedFormType"];
        NSError *error=nil;
        fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (fetchResults == nil)
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication form types: %@", [error localizedDescription]]];
        }
        [self showAlertWithString:[NSString stringWithFormat:@"medication form types Count: %i", (int)[fetchResults count]]];
    });
        
    return fetchResults;
}

//Asynchronously obtain the list of possible drug routes from the database
-(void) getMedicationRoutesWithCompletionBlock:(void(^)(NSArray *resultsArray)) block{
    
    if ([cachedMedicationRoutes count] == 0)
    {
        dispatch_async(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedicationRoute"];
            NSError *error=nil;
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication routes: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication routes Count: %i", (int)[fetchResults count]]];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [cachedMedicationRoutes setArray:fetchResults];
                block([NSArray arrayWithArray:fetchResults]);
            });
        });
    }
    else
        block([NSArray arrayWithArray:cachedMedicationRoutes]);
}

-(NSArray *) getMedicationRoutes{
    
    if ([cachedMedicationRoutes count] == 0)
    {
        __block NSArray *fetchResults;
        
        dispatch_sync(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedicationRoute"];
            NSError *error=nil;
            fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication routes: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication routes Count: %i", (int)[fetchResults count]]];
        });
        
        [cachedMedicationRoutes setArray:fetchResults];
    }
    
    return [NSArray arrayWithArray:cachedMedicationRoutes];
}


//Asynchronously obtain the list of possible strength units for a particular drug type from the database, with a completion block
-(void) getStrengthUnitsForFormType:(NSString *)formType withCompletionBlock:(void(^)(NSArray *resultsArray)) block{
    
    if (![cachedStrengthUnits objectForKey:formType])
    {
        dispatch_async(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedStrengthUnit"];
            
            NSPredicate *predicate=[NSPredicate predicateWithFormat:@"medFormType matches %@", formType];
            [fetchRequest setPredicate:predicate];
            
            NSError *error=nil;
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication strength units: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication strength units Count: %i", (int)[fetchResults count]]];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [cachedStrengthUnits setObject:fetchResults forKey:formType];
                block([NSArray arrayWithArray:fetchResults]);
            });
        });
    }
    else
    {
        NSArray* strengthUnits = (NSArray*)[cachedStrengthUnits objectForKey:formType];
        block([NSArray arrayWithArray:strengthUnits]);
    }
}

//Synchronously obtain the list of possible strength units for a particular drug type from the database
-(NSArray *) getStrengthUnitsForFormType:(NSString *)formType{
    
    if (![cachedStrengthUnits objectForKey:formType])
    {
        __block NSArray *fetchResults;
        
        dispatch_sync(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedStrengthUnit"];
            
            NSPredicate *predicate=[NSPredicate predicateWithFormat:@"medFormType matches %@", formType];
            [fetchRequest setPredicate:predicate];
            NSError *error=nil;
            fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching strength units: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication strength units Count: %i", (int)[fetchResults count]]];
        });
    
        [cachedStrengthUnits setObject:fetchResults forKey:formType];
    }
    
    NSArray* strengthUnits = (NSArray*)[cachedStrengthUnits objectForKey:formType];
    return [NSArray arrayWithArray:strengthUnits];
}


//Asynchronously obtain the list of possible amount units for a particular drug type from the database
-(void) getDoseAmountUnitsForFormType:(NSString *)formType withCompletionBlock:(void(^)(NSArray *resultsArray)) block{
    
    if (![cachedDoseAmountUnits objectForKey:formType])
    {
        dispatch_async(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedDoseUnit"];
            
            NSPredicate *predicate=[NSPredicate predicateWithFormat:@"medFormType matches %@", formType];
            [fetchRequest setPredicate:predicate];
            
            NSError *error=nil;
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication dose units: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication dose units Count: %i", (int)[fetchResults count]]];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [cachedDoseAmountUnits setObject:fetchResults forKey:formType];
                block([NSArray arrayWithArray:fetchResults]);
            });
        });
    }
    else
    {
        NSArray* doseAmountUnits = (NSArray*)[cachedDoseAmountUnits objectForKey:formType];
        block([NSArray arrayWithArray:doseAmountUnits]);
    }
}

//Synchronously obtain the list of possible amount units for a particular drug type from the database
-(NSArray *) getDoseAmountUnitsForFormType:(NSString *)formType{
    
    if (![cachedDoseAmountUnits objectForKey:formType])
    {
        __block NSArray *fetchResults;
        
        dispatch_sync(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedDoseUnit"];
            
            NSPredicate *predicate=[NSPredicate predicateWithFormat:@"medFormType matches %@", formType];
            [fetchRequest setPredicate:predicate];
            NSError *error=nil;
            fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching dose units: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication dose units Count: %i", (int)[fetchResults count]]];
        });
        
        [cachedDoseAmountUnits setObject:fetchResults forKey:formType];
    }
    
    NSArray* doseAmountUnits = (NSArray*)[cachedDoseAmountUnits objectForKey:formType];
    return [NSArray arrayWithArray:doseAmountUnits];
}

//Get medication locations
-(NSArray *) getMedicationLocationsForFormType:(NSString *) formType {
    
    if (![cachedMedicationLocations objectForKey:formType])
    {
        __block NSArray *fetchResults;
        
        dispatch_sync(_medSearchQueue, ^{
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"MedApplyLocation"];
            NSPredicate *predicate=[NSPredicate predicateWithFormat:@"medFormType matches %@", formType];
            [fetchRequest setPredicate:predicate];
            NSError *error=nil;
            fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults == nil)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Error fetching medication apply location: %@", [error localizedDescription]]];
            }
            [self showAlertWithString:[NSString stringWithFormat:@"medication form apply location Count: %i", (int)[fetchResults count]]];
           
        });
        
        [cachedMedicationLocations setObject:fetchResults forKey:formType];
    }
    
    NSArray* medicationLocations = (NSArray*)[cachedMedicationLocations objectForKey:formType];
    return [NSArray arrayWithArray:medicationLocations];
}


#pragma mark - CoreData
// Returns the managed object model for the DB data file.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    NSString *modelPath = [[DosecastUtil getResourceBundle] pathForResource:@"MedicationDB" ofType:@"momd"];
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the DB data file.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
	// persistentStoreCoordinator options - for automatic, lightweight migration of past data model versions
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSReadOnlyPersistentStoreOption, nil];
	
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    
    NSString *storePath=[self dataStorePath];
    NSURL *storeURL=[NSURL fileURLWithPath:storePath];
    
	if(![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]){
        [self showAlertWithString:[NSString stringWithFormat:@"Error adding persistentStoreCoordinator: %@", [error localizedDescription]]];
    }
    
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the DB data file.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    if (self.persistentStoreCoordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

//This method is used in the event that we need a MOC on a different queue
- (NSManagedObjectContext *)newManagedObjectContext
{
    
    NSManagedObjectContext *newMOC = [[NSManagedObjectContext alloc] init];
    [newMOC setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    //    }
    return newMOC;
}


-(NSString *)dataStorePath{
    NSString *defaultDBPath = [[DosecastUtil getResourceBundle] pathForResource:@"MedicationDB" ofType:@"sqlite"];
    return defaultDBPath;
}

#pragma mark - convenience methods
-(MedicationSearchType)getMedicationSearchTypeForString:(NSString *)medSearchTypeString{
    MedicationSearchType searchType;
    if([medSearchTypeString isEqualToString:@"Prescription"]){
        searchType=MedicationSearchTypeRX;
    }else if ([medSearchTypeString isEqualToString:@"OTC"]){
        searchType=MedicationSearchTypeOTC;
    }else{
        searchType=MedicationSearchTypeAll;
    }
    return searchType;

}

-(NSString *)getSearchTypeStringForSearchType:(MedicationSearchType)medSearchType{
    switch (medSearchType) {
        case MedicationSearchTypeAll:
            return @"ALL";
            break;
        case MedicationSearchTypeOTC:
            return @"OTC";
            break;
        case MedicationSearchTypeRX:
            return @"Rx";
            break;
        default:
            return @"UNKNOWN";
            break;
    }
}

#pragma mark - alerts
-(BOOL) isDebugOn{
    
#ifdef DEBUG
    return _isDebugOn;
#endif
    
    return NO;
}

-(void) showAlertWithString:(NSString *)stringToShow{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        DebugLog(@"MedicationSearchManager: %@", stringToShow);
    });
    
    if(self.isDebugOn){
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSLog(@"MedicationSearchManager: %@", stringToShow);
        });
    }
}

#pragma mark - queue mgmt
dispatch_queue_t createSearchQueue()
{
    // Create the queue and set the context data.
    dispatch_queue_t serialQueue = dispatch_queue_create("com.montunosoftware.MedicationSearchQueue", NULL);
    
    return serialQueue;
}

#pragma mark - CleanUp
-(void)dealloc{
    
    self.currentSearchString=nil;

}


@end
