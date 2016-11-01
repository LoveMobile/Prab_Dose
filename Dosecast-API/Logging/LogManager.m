 //
//  LogManager.m
//  Dosecast-API
//
//  Created by Shawn Grimes on 8/22/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "LogManager.h"
#import "DosecastUtil.h"
#import "EventLogEntry.h"
#import "ReachabilityManager.h"
#import "JSONConverter.h"
#import "HTTPWrapper.h"
#import "JSON.h"
#import "ServerProxy.h"
#import "HistoryManager.h"
#import "DataModel.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import <CoreData/CoreData.h>
#import "VersionNumber.h"
#import "GlobalSettings.h"
#import "DrugImageManager.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"
#import "PillNotificationManager.h"

static NSString *JSONContentType = @"application/json; charset=utf-8";

static NSString *CurrentTimeKey = @"currentTime";

NSString *LogSyncCompleteNotification = @"LogSyncCompleteNotification";
NSString *LogSyncFailedNotification = @"LogSyncFailedNotification";

static LogManager *gInstance = nil;
static NSTimeInterval DEFAULT_DELAY = 5.0;

@implementation LogManager

@synthesize isWaitingForResponse=_isWaitingForResponse;
@synthesize backgroundTaskID=_backgroundTaskID;

#pragma mark - Setup
+(LogManager *)sharedManager{
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
        _jsonParser = [[SBJsonParser alloc] init];
        _jsonWriter = [[SBJsonWriter alloc] init];
        
        _lastDelayInSeconds = DEFAULT_DELAY;

        _timeoutTimer = nil;
        _uploadTimer = nil;
        
        _isWaitingForResponse=NO;
        _isWaitingForImageUpload = NO;
        _isWaitingForImageDownload = NO;
        _backgroundSyncPauseStack = [[NSMutableArray alloc] init];
        _isIncludingSyncRequest = NO;
        _attemptedSyncWhenPaused = NO;
        _syncErrorMessage = NO;
        _backgroundTaskID = UIBackgroundTaskInvalid;

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleImageUploadComplete:)
                                                     name:DrugImageUploadCompleteNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleImageDownloadComplete:)
                                                     name:DrugImageDownloadCompleteNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleImageSyncFail:)
                                                     name:DrugImageSyncFailedNotification
                                                   object:nil];

        _batchSize = 50;
        
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageUploadCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageDownloadCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageSyncFailedNotification object:nil];
}

- (void)handleImageUploadComplete:(NSNotification*)notification
{
    if (_isWaitingForImageUpload)
    {
        _isWaitingForImageUpload = NO;
        [self uploadLogs];
        [self startUploadLogsImmediately];
    }
}

- (void)handleImageDownloadComplete:(NSNotification*)notification
{
    if (_isWaitingForImageDownload)
    {
        _isWaitingForImageDownload = NO;
        
        [self showAlertWithString:@"notifying sync complete" limitLengthToLog:NO];
        
        // Notify anyone who cares that we've just finished synching successfully
        [[NSNotificationCenter defaultCenter] postNotification:
         [NSNotification notificationWithName:LogSyncCompleteNotification object:nil]];
    }
}

- (void)handleImageSyncFail:(NSNotification*)notification
{
    if (_isWaitingForImageUpload || _isWaitingForImageDownload)
    {
        [self showAlertWithString:@"notifying sync failed" limitLengthToLog:NO];

        // Notify anyone who cares that our sync attempt was foiled (for now)
        [[NSNotificationCenter defaultCenter] postNotification:
         [NSNotification notificationWithName:LogSyncFailedNotification object:nil]];
    }
}

