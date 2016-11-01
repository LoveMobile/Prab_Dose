//
//  DrugImageManager.m
//  Dosecast-API
//
//  Created by Shawn Grimes on 10/2/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DrugImageManager.h"
#import "ReachabilityManager.h"
#import "DosecastUtil.h"
#import "HistoryManager.h"
#import "DosecastDBDataFile.h"
#import "DrugImage.h"
#import "ServerProxy.h"
#import "HTTPWrapper.h"
#import "JSON.h"
#import "JSONConverter.h"
#import "DataModel.h"
#import "VersionNumber.h"
#import "GlobalSettings.h"

NSString *DrugImageDownloadCompleteNotification = @"DrugImageDownloadCompleteNotification";
NSString *DrugImageUploadCompleteNotification = @"DrugImageUploadCompleteNotification";
NSString *DrugImageSyncFailedNotification = @"DrugImageSyncFailedNotification";
NSString *DrugImageAvailableNotification = @"DrugImageAvailableNotification";

static DrugImageManager *gInstance = nil;
static NSTimeInterval DEFAULT_DELAY = 0.3;

@implementation DrugImageManager
@synthesize isWaitingForResponse=_isWaitingForResponse;
@synthesize backgroundTaskID=_backgroundTaskID;

#pragma mark - Setup
+(DrugImageManager *)sharedManager{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

-(id) init{
    if((self=[super init])){
        

#ifdef DEBUG_SERVER
        _serverProtocol = NSLocalizedStringWithDefaultValue(@"ServerProtocolDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"https", @"Protocol of URL for Dosecast server"]);
        _serverHost = NSLocalizedStringWithDefaultValue(@"ServerHostDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"ppserver.montunosoftware.com", @"Domain name of Dosecast server host"]);
        _serverPath = NSLocalizedStringWithDefaultValue(@"ServerPathDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"/pillpopper-dev", @"The path to the debug server on the Dosecast server host"]);
#else
        _serverProtocol = NSLocalizedStringWithDefaultValue(@"ServerProtocolRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"https", @"Protocol of URL for Dosecast server"]);
        _serverHost = NSLocalizedStringWithDefaultValue(@"ServerHostRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"ppserver.montunosoftware.com", @"Domain name of Dosecast server host"]);
        _serverPath = NSLocalizedStringWithDefaultValue(@"ServerPathRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"/pillpopper", @"The path to the release server on the Dosecast server host"]);
#endif

        
        _httpWrapper = [[HTTPWrapper alloc] init];
        _httpWrapper.asynchronous = YES;
        _httpWrapper.delegate = self;

        //Create sync timer
        _syncTimer = nil;
        _lastDelayInSeconds = DEFAULT_DELAY;
    
        _isWaitingForResponse=NO;
        _jsonParser = [[SBJsonParser alloc] init];
        _backgroundTaskID = UIBackgroundTaskInvalid;

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAPIVersionUpgrade:)
                                                     name:GlobalSettingsAPIVersionUpgrade
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];

#ifdef DEBUG
        _isDebugOn=YES;
#else
        _isDebugOn=NO;
#endif
        
    }
    return self;
}

- (void)dealloc
{
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalSettingsAPIVersionUpgrade object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];
}

#pragma mark - Server Sync Control

- (void) clearAllImages
{
    if (_timeoutTimer)
    {
        [_timeoutTimer invalidate];
        _timeoutTimer=nil;
    }
    
    if (_syncTimer)
    {
        [_syncTimer invalidate];
        _syncTimer = nil;
    }
    self.isWaitingForResponse = NO;
    _lastDelayInSeconds = DEFAULT_DELAY;
    
    NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    
    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
    if (resultsArray == nil)
    {
        [self showAlertWithString:[NSString stringWithFormat:@"Error fetching image entries: %@", [error localizedDescription]]];
    }
    else
    {
        // Delete all objects in the database
        for (DrugImage *imageEntry in resultsArray)
        {
            //File will be removed from the filesystem when the core data object is deleted
            [newMOC deleteObject:imageEntry];
        }
        NSError *saveError;
        if(![newMOC save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error clearing image entries for sync Error: %@", [saveError localizedDescription]]];
        }else{
            [self showAlertWithString:@"Successfully cleared image entries for sync"];
        }
    }
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    [self clearAllImages];
}

-(BOOL) isWaitingForResponse{
    return _isWaitingForResponse;
}

- (void) setIsWaitingForResponse:(BOOL)isWaitingForResponse
{
    _isWaitingForResponse = isWaitingForResponse;
}

- (void)handleAPIVersionUpgrade:(NSNotification*)notification
{
    VersionNumber* lastAPIVersionNumber = notification.object;
    BOOL isFileUpgrade = [((NSNumber*)[notification.userInfo objectForKey:GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade]) boolValue];
    if ([lastAPIVersionNumber compareWithVersionString:@"Version 6.0.9"] == NSOrderedSame) // upgrade from v6.0.9
    {
        if (isFileUpgrade)
        {
            NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
            
            NSManagedObjectContext *newMoc=[self newManagedObjectContext];
            
            NSError *error=nil;
            // Set the needs download flag to false on all database objects
            NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
            if (resultsArray)
            {
                for (DrugImage *imageEntry in resultsArray)
                {
                    imageEntry.needsDownload=[NSNumber numberWithBool:NO];
                    
                    // Replace image path with the relative path to the file. It is stored as an absolute path, and the app's document directory path may change unexpectedly.
                    if (imageEntry.imagePath && imageEntry.imageGUID)
                        [imageEntry updateImagePath];
                }
                
                NSError *saveError;
                [newMoc save:&saveError];
            }
        }
    }
}

#pragma mark - DrugImage Information

- (BOOL) needsImageSync
{
    NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"needsUpload == %@ or needsDelete == %@ or needsDownload == %@", [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES]];
    [batchRequest setPredicate:fetchPredicate];
    [batchRequest setFetchLimit:1];
    
    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
    if (resultsArray == nil)
        return NO;
    else
        return [resultsArray count] > 0;
}

- (BOOL) needsImageDownload
{
    NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"needsDownload == %@", [NSNumber numberWithBool:YES]];
    [batchRequest setPredicate:fetchPredicate];
    [batchRequest setFetchLimit:1];
    
    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
    if (resultsArray == nil)
        return NO;
    else
        return [resultsArray count] > 0;
}

- (BOOL) needsImageUpload
{
    NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"needsUpload == %@", [NSNumber numberWithBool:YES]];
    [batchRequest setPredicate:fetchPredicate];
    [batchRequest setFetchLimit:1];
    
    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
    if (resultsArray == nil)
        return NO;
    else
        return [resultsArray count] > 0;
}

//Returns if an image exists for a certain imageGUID
-(BOOL) doesImageExistForImageGUID:(NSString *) imageGUIDToCheck{
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToCheck];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];

    DrugImage *currentImageEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);
    return (currentImageEntry != nil && [currentImageEntry fullPathToImageFile] != nil);
}

