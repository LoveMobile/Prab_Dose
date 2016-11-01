//
//  DosecastDBDataFile.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/10/11.
//  Copyright (c) 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSManagedObjectModel;
@class NSManagedObjectContext;
@class NSPersistentStoreCoordinator;

@protocol DosecastDBDataFileDelegate
@required
- (UINavigationController*)getUINavigationController;
@end

@interface DosecastDBDataFile : NSObject
{
@private
    NSURL* storeUrl;
    NSString* schemaFilename;
    NSString* schemaFilenameExt;
    NSManagedObjectContext *managedObjectContext_;
    NSManagedObjectModel *managedObjectModel_;
    NSPersistentStoreCoordinator *persistentStoreCoordinator_;
    NSObject<DosecastDBDataFileDelegate>* __weak delegate;
}

- (id)initWithURL:(NSURL*)store
   schemaFilename:(NSString*)schemaFile
schemaFilenameExt:(NSString*)schemaFileExt
         delegate:(NSObject<DosecastDBDataFileDelegate>*)del;

// Commits any changes to the db file
- (void) saveChanges;

// Returns the managed object model for the DB data file.
// If the model doesn't already exist, it is created from the application's model.
@property (weak, nonatomic, readonly) NSManagedObjectModel* managedObjectModel;

// Returns the persistent store coordinator for the DB data file.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
@property (weak, nonatomic, readonly) NSPersistentStoreCoordinator* persistentStoreCoordinator;

// Returns the managed object context for the DB data file.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
@property (weak, nonatomic, readonly) NSManagedObjectContext* managedObjectContext;

@property (nonatomic, weak) NSObject<DosecastDBDataFileDelegate> *delegate;

@end
