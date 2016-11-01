//
//  DosecastDBDataFile.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/10/11.
//  Copyright (c) 2011 Montuno Software, LLC. All rights reserved.
//

#import "DosecastDBDataFile.h"
#import "DosecastUtil.h"
#import <CoreData/CoreData.h>
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

@implementation DosecastDBDataFile
@synthesize delegate;

- (id)init
{
    return [self initWithURL:nil schemaFilename:nil schemaFilenameExt:nil delegate:nil];
}

- (id)initWithURL:(NSURL *)store
   schemaFilename:(NSString*)schemaFile
schemaFilenameExt:(NSString*)schemaFileExt
         delegate:(NSObject<DosecastDBDataFileDelegate>*)del
{
	if ((self = [super init]))
    {
        storeUrl = store;
        schemaFilename = schemaFile;
        schemaFilenameExt = schemaFileExt;
        delegate = del;
	}
	
    return self;		
}


// Commits any changes to the db file
- (void) saveChanges
{
    // Try to save our db changes, if any. Make sure we have a persistent store and it has some changes.
    NSError *error = nil;
    BOOL hasPersistentStores = NO;
    if (persistentStoreCoordinator_)
        hasPersistentStores = [[persistentStoreCoordinator_ persistentStores] count] > 0;
    if (managedObjectContext_ != nil && hasPersistentStores && [managedObjectContext_ hasChanges])
    {
		[managedObjectContext_ save:&error];
    }
}

// Returns the managed object model for the DB data file.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (managedObjectModel_ != nil) {
        return managedObjectModel_;
    }
    else if (!schemaFilename || !schemaFilenameExt)
        return nil;
    NSString *modelPath = [[DosecastUtil getResourceBundle] pathForResource:schemaFilename ofType:schemaFilenameExt];
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    managedObjectModel_ = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return managedObjectModel_;
}

// Returns the persistent store coordinator for the DB data file.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (persistentStoreCoordinator_ != nil) {
        return persistentStoreCoordinator_;
    }
    else if (!storeUrl)
        return nil;
        
	// persistentStoreCoordinator options - for automatic, lightweight migration of past data model versions
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             NSFileProtectionNone, NSPersistentStoreFileProtectionKey, nil];
	
    NSError *error = nil;
    persistentStoreCoordinator_ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
	NSPersistentStore* store = [persistentStoreCoordinator_ addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error];
	if (!store && error)
	{
		NSString* errorText = NSLocalizedStringWithDefaultValue(@"ErrorHistoryLoadingMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history could not be loaded due to the following error: %@", @"The message in the alert appearing when an error occurs loading the dose history"]);
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorHistoryLoadingTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Error Loading Dose History", @"The title of the alert appearing when an error occurs loading the dose history"])
                                                                                           message:[NSString stringWithFormat:errorText, [error localizedDescription]]];
        UINavigationController* mainNavigationController = [delegate getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        [alert showInViewController:topNavController.topViewController];
	}
    
    return persistentStoreCoordinator_;
}

// Returns the managed object context for the DB data file.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (managedObjectContext_ != nil) {
        return managedObjectContext_;
    }
    
    NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
    if (coordinator != nil) {
        managedObjectContext_ = [[NSManagedObjectContext alloc] init];
        [managedObjectContext_ setPersistentStoreCoordinator:coordinator];
    }
    return managedObjectContext_;
}

@end