//Returns a UIImage for a particular imageGUID
-(UIImage *)imageForImageGUID:(NSString *)imageGUIDToRetrieve
{    
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToRetrieve];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *currentImageEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);
    if (currentImageEntry && [currentImageEntry fullPathToImageFile])
        return [UIImage imageWithContentsOfFile:[currentImageEntry fullPathToImageFile]];
    else
        return nil;
 }


#pragma mark - Local DrugImage File Changes

//Saves the image (generates a new GUID if one
//is not provided and one does not exists) for the drug ID
//Allows you to specify an imageGUID and if the image should be uploaded to the server
//Use this method when pulling DrugImages from the server
-(NSString *) imageGUIDWithImage:(UIImage *)imageToSave withImageGUID:(NSString *)imageGUID shouldUploadImage:(BOOL)shouldUpload{
    
    UIImage *image=[imageToSave copy];
    
    NSString *imageGUIDToSave=@"";
    if(imageGUID!=nil){
        imageGUIDToSave=[NSString stringWithString:imageGUID];
    }else{
        imageGUIDToSave=[DosecastUtil createGUID];
    }
    
    //Get save path
    NSString *filePathString=[DrugImage fullFilePathForImageGUID:imageGUIDToSave];
    
    //Check that UIImage is valid and has data
    CGImageRef cgref = [image CGImage];
    CIImage *cim = [image CIImage];
    if (cim == nil && cgref == NULL)
    {
        [self showAlertWithString:@"no underlying data"];
        return @"";
    }
    
    //Create jpg from UIImage and save to file system
    NSError* writeError = nil;
    if (![UIImageJPEGRepresentation(image, 8.0) writeToFile:filePathString options:(NSAtomicWrite | NSDataWritingFileProtectionNone) error:&writeError])
    {
        [self showAlertWithString:@"File was not saved to the file system"];
        return @"";
    }
    
    //Check if database object already exists
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToSave];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *currentImageEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

    if(currentImageEntry){            
        //Sets whether we should mark the image for upload or not
        currentImageEntry.needsUpload=[NSNumber numberWithBool:shouldUpload];
        currentImageEntry.needsDelete=[NSNumber numberWithBool:NO];
        currentImageEntry.needsDownload = [NSNumber numberWithBool:NO];
        
        // If the image path is missing, it means this was recently downloaded - so update it now
        if (!currentImageEntry.imagePath)
            [currentImageEntry updateImagePath];
        
        NSError *saveError;
        if(![newMoc save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error saving updated image entries, Error: %@", [saveError localizedDescription]]];
        }
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Saving new DrugImage for imageGUID: %@",imageGUIDToSave]];
        //Create new drug image database object
        
        DrugImage *newDrugImage=(DrugImage *)[NSEntityDescription insertNewObjectForEntityForName:@"DrugImage" inManagedObjectContext:newMoc];
        newDrugImage.imageGUID=imageGUIDToSave;
        [newDrugImage updateImagePath];
        newDrugImage.needsUpload=[NSNumber numberWithBool:shouldUpload];
        newDrugImage.needsDelete=[NSNumber numberWithBool:NO];
        newDrugImage.needsDownload=[NSNumber numberWithBool:NO];
        
        NSError *error=nil;
        if(![newMoc save:&error]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error adding new drug image: %@",[error localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Saved new drug image: %@",[newDrugImage fullPathToImageFile]]];
        }
    }
    
    if (shouldUpload)
    {
        [self syncImages];
    }
    
    return imageGUIDToSave;
}

