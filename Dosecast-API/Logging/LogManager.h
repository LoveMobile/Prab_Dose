//
//  LogManager.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 8/22/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPWrapperDelegate.h"
@class HTTPWrapper;
@class SBJsonParser;
@class SBJsonWriter;

// This notification is fired when a sync has been completed
extern NSString *LogSyncCompleteNotification;

// This notification is fired when a sync attempt has failed
extern NSString *LogSyncFailedNotification;

@interface LogManager : NSObject <HTTPWrapperDelegate>
{
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    BOOL _isDebugOn;
    BOOL _isWaitingForResponse;
    BOOL _isIncludingSyncRequest;
    NSMutableArray* _backgroundSyncPauseStack;
    BOOL _attemptedSyncWhenPaused;
    BOOL _isWaitingForImageUpload;
    BOOL _isWaitingForImageDownload;
    
    NSTimer *_timeoutTimer;
    NSTimer *_uploadTimer;

    //This is used to extend a delay of uploading if errors are encountered
    NSInteger _lastDelayInSeconds;
    
    NSString *_serverHost;
	NSString *_serverPath;
	NSString *_serverProtocol;
    NSString *_syncErrorMessage;
    HTTPWrapper *_httpWrapper;
    SBJsonParser *_jsonParser;
    SBJsonWriter *_jsonWriter;
    UIBackgroundTaskIdentifier _backgroundTaskID;

    NSInteger _batchSize;
}

//Property to say if an upload has been initiated and we are waiting for the response from the server
@property(nonatomic, assign) BOOL isWaitingForResponse;
@property(nonatomic, assign) BOOL isBackgroundSyncPaused;

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskID;

//Add a log entry to the logging database to be uploaded.  Will return YES if successful.
-(void) addLogEntryWithUnwrappedRequest:(NSDictionary *)dictionaryToBeLogged uploadLogsAfter:(BOOL)uploadLogsAfter;

-(void)clearAllLogs;

-(void)uploadLogs;
-(BOOL)startUploadLogsImmediately;

-(void)beginPausingBackgroundSync;
-(BOOL)isPausingBackgroundSync;
-(void)endPausingBackgroundSync;

+(LogManager *)sharedManager;

@end