- (void) clearAllLogs
{
    if (_timeoutTimer)
    {
        [_timeoutTimer invalidate];
        _timeoutTimer=nil;
    }
    
    if (_uploadTimer)
    {
        [_uploadTimer invalidate];
        _uploadTimer = nil;
    }
    self.isWaitingForResponse = NO;
    _isWaitingForImageUpload = NO;
    _isWaitingForImageDownload = NO;
    _lastDelayInSeconds = DEFAULT_DELAY;
    _attemptedSyncWhenPaused = NO;
    _isIncludingSyncRequest = NO;
    [_backgroundSyncPauseStack removeAllObjects];
    
    NSError *error=nil;
    NSPersistentStore *store = nil;
    NSArray* persistentStores = [[self persistentStoreCoordinator] persistentStores];
    if ([persistentStores count] > 0)
    {
        store=[persistentStores objectAtIndex:0];
        [[self persistentStoreCoordinator] removePersistentStore:store error:&error];
    }
    if(!error){
        if (store)
            [[NSFileManager defaultManager] removeItemAtURL:store.URL error:&error];
        if(!error){
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                     [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                                     NSFileProtectionNone, NSPersistentStoreFileProtectionKey, nil];
            
            if(![[self persistentStoreCoordinator] addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self dataStoreURL] options:options error:&error])
            {
                DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                                   message:[error localizedDescription]];
                UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
                UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
                
                [alert showInViewController:topNavController.topViewController];

                [self showAlertWithString:[NSString stringWithFormat:@"Error adding persistentStoreCoordinator: %@", [error localizedDescription]] limitLengthToLog:NO];
            }
            
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Error deleting store file: %@", [error localizedDescription]] limitLengthToLog:NO];
        }
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Error deleting Store: %@", [error localizedDescription]] limitLengthToLog:NO];
    }
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    [self clearAllLogs];
}

#pragma mark - Controls

-(void) addLogEntryWithUnwrappedRequest:(NSDictionary *)dictionaryToBeLogged uploadLogsAfter:(BOOL)uploadLogsAfter{
    [self showAlertWithString:[NSString stringWithFormat:@"Trying to add log entry: %@", dictionaryToBeLogged] limitLengthToLog:NO];
    NSManagedObjectContext *mOC = [self newManagedObjectContext];

    NSData *serializedDictionaryData=[self convertDictionaryToData:dictionaryToBeLogged];
    if(serializedDictionaryData){
        EventLogEntry *newLogEntry=(EventLogEntry *)[NSEntityDescription insertNewObjectForEntityForName:@"EventLogEntry" inManagedObjectContext:mOC];
        newLogEntry.entry=serializedDictionaryData;
        newLogEntry.guid=[DosecastUtil createGUID];
        newLogEntry.dateAdded=[NSDate date];
        NSError *error=nil;
        if(![mOC save:&error]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error adding new log entry: %@",[error localizedDescription]] limitLengthToLog:NO];
        }
        else
        {
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully added log entry to local DB with GUID: %@", newLogEntry.guid] limitLengthToLog:NO];
            if (uploadLogsAfter)
                [self uploadLogs];
        }
    }else{
        [self showAlertWithString:@"Can't add log entry, unable to serialize dictionary data" limitLengthToLog:NO];
    }
}

-(void)uploadLogs
{
    if (!_uploadTimer && !self.isWaitingForResponse && !_isWaitingForImageUpload && [self needsUploadOfLogEntries])
    {
        if ([self isPausingBackgroundSync])
            _attemptedSyncWhenPaused = YES;
        else
        {
            _uploadTimer = [NSTimer scheduledTimerWithTimeInterval:_lastDelayInSeconds target:self selector:@selector(uploadBatchLogs:) userInfo:nil repeats:NO];
        }
    }
}

- (BOOL) startUploadLogsImmediately
{
    if (_uploadTimer && _uploadTimer.isValid && !_isWaitingForImageUpload)
    {
        [_uploadTimer fire];
        return YES;
    }
    else
        return NO;
}

- (void) beginPausingBackgroundSync
{
    [_backgroundSyncPauseStack addObject:[NSNumber numberWithBool:YES]];
}

- (BOOL) isPausingBackgroundSync
{
    return ([_backgroundSyncPauseStack count] > 0);
}

// Called after ending a batch of LocalNotificationManager calls - for performance purposes
- (void) endPausingBackgroundSync
{
    if ([self isPausingBackgroundSync])
        [_backgroundSyncPauseStack removeLastObject];
    
    if (![self isPausingBackgroundSync] && _attemptedSyncWhenPaused)
    {
        [self uploadLogs];
        _attemptedSyncWhenPaused = NO;
    }
}

//This is used to reset whether we are waiting for a response in a timeout situation
-(void)resetWaiting:(NSTimer*)theTimer {
    if(self.isWaitingForResponse){
        [self showAlertWithString:@"Connection Timed Out: Cancelling Connection" limitLengthToLog:NO];
        
        [_httpWrapper cancelConnection];
        
        if(_timeoutTimer){
            [self showAlertWithString:@"Releasing timeout timer" limitLengthToLog:NO];
            _timeoutTimer=nil;
            [self showAlertWithString:@"Timeout timer released" limitLengthToLog:NO];
        }
        self.isWaitingForResponse=NO;
        [self delayTimers];
    };
}