//Removes an image for a particular imageGUID
//Optionally from the server too
-(void)removeImageForImageGUID:(NSString *)imageGUIDToRemove shouldRemoveServerImage:(BOOL)shouldRemoveServer{

    //Check if database object already exists
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToRemove];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *imageEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

   if (imageEntry) {
        [self showAlertWithString:[NSString stringWithFormat:@"Deleting image entry"]];
       
        if(shouldRemoveServer){
            //Marks the image for deletion on the server
            imageEntry.needsDelete=[NSNumber numberWithBool:YES];
            imageEntry.needsUpload=[NSNumber numberWithBool:NO];
            imageEntry.needsDownload = [NSNumber numberWithBool:NO];
            NSError *saveError;
            if(![newMoc save:&saveError]){
                [self showAlertWithString:[NSString stringWithFormat:@"Error saving deleted image entries to core data, Error: %@", [saveError localizedDescription]]];
            }
            [self syncImages];
        }else{
            //Delete the image locally only
            //File will be removed from the filesystem when the core data object is deleted
            [newMoc deleteObject:imageEntry];
            NSError *saveError;
            if(![newMoc save:&saveError]){
                [self showAlertWithString:[NSString stringWithFormat:@"Error saving deleted image entries to core data, Error: %@", [saveError localizedDescription]]];
            }
        }
    }
}

#pragma mark - ServerImages

-(void)syncImages
{
    if (!_syncTimer && !self.isWaitingForResponse && [self needsImageSync])
        _syncTimer = [NSTimer scheduledTimerWithTimeInterval:_lastDelayInSeconds target:self selector:@selector(syncPendingImageChanges:) userInfo:nil repeats:NO];
}

-(void) startSyncImagesImmediately
{
    if (_syncTimer && _syncTimer.isValid)
    {
        [_syncTimer fire];
    }
}

