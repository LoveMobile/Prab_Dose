//
//  ServerProxy.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/11/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPWrapperDelegate.h"
#import "ServerProxyDelegate.h"
#import "DosecastCoreTypes.h"

@class HTTPWrapper;
@class SBJsonParser;
@class SBJsonWriter;
@class DrugReminder;
@class DrugDosage;
@class AddressBookContact;

@interface ServerProxy : NSObject<HTTPWrapperDelegate> {
@private
	HTTPWrapper* httpWrapper;
	NSMutableString* methodCalled;
	NSObject<ServerProxyDelegate>* __weak responseDelegate;
	SBJsonParser* jsonParser;
    SBJsonWriter* jsonWriter;
	NSString* serverHost;
	NSString* serverPath;
	NSString* serverProtocol;
    NSTimer* timeoutTimer;
}

// Singleton methods
+ (ServerProxy*) getInstance;

// Proxy for CreateUser call. If successful, updates data model with UserID.
- (void)createUser:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for Sync call. If successful, updates data model.
- (void)sync:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GetBlob call. If successful, returns the blob data.
- (void)getBlob:(NSString*)guid
      respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GroupInfoByName call. If successful, returns group info given the group name.
- (void)groupInfoByName:(NSString*)groupName
              respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GroupInfoByID call. If successful, returns group info given the group ID.
- (void)groupInfoByID:(NSString*)groupId
              respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GroupJoin call. If successful, returns expected result.
- (void)groupJoin:(NSString*)groupId
         password:(NSString*)password
            respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GroupLeave call. If successful, returns expected result.
- (void)groupLeave:(NSString*)groupId
        respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GetRendezvousCode call. If successful, returns expected result.
- (void)getRendezvousCode:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for SubmitRendezvousCode call. If successful, returns expected result given a rendezvous code.
- (void)submitRendezvousCode:(NSString*)rendezvousCode
                   respondTo:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for GetAttachedDevices call. If successful, returns expected result.
- (void)getAttachedDevices:(NSObject<ServerProxyDelegate>*)delegate;

// Proxy for DetachDevice call. If successful, returns expected result given a rendezvous code.
- (void)detachDevice:(NSString*)hardwareIDToDetach
           respondTo:(NSObject<ServerProxyDelegate>*)delegate;

@end