- (BOOL) isSyncNeeded
{
    return ([DataModel getInstance].userRegistered && [DataModel getInstance].syncNeeded);
}

- (BOOL) needsUploadOfLogEntries
{
    NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"EventLogEntry"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES];
    [batchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    //Sets the batch size for uploading
    [batchRequest setFetchLimit:1];
    
    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
    BOOL hasLogEntries = (resultsArray != nil && [resultsArray count] > 0);
    return (hasLogEntries || [self isSyncNeeded]);
}

- (void) addUnwrappedRequest:(NSMutableDictionary*)unwrappedData toWrappedDictionaryArray:(NSMutableArray*)arrayWrappedDictionaries withReplayId:(NSString*)replayId
{
    // Add currentTime to unwrappedData dictionary
    long long currentTimeVal = (long long)[[NSDate date] timeIntervalSince1970];
    [unwrappedData setObject:[NSNumber numberWithLongLong:currentTimeVal] forKey:CurrentTimeKey];
    
    //Wrap request
    NSMutableDictionary *wrappedDictionary = [JSONConverter wrapRequest:unwrappedData];
    
    //Add ReplayId
    [JSONConverter addReplayIdToWrappedRequest:replayId wrappedRequest:wrappedDictionary];
    
    //Add wrapped request to array
    [arrayWrappedDictionaries addObject:wrappedDictionary];
}