-(void)syncPendingImageChanges:(NSTimer*)theTimer {
    _syncTimer = nil;

    //make sure the image manager should sync results and check to make sure we are not waiting for a response from the server
    [self showAlertWithString:@"Checking for images to sync"];
    if([[ReachabilityManager getInstance] canReachInternet]){
        NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
        NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"needsUpload == %@ or needsDelete == %@ or needsDownload == %@", [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES]];
        [batchRequest setPredicate:fetchPredicate];
        [batchRequest setFetchLimit:1];

        // Sort images needing upload first, then download next
        NSSortDescriptor *uploadSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"needsUpload" ascending:NO];
        NSSortDescriptor *downloadSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"needsDownload" ascending:NO];
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:uploadSortDescriptor, downloadSortDescriptor, nil];
        [batchRequest setSortDescriptors:sortDescriptors];
        
        NSManagedObjectContext *newMOC=[self newManagedObjectContext];
        
        NSError *error=nil;
        NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
        if (resultsArray == nil)
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Error fetching image entries: %@", [error localizedDescription]]];
        }
        [self showAlertWithString:[NSString stringWithFormat:@"Results Count: %i", (int)[resultsArray count]]];
        if([resultsArray count]>0){
            DrugImage *imageEntry = (DrugImage *)[resultsArray objectAtIndex:0];
            if([imageEntry.needsUpload boolValue]==YES){
                NSString *serverURL=[[self getServerURL] stringByAppendingFormat:@"/putblob?guid=%@", imageEntry.imageGUID];
                [self showAlertWithString:serverURL];
                
                NSURL *imageUploadURL=[NSURL URLWithString:[[self getServerURL] stringByAppendingFormat:@"/putblob?guid=%@", imageEntry.imageGUID]];
                NSData *imageData = [NSData dataWithContentsOfFile:[imageEntry fullPathToImageFile]];
                //Mark that we are now waiting for a response from the server
                self.isWaitingForResponse=YES;
                
                [self showAlertWithString:[NSString stringWithFormat:@"Starting image upload for: %@", [imageEntry fullPathToImageFile]]];
                
                _timeoutTimer=[NSTimer scheduledTimerWithTimeInterval:25 target:self selector:@selector(resetWaiting:) userInfo:nil repeats:NO];
                
                // Make the request
                [_httpWrapper sendPOSTRequestTo:imageUploadURL withDataBody:imageData withContentType:nil];
                
            } else if([imageEntry.needsDownload boolValue]==YES){

                NSString *serverURL=[[self getServerURL] stringByAppendingFormat:@"/getblob?guid=%@", imageEntry.imageGUID];
                [self showAlertWithString:serverURL];
                
                NSURL *imageGetURL=[NSURL URLWithString:[[self getServerURL] stringByAppendingFormat:@"/getblob?guid=%@", imageEntry.imageGUID]];
                //Mark that we are now waiting for a response from the server
                self.isWaitingForResponse=YES;
                
                [self showAlertWithString:[NSString stringWithFormat:@"Starting image get on server for: %@", [imageEntry imageGUID]]];
                
                _timeoutTimer=[NSTimer scheduledTimerWithTimeInterval:25 target:self selector:@selector(resetWaiting:) userInfo:nil repeats:NO];
                
                // Make the request
                [_httpWrapper sendPOSTRequestTo:imageGetURL withDataBody:nil withContentType:nil];

            }else if([imageEntry.needsDelete boolValue]==YES){
                NSString *serverURL=[[self getServerURL] stringByAppendingFormat:@"/delblob?guid=%@", imageEntry.imageGUID];
                [self showAlertWithString:serverURL];
                
                NSURL *imageDeleteURL=[NSURL URLWithString:[[self getServerURL] stringByAppendingFormat:@"/delblob?guid=%@", imageEntry.imageGUID]];
                //Mark that we are now waiting for a response from the server
                self.isWaitingForResponse=YES;
                
                [self showAlertWithString:[NSString stringWithFormat:@"Starting image delete on server for: %@", [imageEntry fullPathToImageFile]]];
                
                _timeoutTimer=[NSTimer scheduledTimerWithTimeInterval:25 target:self selector:@selector(resetWaiting:) userInfo:nil repeats:NO];
                
                // Make the request
                [_httpWrapper sendPOSTRequestTo:imageDeleteURL withDataBody:nil withContentType:nil];

            }else{
                [self showAlertWithString:[NSString stringWithFormat:@"Did not match needUpload or needDelete or needDownload: %@", imageEntry.imageGUID]];
            }
        }else{
            [self showAlertWithString:@"Did not start sync: did not find any images to upload, delete or download"];
        }
    }
    else
        [self delayTimers];
}

//This is used to reset whether we are waiting for a response in a timeout situation
-(void)resetWaiting:(NSTimer*)theTimer {
    if(self.isWaitingForResponse){
        [self showAlertWithString:@"Connection Timed Out: Cancelling Connection"];
        
        [_httpWrapper cancelConnection];
        
        if(_timeoutTimer){
            [self showAlertWithString:@"Releasing timeout timer"];
            _timeoutTimer=nil;
            [self showAlertWithString:@"Timeout timer released"];
        }
        
        self.isWaitingForResponse=NO;
        [self delayTimers];
    };
}

