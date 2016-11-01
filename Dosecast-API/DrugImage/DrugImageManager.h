//
//  DrugImageManager.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 10/2/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "HTTPWrapperDelegate.h"

@class DrugImage;
@class HTTPWrapper;
@class SBJsonParser;

// This notification is fired when a drug image has been downloaded
extern NSString *DrugImageAvailableNotification;

// This notification is fired when all new drug images have been downloaded
extern NSString *DrugImageDownloadCompleteNotification;

// This notification is fired when new drug images have been uploaded
extern NSString *DrugImageUploadCompleteNotification;

// This notification is fired when a sync attempt has failed
extern NSString *DrugImageSyncFailedNotification;

@interface DrugImageManager : NSObject <HTTPWrapperDelegate>
{
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    
    //Used for syncing images
    HTTPWrapper *_httpWrapper;
    SBJsonParser *_jsonParser;
    NSString *_serverProtocol;
    NSString *_serverHost;
	NSString *_serverPath;
    
    NSTimer *_timeoutTimer;
    NSTimer *_syncTimer;
    
    //This is used to extend a delay of syncing if errors are encountered
    NSTimeInterval _lastDelayInSeconds;
    
    UIBackgroundTaskIdentifier _backgroundTaskID;
    BOOL _isWaitingForResponse;
    BOOL _isDebugOn;
}

#pragma mark - Server Sync Control
-(void) clearAllImages;
-(void) syncImages;
-(void) startSyncImagesImmediately;

- (BOOL) needsImageUpload;
- (BOOL) needsImageDownload;

//Used to finish any background transactions
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskID;

//Property to say if a sync has been initiated and we are waiting for the response from the server
@property(nonatomic, readonly) BOOL isWaitingForResponse;

#pragma mark - DrugImage Information

//Checks if an image exists for a certain imageGUID
-(BOOL) doesImageExistForImageGUID:(NSString *) imageGUIDToCheck;

//Returns a UIImage for a particular imageGUID
-(UIImage *)imageForImageGUID:(NSString *)imageGUIDToRetrieve;

#pragma mark - Local DrugImage File Changes
//Saves the image (generates a new GUID if one
//is not provided and one does not exists) for the drug ID
//Allows you to specify an imageGUID and if the image should be uploaded to the server
//Use this method when pulling DrugImages from the server
-(NSString *) imageGUIDWithImage:(UIImage *)imageToSave withImageGUID:(NSString *)imageGUID shouldUploadImage:(BOOL)shouldUpload;

//Removes the DrugImage for the specified imageGUID
//from the file system, core data and optionally from the server
-(void)removeImageForImageGUID:(NSString *)imageGUIDToRemove shouldRemoveServerImage:(BOOL)shouldRemoveServer;

#pragma mark - Server Methods

-(void) uploadImageWithImageGUID:(NSString *)imageGUIDToUpload;
-(void) downloadImageWithImageGUID:(NSString *)imageGUIDToDownload;

+(DrugImageManager *)sharedManager;

- (BOOL) needsImageSync;

@end