-(void)uploadBatchLogs:(NSTimer*)theTimer
{
    _uploadTimer = nil;
    if ([self isPausingBackgroundSync]) // Bail if we shouldn't be doing this
    {
        _attemptedSyncWhenPaused = YES;
        
        [self showAlertWithString:@"notifying sync failed (background sync paused)" limitLengthToLog:NO];

        // Notify anyone who cares that we couldn't sync
        [[NSNotificationCenter defaultCenter] postNotification:
         [NSNotification notificationWithName:LogSyncFailedNotification object:nil]];
    }
    else if ([[DrugImageManager sharedManager] needsImageUpload]) // Don't begin uploading if an image upload is pending (images should always complete before proceeding)
    {
        _isWaitingForImageUpload = YES;
        
        [[DrugImageManager sharedManager] startSyncImagesImmediately]; // give the image manager a nudge
        
        // Don't report a sync failure. We'll be notified when the images are downloaded and will start then.
    }
    else if([[ReachabilityManager getInstance] canReachInternet])
    {
        DataModel* dataModel = [DataModel getInstance];
        
        //make sure the log manager should upload results and check to make sure we are not waiting for a response from the server
        [self showAlertWithString:@"Checking for logs to upload" limitLengthToLog:NO];
        
        NSFetchRequest *batchRequest=[NSFetchRequest fetchRequestWithEntityName:@"EventLogEntry"];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES];
        [batchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        //Sets the batch size for uploading
        [batchRequest setFetchLimit:_batchSize];
        
        NSManagedObjectContext *newMOC=[self newManagedObjectContext];
        
        NSError *error=nil;
        NSArray *resultsArray = [newMOC executeFetchRequest:batchRequest error:&error];
        
        // Only sync if there are no other log entries waiting to be uploaded. This is for legacy reasons (to flush out pending log entries)
        _isIncludingSyncRequest = ((!resultsArray || [resultsArray count] == 0) && [self isSyncNeeded]);

        // Upload to the server if we have any log entries
        if((resultsArray != nil && [resultsArray count]>0) || _isIncludingSyncRequest)
        {
            NSMutableArray *arrayWrappedDictionaries=[NSMutableArray arrayWithCapacity:_batchSize];
            if (resultsArray != nil && [resultsArray count]>0)
            {
                for (EventLogEntry *logEntry in resultsArray) {
                    NSMutableDictionary *unwrappedData=[NSMutableDictionary dictionaryWithDictionary:[self convertDataToDictionary:logEntry.entry]];

                    [self addUnwrappedRequest:unwrappedData toWrappedDictionaryArray:arrayWrappedDictionaries withReplayId:logEntry.guid];
                }
            }
            
            if (_isIncludingSyncRequest)
            {
                NSMutableArray* drugList = nil;
                NSMutableDictionary* globalPreferences = nil;
                [dataModel createInputsForSyncRequest:&drugList globalPreferences:&globalPreferences];
                
                NSMutableDictionary* unwrappedData = [JSONConverter createUnwrappedRequestForSyncMethod:dataModel.hardwareID
                                                                                                 partnerID:NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"])
                                                                                                  language:[DosecastUtil getLanguageCountryCode]
                                                                                                    userID:dataModel.userID
                                                                                                  drugList:drugList
                                                                                            deletedDrugIDs:dataModel.deletedDrugIDs
                                                                                         globalPreferences:globalPreferences];
                
                [self addUnwrappedRequest:unwrappedData toWrappedDictionaryArray:arrayWrappedDictionaries withReplayId:[DosecastUtil createGUID]];
            }
            
            NSMutableDictionary *wrappedMultiRequest=[JSONConverter wrapMultiRequest:arrayWrappedDictionaries getAllOutput:YES];
                
            // Generate JSON from JSON objects
            NSString* jsonRequest = [_jsonWriter stringWithObject:wrappedMultiRequest error:nil];
            
            //Mark that we are now waiting for a response from the server
            self.isWaitingForResponse=YES;
            NSString *serverURL=[NSString stringWithFormat:@"Sending to server: %@", [self getServerURL]];
            [self showAlertWithString:serverURL limitLengthToLog:NO];
            
            [self showAlertWithString:[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest] limitLengthToLog:YES];
            
            //Create _timeoutTimer
            _timeoutTimer=[NSTimer scheduledTimerWithTimeInterval:25 target:self selector:@selector(resetWaiting:) userInfo:nil repeats:NO];
            
            // Make the request
            [_httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
        }else{
            [self showAlertWithString:@"Did not start upload: did not find any logs to upload" limitLengthToLog:NO];
        }
    }
    else
    {
        // Don't report a failure here. It will be done in the call below.
        [self delayTimers];
    }
}

#pragma mark - Data and Dictionary Conversions
-(NSData *)convertDictionaryToData:(NSDictionary *)dictionaryToBeSerialized{
    NSString *errorStr=nil;
    NSData *serializedDictionaryData=[NSPropertyListSerialization dataFromPropertyList:dictionaryToBeSerialized format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorStr];
    if(!serializedDictionaryData){
        [self showAlertWithString:[NSString stringWithFormat:@"Error serializing dictionary: %@",errorStr] limitLengthToLog:NO];
    }
    return serializedDictionaryData;
}

-(NSDictionary *)convertDataToDictionary:(NSData *)serializedData{
    NSString *errorStr;
    NSDictionary *unWrappedDictionary=[NSPropertyListSerialization propertyListFromData:serializedData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorStr];
    if(!unWrappedDictionary){
        [self showAlertWithString:[NSString stringWithFormat:@"Error unserializing data into dictionary: %@",errorStr] limitLengthToLog:NO];
    }
    return unWrappedDictionary;
}

#pragma mark - connection setup
- (NSString*) getServerURL
{
	return [NSString stringWithFormat:@"%@://%@%@", _serverProtocol, _serverHost, _serverPath];
}


#pragma mark - CoreData Setup
-(void) deleteLogEntryWithGUID:(NSString *)guidToDelete{
    
    NSFetchRequest *fetchRequest=[NSFetchRequest fetchRequestWithEntityName:@"EventLogEntry"];
    NSPredicate *fetchPredicate=[NSPredicate predicateWithFormat:@"guid == %@", guidToDelete];
    [fetchRequest setPredicate:fetchPredicate];

    NSManagedObjectContext *newMOC=[self newManagedObjectContext];
    NSError *error=nil;
    NSArray *resultsArray = [newMOC executeFetchRequest:fetchRequest error:&error];
    if (resultsArray == nil)
    {
        [self showAlertWithString:[NSString stringWithFormat:@"Error finding log entry to delete: %@", [error localizedDescription]] limitLengthToLog:NO];
    }
    if([resultsArray count]>0){
        [newMOC deleteObject:[resultsArray objectAtIndex:0]];
        NSError *saveError;
        if(![newMOC save:&saveError]){
            [self showAlertWithString:[NSString stringWithFormat:@"Error deleting log entry with GUID: %@, Error: %@", guidToDelete, [saveError localizedDescription]] limitLengthToLog:NO];
        }else{
            [self showAlertWithString:[NSString stringWithFormat:@"Successfully deleted log entry with GUID: %@", guidToDelete] limitLengthToLog:NO];
        }
    }else{
        [self showAlertWithString:[NSString stringWithFormat:@"Found no log entry with guid (%@) to delete", guidToDelete] limitLengthToLog:NO];
    }
}

// Returns the managed object model for the DB data file.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    @synchronized(self) {
        if (_managedObjectModel != nil) {
            return _managedObjectModel;
        }
        
        NSString *modelPath = [[DosecastUtil getResourceBundle] pathForResource:@"Logging" ofType:@"momd"];
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
        if(![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self dataStoreURL] options:options error:&error])
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:[error localizedDescription]];
            UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            
            [alert showInViewController:topNavController.topViewController];

            [self showAlertWithString:[NSString stringWithFormat:@"Error adding persistentStoreCoordinator: %@", [error localizedDescription]] limitLengthToLog:NO];
        }

        
        return _persistentStoreCoordinator;
    }
}