-(void) uploadImageWithImageGUID:(NSString *)imageGUIDToUpload{
    //Marks the image for upload in the data model
    //Image will be uploaded at the next queue processing
    
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToUpload];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *foundEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

    if(foundEntry) {
        foundEntry.needsUpload=[NSNumber numberWithBool:YES];
        foundEntry.needsDelete=[NSNumber numberWithBool:NO];
        foundEntry.needsDownload=[NSNumber numberWithBool:NO];
        
        NSError *saveError;
        if(![newMoc save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error marking image as needing upload with GUID: %@, Error: %@", imageGUIDToUpload, [saveError localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully marked image as needing upload with GUID: %@", imageGUIDToUpload]];
        }
        [self syncImages];
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Found no drug image with guid (%@) to mark as needing upload", imageGUIDToUpload]];
    }
}

-(void) downloadImageWithImageGUID:(NSString *)imageGUIDToDownload{
    //Marks the image for download in the data model
    //Image will be downloaded at the next queue processing
    
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToDownload];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *foundEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

    if(foundEntry) {
        foundEntry.needsDownload=[NSNumber numberWithBool:YES];
        foundEntry.needsDelete=[NSNumber numberWithBool:NO];
        foundEntry.needsUpload=[NSNumber numberWithBool:NO];
        
        NSError *saveError;
        if(![newMoc save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error marking image as needing download with GUID: %@, Error: %@", imageGUIDToDownload, [saveError localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully marked image as needing download with GUID: %@", imageGUIDToDownload]];
        }
    }
    else
    {
        //Create new drug image database object
        DrugImage *newDrugImage=(DrugImage *)[NSEntityDescription insertNewObjectForEntityForName:@"DrugImage" inManagedObjectContext:newMoc];
        newDrugImage.imageGUID=imageGUIDToDownload;
        newDrugImage.imagePath=nil;
        newDrugImage.needsDownload=[NSNumber numberWithBool:YES];
        newDrugImage.needsDelete=[NSNumber numberWithBool:NO];
        newDrugImage.needsUpload=[NSNumber numberWithBool:NO];
        
        NSError *error=nil;
        if(![newMoc save:&error]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error adding new drug image: %@",[error localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Saved new drug image with guid: %@",newDrugImage.imageGUID]];
        }
    }
    [self syncImages];
}

-(void) markImageGUIDAsDeleted:(NSString *)imageGUIDToDelete{
    
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", imageGUIDToDelete];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *foundEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

    if(foundEntry){
        
        //Image file will be deleted from the file system when the core data object is deleted
        [newMoc deleteObject:foundEntry];
        
        NSError *saveError;
        if(![newMoc save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error deleting image with GUID: %@, Error: %@", imageGUIDToDelete, [saveError localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully delete image with GUID: %@", imageGUIDToDelete]];
        }
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Found no drug image with guid (%@) to delete", imageGUIDToDelete]];
    }
}

//When we have received confirmation from the server that the image has been uploaded
//We can mark it as uploaded so we don't upload it again
-(void) markImageGUIDAsUploaded:(NSString *)guidToMark
{
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"DrugImage"];
    NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"imageGUID matches %@", guidToMark];
    [fetchRequest setPredicate:fetchPredicate];
    
    NSManagedObjectContext *newMoc=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMoc executeFetchRequest:fetchRequest error:&error];
    
    DrugImage *foundEntry = (resultsArray && [resultsArray count] > 0 ? [resultsArray firstObject] : nil);

    if(foundEntry){
        
        foundEntry.needsUpload=[NSNumber numberWithBool:NO];
        NSError *saveError;
        if(![newMoc save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error marking image as uploaded with GUID: %@, Error: %@", guidToMark, [saveError localizedDescription]]];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully marked image as uploaded with GUID: %@", guidToMark]];
        }
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Found no drug image with guid (%@) to mark as uploaded", guidToMark]];
    }
}

#pragma mark - connection setup
- (NSString*) getServerURL
{
	return [NSString stringWithFormat:@"%@://%@%@", _serverProtocol, _serverHost, _serverPath];
}

#pragma mark - CoreData
// Returns the managed object model for the DB data file.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    @synchronized(self) {
        if (_managedObjectModel != nil) {
            return _managedObjectModel;
        }
        
        NSString *modelPath = [[DosecastUtil getResourceBundle] pathForResource:@"DrugImages" ofType:@"momd"];
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        return _managedObjectModel;
    }
}

// Returns the persistent store coordinator for the DB data file.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    @synchronized(self) {
        if (_persistentStoreCoordinator != nil) {
            return _persistentStoreCoordinator;
        }
        
        // persistentStoreCoordinator options - for automatic, lightweight migration of past data model versions
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                                 NSFileProtectionNone, NSPersistentStoreFileProtectionKey, nil];
        
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        
        NSString *storePath=[self dataStorePath];
        NSURL *storeURL=[NSURL fileURLWithPath:storePath];
        
        if(![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error adding images db persistentStoreCoordinator: %@", [error localizedDescription]]];
        }
        
        return _persistentStoreCoordinator;
    }
}

//This method is used in the event that we need a MOC on a different queue
- (NSManagedObjectContext *)newManagedObjectContext
{
    NSManagedObjectContext *newMOC = [[NSManagedObjectContext alloc] init];
    [newMOC setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
    return newMOC;
}

-(NSString *)dataStorePath{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/DrugImages.sqlite"];
}

#pragma mark - HTTPWrapperDelegate
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didRetrieveData:(NSData *)data{
    
    if(_timeoutTimer){
        [self showAlertWithString:@"Invalidating timeout timer"];
        [_timeoutTimer invalidate];
        _timeoutTimer=nil;
        [self showAlertWithString:@"Timeout timer invalidated"];
    }
    
    // Don't retrieve any data if we got an error
	if (_httpWrapper.responseStatusCode != 200){

        if(_httpWrapper.responseStatusCode==404){
            //If an image does not exists on the server, we should remove it from our database
            //Check to see if this was a delete or get operation
            NSRange delblobRange=[[_httpWrapper.requestURL path] rangeOfString:@"delblob"];
            NSRange getblobRange=[[_httpWrapper.requestURL path] rangeOfString:@"getblob"];
            if(delblobRange.location!=NSNotFound || getblobRange.location!=NSNotFound){
                NSRange imageGuidRange=[[_httpWrapper.requestURL query] rangeOfString:@"guid="];
                if(imageGuidRange.location!=NSNotFound){
                    NSUInteger startOfGUID=imageGuidRange.location + imageGuidRange.length;
                    NSString *imageGuid=[[_httpWrapper.requestURL query] substringFromIndex:startOfGUID];
                    [self markImageGUIDAsDeleted:imageGuid];

                    //Reset an error delay we had in the past
                    _lastDelayInSeconds = DEFAULT_DELAY;
                }
            }
            self.isWaitingForResponse=NO;
            [self syncImages];
            return;
        }
        [self showAlertWithString:[NSString stringWithFormat:@"HTTP Path: %@", [_httpWrapper.requestURL path]]];
        [self showAlertWithString:[NSString stringWithFormat:@"Did not receive 200 response code: %i", _httpWrapper.responseStatusCode]];
        
        self.isWaitingForResponse=NO;
        [self delayTimers];
        return;
    }
	
    //Reset an error delay we had in the past
    _lastDelayInSeconds = DEFAULT_DELAY;
    
    NSString *responseText=[_httpWrapper responseAsText];
    //Delete blobs return empty data, so make sure this was an upload request
    //before updating the needsUpload flag
    if(responseText && [responseText length]>0)
    {
        NSRange putblobRange=[[_httpWrapper.requestURL path] rangeOfString:@"putblob"];
        if(putblobRange.location!=NSNotFound)
        {
            NSMutableDictionary *wrappedResponse = [_jsonParser objectWithString:responseText error:nil];
            NSMutableDictionary *unwrappedResponse=[wrappedResponse objectForKey:@"pillpopperResponse"];
            [self showAlertWithString:@"Response contains data"];
            
            [self showAlertWithString:[NSString stringWithFormat:@"Response String: %@", unwrappedResponse]];
            NSString *imageGUID=nil;
            [JSONConverter extractImageGUIDFromUnwrappedResponse:unwrappedResponse imageGUID:&imageGUID];
            if (imageGUID)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Successfully uploaded image GUID: %@", imageGUID]];
                
                [self markImageGUIDAsUploaded:imageGUID];
                
                if (![self needsImageUpload])
                {
                    [self showAlertWithString:@"all image uploads complete"];
                    
                    // Notify anyone who cares that we've just finished uploading a batch of images
                    [[NSNotificationCenter defaultCenter] postNotification:
                     [NSNotification notificationWithName:DrugImageUploadCompleteNotification object:nil]];
                }
            }
        }
    }else{
        //Image deletes do not return responses other than 200 codes, need to extract the GUID and delete it from the database
        NSRange delblobRange=[[_httpWrapper.requestURL path] rangeOfString:@"delblob"];
        NSRange getblobRange=[[_httpWrapper.requestURL path] rangeOfString:@"getblob"];
        if(delblobRange.location!=NSNotFound){
            NSRange imageGuidRange=[[_httpWrapper.requestURL query] rangeOfString:@"guid="];
            if(imageGuidRange.location!=NSNotFound){
                NSUInteger startOfGUID=imageGuidRange.location + imageGuidRange.length;
                NSString *imageGuidToMarkAsDeleted=[[_httpWrapper.requestURL query] substringFromIndex:startOfGUID];
                [self markImageGUIDAsDeleted:imageGuidToMarkAsDeleted];
            }
        }
        else if (getblobRange.location!=NSNotFound)
        {
            NSArray* URLComponents = [[_httpWrapper.requestURL query] componentsSeparatedByString:@"guid="];
            NSString* imageGUID = [URLComponents objectAtIndex:1];
            UIImage* image = [UIImage imageWithData:data];
            if (image)
            {
                [self imageGUIDWithImage:image withImageGUID:imageGUID shouldUploadImage:NO];
                // since the database object already exists, the above call will mark the object as no longer needing a download
                
                [self showAlertWithString:[NSString stringWithFormat:@"new image downloaded with guid %@", imageGUID]];
                
                // Notify anyone who cares that we've just finished downloading an image
                [[NSNotificationCenter defaultCenter] postNotification:
                 [NSNotification notificationWithName:DrugImageAvailableNotification object:nil]];

                if (![self needsImageDownload])
                {
                    [self showAlertWithString:@"all image downloads complete"];
                    
                    // Notify anyone who cares that we've just finished downloading a batch of images
                    [[NSNotificationCenter defaultCenter] postNotification:
                     [NSNotification notificationWithName:DrugImageDownloadCompleteNotification object:nil]];
                }
            }
        }
    }
    self.isWaitingForResponse=NO;
    
    // Since we finished successfully, immediately start on the next sync
    [self syncImages];
}