//We no longer can use a single MOC, for thread safety, we need to use a unique MOC to each queue

- (NSManagedObjectContext *)newManagedObjectContext
{    
    NSManagedObjectContext *newMOC = [[NSManagedObjectContext alloc] init];
    [newMOC setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
    return newMOC;
}

-(NSURL *)dataStoreURL{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return [NSURL fileURLWithPath:[documentsDirectoryPath stringByAppendingPathComponent:@"EventLogs.sqlite"]];
}

#pragma mark - HTTPWrapperDelegate
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didRetrieveData:(NSData *)data{
    
    BOOL errorOccurred = NO;
    
    //Invalidate and release _timeoutTimer
    if(_timeoutTimer){
        [self showAlertWithString:@"Invalidating timeout timer" limitLengthToLog:NO];
        [_timeoutTimer invalidate];
        _timeoutTimer=nil;
        [self showAlertWithString:@"Timeout timer invalidated" limitLengthToLog:NO];
        }

    // Don't retrieve any data if we got an error
	if (_httpWrapper.responseStatusCode != 200){
        [self showAlertWithString:[NSString stringWithFormat:@"Did not receive 200 response code: %i", _httpWrapper.responseStatusCode] limitLengthToLog:NO];
        self.isWaitingForResponse=NO;
        [self delayTimers];
        return;
    }
	
	// Ensure we received some data back. If not, assume it's because of a bad internet connection.
	if (!data || [data length] == 0)
	{
        [self showAlertWithString:@"Could not connect to the internet." limitLengthToLog:NO];
        self.isWaitingForResponse=NO;
        [self delayTimers];
		return;
	}
	
    NSString* json = [[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding];
    
    [self showAlertWithString:[NSString stringWithFormat:@"Received JSON from server: %@", json] limitLengthToLog:YES];

    // Parse JSON string and generate object hierarchy
    NSMutableDictionary* wrappedMultiResponse = [_jsonParser objectWithString:json error:nil];
	
    NSMutableArray *arrayMultiResponse=[JSONConverter extractWrappedMultiResponse:wrappedMultiResponse];
    int numResponses = (int)[arrayMultiResponse count];
    
    for (int i = 0; i < numResponses; i++)
    {
        NSMutableDictionary *wrappedResponse = [arrayMultiResponse objectAtIndex:i];
        
        // Ensure we received a valid wrapped response from the server before continuing
        if (![JSONConverter isValidWrappedResponse:wrappedResponse])
        {
            [self showAlertWithString:@"Could not connect to the internet" limitLengthToLog:NO];
            self.isWaitingForResponse=NO;
            [self delayTimers];
            return;
        }
        
        if (_isIncludingSyncRequest && i == (numResponses-1))
        {
            DataModel* dataModel = [DataModel getInstance];
            BOOL shouldBeDetached = NO;
            NSString* errorMessage = nil;
            [dataModel syncDrugData:wrappedResponse isInteractive:NO shouldBeDetached:&shouldBeDetached errorMessage:&errorMessage];
            _syncErrorMessage = errorMessage;
            
            if (shouldBeDetached)
            {
                [self showAlertWithString:@"should be detached" limitLengthToLog:NO];
                _syncErrorMessage = nil;
                [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
            }
            else
            {
                if (errorMessage)
                    errorOccurred = YES;
                
                if (!_syncErrorMessage)
                {
                    if ([[DrugImageManager sharedManager] needsImageDownload])
                    {
                        _isWaitingForImageDownload = YES;
                        [[DrugImageManager sharedManager] startSyncImagesImmediately];
                    }
                    else
                    {
                        [self showAlertWithString:@"notifying sync complete" limitLengthToLog:NO];

                        // Notify anyone who cares that we've just finished synching successfully
                        [[NSNotificationCenter defaultCenter] postNotification:
                         [NSNotification notificationWithName:LogSyncCompleteNotification object:nil]];
                    }
                }
            }
        }
        else
        {
            // Delete the log entry corresponding to this response

            NSMutableDictionary *unwrappedResponse=[JSONConverter unwrapResponse:wrappedResponse];

            NSString *replayID=nil;
            [JSONConverter extractReplayIDFromUnwrappedResponse:unwrappedResponse replayID:&replayID];
            if (replayID)
            {
                [self showAlertWithString:[NSString stringWithFormat:@"Successfully uploaded GUID: %@", replayID] limitLengthToLog:NO];
                [self deleteLogEntryWithGUID:replayID];
            }
        }
    }

    self.isWaitingForResponse=NO;
    if (errorOccurred)
        [self delayTimers];
    else
    {
        //Reset an error delay we had in the past
        _lastDelayInSeconds = DEFAULT_DELAY;
    }
    [self uploadLogs];
}


-(void)handleDetached:(NSTimer*)theTimer
{
    [self showAlertWithString:@"execute detach: delete all data and write to file" limitLengthToLog:NO];

    DataModel* dataModel = [DataModel getInstance];
    dataModel.wasDetached = YES;
    [dataModel performDeleteAllData];
    [dataModel writeToFile:nil];
    
    [self showAlertWithString:@"notifying sync complete" limitLengthToLog:NO];

    // Notify anyone who cares that we've just finished synching successfully
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:LogSyncCompleteNotification object:nil]];
}

- (void)HTTPWrapperHasBadCredentials:(HTTPWrapper *)httpWrapper{
    [self showAlertWithString:@"HTTPWrapper has bad crendentials" limitLengthToLog:NO];
    
    //Delay timers
    self.isWaitingForResponse=NO;
    [self delayTimers];
}

- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didFailWithError:(NSError *)error{
    [self showAlertWithString:[NSString stringWithFormat:@"Error from HTTPWrapper: %@", [error localizedDescription]] limitLengthToLog:NO];
    //Delay timers
    self.isWaitingForResponse=NO;
    [self delayTimers];
}
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didReceiveStatusCode:(int)statusCode{
    // If the status code != 200, don't set isWaitingForResponse to NO yet. Let this happen in
    // didRetrieveData because it will occur later, and we don't want to broadcast that we're done waiting yet.
    [self showAlertWithString:[NSString stringWithFormat:@"Received status code from HTTPWrapper: %i", statusCode] limitLengthToLog:NO];
}

#pragma mark - queue mgmt

#pragma mark - Timer Mgmt
-(void)delayTimers{
    
    [self showAlertWithString:@"notifying sync failed" limitLengthToLog:NO];

    // Notify anyone who cares that our sync attempt was foiled (for now)
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:LogSyncFailedNotification object:_syncErrorMessage]];
    _syncErrorMessage = nil;
    
    [self showAlertWithString:@"Delaying timers" limitLengthToLog:NO];
    //Delay timers:
    if(_lastDelayInSeconds < 600.0){
        _lastDelayInSeconds=ceil(_lastDelayInSeconds * 1.5f);
    }
    
    [self showAlertWithString:[NSString stringWithFormat:@"New Delay: %d", (int)_lastDelayInSeconds] limitLengthToLog:NO];

    [self uploadLogs];
}

#pragma mark - alerts
-(void) showAlertWithString:(NSString *)stringToShow limitLengthToLog:(BOOL)limitLengthToLog {
    if(_isDebugOn){
        NSLog(@"LogManager: %@", stringToShow);
    }

    if (limitLengthToLog)
    {
        if ([stringToShow length] > 50)
            stringToShow = [NSString stringWithFormat:@"%@...", [stringToShow substringToIndex:50]];
        DebugLog(@"LogManager: %@", stringToShow);
    }
    else
    {
        DebugLog(@"LogManager: %@", stringToShow);
    }
}

@end