- (void)HTTPWrapperHasBadCredentials:(HTTPWrapper *)httpWrapper{
    [self showAlertWithString:@"HTTPWrapper has bad crendentials"];
    
    //Delay timers
    self.isWaitingForResponse=NO;
    [self delayTimers];
}

- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didFailWithError:(NSError *)error{
    [self showAlertWithString:[NSString stringWithFormat:@"Error from HTTPWrapper: %@", [error localizedDescription]]];
    //Delay timers
    self.isWaitingForResponse=NO;
    [self delayTimers];
}

- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didReceiveStatusCode:(int)statusCode{
    // If the status code != 200, don't set isWaitingForResponse to NO yet. Let this happen in
    // didRetrieveData because it will occur later, and we don't want to broadcast that we're done waiting yet.
    [self showAlertWithString:[NSString stringWithFormat:@"Received status code from HTTPWrapper: %i", statusCode]];
}

#pragma mark - Timer Mgmt

-(void)delayTimers{
    
    [self showAlertWithString:@"drug image sync failed"];
    
    // Notify anyone who cares that we've failed
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:DrugImageSyncFailedNotification object:nil]];

    NSString *stringToLog=[NSString stringWithFormat:@"Delaying timers"];
    [self showAlertWithString:stringToLog];
    if(_lastDelayInSeconds < 600.0){
        _lastDelayInSeconds=ceil(_lastDelayInSeconds * 1.5f);
    }
    
    [self showAlertWithString:[NSString stringWithFormat:@"New Delay: %d", (int)_lastDelayInSeconds]];
    
    [self syncImages];
}


#pragma mark - queues

#pragma mark - Logging
-(void) showAlertWithString:(NSString *)stringToShow{
    DebugLog(@"DrugImageManager: %@", stringToShow);
    
    if(_isDebugOn){
        NSLog(@"DrugImageManager: %@", stringToShow);
    }
}


@end
