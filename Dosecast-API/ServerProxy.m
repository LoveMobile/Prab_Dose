//
//  ServerProxy.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/11/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ServerProxy.h"
#import "HTTPWrapper.h"
#import "JSONConverter.h"
#import "DataModel.h"
#import "JSON.h"
#import "DosecastUtil.h"
#import "LocalNotificationManager.h"
#import "Drug.h"
#import "ReachabilityManager.h"
#import "DrugReminder.h"
#import "DrugDosage.h"
#import "AddressBookContact.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "HistoryManager.h"
#import "CustomNameIDList.h"
#import "Group.h"
#import "VersionNumber.h"
#import "GlobalSettings.h"
#import "SyncDevice.h"

static const double ASYNC_TIME_DELAY = 0.01;

static int HTTP_REQUEST_TIMEOUT_SECS = 30;

static ServerProxy *gInstance = nil;

static NSString *JSONContentType = @"application/json; charset=utf-8";

static NSString *CreateUserMethodName = @"createUser";
static NSString *SyncMethodName = @"sync";
static NSString *GetBlobMethodName = @"getBlob";
static NSString *GroupInfoByNameMethodName = @"groupInfoByName";
static NSString *GroupInfoByIDMethodName = @"groupInfoById";
static NSString *GroupJoinMethodName = @"groupJoin";
static NSString *GroupLeaveMethodName = @"groupLeave";
static NSString *GetRendezvousCodeMethodName = @"getRendezvousCode";
static NSString *SubmitRendezvousCodeMethodName = @"submitRendezvousCode";
static NSString *GetAttachedDevicesMethodName = @"getAttachedDevices";
static NSString *DetachDeviceMethodName = @"detachDevice";

static NSString *UserDataKey = @"userData";
static NSString *CurrentTimeKey = @"currentTime";

@implementation ServerProxy

// Singleton methods

+ (ServerProxy*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

- (id)init
{
    if ((self = [super init]))
    {
#ifdef DEBUG_SERVER
        serverProtocol = NSLocalizedStringWithDefaultValue(@"ServerProtocolDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"https", @"Protocol of URL for Dosecast server"]);
        serverHost = NSLocalizedStringWithDefaultValue(@"ServerHostDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"ppserver.montunosoftware.com", @"Domain name of Dosecast server host"]);
        serverPath = NSLocalizedStringWithDefaultValue(@"ServerPathDebug", @"Dosecast", [DosecastUtil getResourceBundle], @"/pillpopper-dev", @"The path to the debug server on the Dosecast server host"]);
#else
        serverProtocol = NSLocalizedStringWithDefaultValue(@"ServerProtocolRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"https", @"Protocol of URL for Dosecast server"]);
        serverHost = NSLocalizedStringWithDefaultValue(@"ServerHostRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"ppserver.montunosoftware.com", @"Domain name of Dosecast server host"]);
        serverPath = NSLocalizedStringWithDefaultValue(@"ServerPathRelease", @"Dosecast", [DosecastUtil getResourceBundle], @"/pillpopper", @"The path to the release server on the Dosecast server host"]);
#endif
        
		httpWrapper = [[HTTPWrapper alloc] init];
		httpWrapper.asynchronous = YES; 
		httpWrapper.delegate = self;
		responseDelegate = nil;
		methodCalled = [[NSMutableString alloc] initWithString:@""];
		jsonParser = [[SBJsonParser alloc] init];
        jsonWriter = [[SBJsonWriter alloc] init];
        timeoutTimer = nil;
    }
	
    return self;
}

- (void)dealloc
{
    if (timeoutTimer)
    {
        [timeoutTimer invalidate];
        timeoutTimer = nil;
    }    
}

- (NSString*) getServerURL
{
	return [NSString stringWithFormat:@"%@://%@%@", serverProtocol, serverHost, serverPath];
}

- (void) startServerCallTimers
{
    if (timeoutTimer) // shouldn't happen, but just to be safe
    {
        [timeoutTimer invalidate];
    }
    timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:HTTP_REQUEST_TIMEOUT_SECS target:self selector:@selector(handleTimeoutTimer:) userInfo:nil repeats:NO];
}

- (void) stopServerCallTimers
{
    if (timeoutTimer)
    {
        [timeoutTimer invalidate];
        timeoutTimer = nil;
    }
}

- (void) handleCommunicationsError:(NSString*)errorMessage
{
	ServerProxyStatus status = ServerProxyCommunicationsError;

    [self stopServerCallTimers];
    
	if ([methodCalled caseInsensitiveCompare:CreateUserMethodName] == NSOrderedSame)
	{
		DebugLog(@"createUser end: communications error");
		
		if ([responseDelegate respondsToSelector:@selector(createUserServerProxyResponse:errorMessage:)])
		{
			[responseDelegate createUserServerProxyResponse:status errorMessage:errorMessage];
		}
	}
	else if ([methodCalled caseInsensitiveCompare:SyncMethodName] == NSOrderedSame)
	{
		DebugLog(@"sync end: communications error");
		
		if ([responseDelegate respondsToSelector:@selector(syncServerProxyResponse:errorMessage:)])
		{
			[responseDelegate syncServerProxyResponse:status errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GetBlobMethodName] == NSOrderedSame)
	{
		DebugLog(@"getBlob end: communications error");
		
		if ([responseDelegate respondsToSelector:@selector(getBlobServerProxyResponse:data:errorMessage:)])
		{
			[responseDelegate getBlobServerProxyResponse:status data:nil errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupInfoByNameMethodName] == NSOrderedSame)
	{
		DebugLog(@"groupInfoByName end: communications error");
		
		if ([responseDelegate respondsToSelector:@selector(groupInfoByNameServerProxyResponse:groupFound:group:errorMessage:)])
		{
			[responseDelegate groupInfoByNameServerProxyResponse:status groupFound:NO group:nil errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupInfoByIDMethodName] == NSOrderedSame)
	{
		DebugLog(@"groupInfoByID end: communications error");
		
		if ([responseDelegate respondsToSelector:@selector(groupInfoByIDServerProxyResponse:groupFound:group:errorMessage:)])
		{
			[responseDelegate groupInfoByIDServerProxyResponse:status groupFound:NO group:nil errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupJoinMethodName] == NSOrderedSame)
	{
		DebugLog(@"groupJoin end: communications error");
		
        if ([responseDelegate respondsToSelector:@selector(groupJoinServerProxyResponse:groupJoinResult:gaveSubscription:gavePremium:errorMessage:)])
		{
			[responseDelegate groupJoinServerProxyResponse:status groupJoinResult:nil gaveSubscription:NO gavePremium:NO errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupLeaveMethodName] == NSOrderedSame)
	{
		DebugLog(@"groupLeave end: communications error");
		
        if ([responseDelegate respondsToSelector:@selector(groupLeaveServerProxyResponse:groupLeaveResult:tookAwaySubscription:tookAwayPremium:errorMessage:)])
		{
			[responseDelegate groupLeaveServerProxyResponse:status groupLeaveResult:nil tookAwaySubscription:NO tookAwayPremium:NO errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GetRendezvousCodeMethodName] == NSOrderedSame)
    {
        DebugLog(@"getRendezvousCode end: communications error");
        
        if ([responseDelegate respondsToSelector:@selector(getRendezvousCodeServerProxyResponse:rendezvousCode:expires:errorMessage:)])
        {
            [responseDelegate getRendezvousCodeServerProxyResponse:status rendezvousCode:nil expires:nil errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:SubmitRendezvousCodeMethodName] == NSOrderedSame)
    {
        DebugLog(@"submitRendezvousCode end: communications error");
        
        if ([responseDelegate respondsToSelector:@selector(submitRendezvousCodeServerProxyResponse:rendezvousResult:errorMessage:)])
        {
            [responseDelegate submitRendezvousCodeServerProxyResponse:status rendezvousResult:nil errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:GetAttachedDevicesMethodName] == NSOrderedSame)
    {
        DebugLog(@"getAttachedDevices end: communications error");
        
        if ([responseDelegate respondsToSelector:@selector(getAttachedDevicesServerProxyResponse:syncDevices:errorMessage:)])
        {
            [responseDelegate getAttachedDevicesServerProxyResponse:status syncDevices:nil errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:DetachDeviceMethodName] == NSOrderedSame)
    {
        DebugLog(@"detachDevice end: communications error");
        
        if ([responseDelegate respondsToSelector:@selector(detachDeviceServerProxyResponse:syncDevices:errorMessage:)])
        {
            [responseDelegate detachDeviceServerProxyResponse:status syncDevices:nil errorMessage:errorMessage];
        }
    }
}

-(void) handleTimeoutTimer:(NSTimer*)theTimer
{
    [httpWrapper cancelConnection];
    
    NSString* errorMessage = nil;
    if (![[ReachabilityManager getInstance] canReachInternet])
        errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
    else
        errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorServerCannotConnectWithoutError", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the server. Please try again in a few minutes, and if the issue persists, please contact us.", @"The error message when the client can't connect to the server"]), [DosecastUtil getProductAppName]];
    
    [self handleCommunicationsError:errorMessage];

    // The call above cleared the timeout timer. No need to do it again.
}

- (void)HTTPWrapper:(HTTPWrapper *)httpWrapper didFailWithError:(NSError *)error
{		
	NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorServerCannotConnect", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the server as a result of the following error: %@ Please try again in a few minutes, and if the issue persists, please contact us.", @"The error message when the client can't connect to the server"]), [DosecastUtil getProductAppName], [error localizedDescription]];
	[self handleCommunicationsError:errorMessage];
}

// Function to compare two drugs' nextReminder dates
NSComparisonResult compareSyncDevices(SyncDevice* d1, SyncDevice* d2, void* context)
{
    NSTimeInterval interval = [d1.lastSeen timeIntervalSinceDate:d2.lastSeen];
    if (interval < 0)
        return NSOrderedDescending;
    else if (interval > 0)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didRetrieveData:(NSData *)data
{	
	// Don't retrieve any data if we got an error
	if (httpWrapper.responseStatusCode != 200)
		return;
	
    [self stopServerCallTimers];
    
    // Special case: handle blob (binary data) separately
    if ([methodCalled caseInsensitiveCompare:GetBlobMethodName] == NSOrderedSame)
	{
		ServerProxyStatus status = ServerProxySuccess;
        
        DebugLog(@"getBlob end");
		
		if ([responseDelegate respondsToSelector:@selector(getBlobServerProxyResponse:data:errorMessage:)])
		{
			[responseDelegate getBlobServerProxyResponse:status data:data errorMessage:nil];
		}
        
        return;
	}

	// Ensure we received some data back. If not, assume it's because of a bad internet connection.
	if (!data || [data length] == 0)
	{
		NSString* errorMessageText = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalError", @"Dosecast", [DosecastUtil getResourceBundle], @"An internal error has occurred on the %@ server. Please try again in a few minutes, and if the issue persists, please contact us.", @"The error message when an internal server error occurs"]);
		NSString* errorMessage = [NSString stringWithFormat:errorMessageText, [DosecastUtil getProductAppName]];
		[self handleCommunicationsError:errorMessage];
		return;
	}
	
    NSString* json = [[NSString alloc] initWithData:data 
								  encoding:NSUTF8StringEncoding];
	
    NSString *stringToLog=[NSString stringWithFormat:@"Received JSON from server: %@", json];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

	// Parse JSON string and generate object hierarchy
	NSMutableDictionary* wrappedResponse = [jsonParser objectWithString:json error:nil];
	
	// Ensure we received a valid wrapped response from the server before continuing
	if (![JSONConverter isValidWrappedResponse:wrappedResponse])
	{
		NSString* errorMessageText = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalError", @"Dosecast", [DosecastUtil getResourceBundle], @"An internal error has occurred on the %@ server. Please try again in a few minutes, and if the issue persists, please contact us.", @"The error message when an internal server error occurs"]);
		NSString* errorMessage = [NSString stringWithFormat:errorMessageText, [DosecastUtil getProductAppName]];
		[self handleCommunicationsError:errorMessage];
		return;		
	}
	
	if ([methodCalled caseInsensitiveCompare:CreateUserMethodName] == NSOrderedSame)
	{		
		DataModel* dataModel = [DataModel getInstance];
		
		NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];

		NSString* errorMessage = nil;
        NSString* devErrorMessage = nil;
		ServerProxyStatus status = ServerProxySuccess;
        
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
		if (errorMessage)
			status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
		else
		{
			// Update the data model with the UserID
			dataModel.userID = [JSONConverter extractUserIDFromCreateUserResponse:unwrappedResponse];
            
            DebugLog(@"create user writing file");

            [[DataModel getInstance] writeToFile:nil];
		}

		if (status != ServerProxySuccess)
			DebugLog(@"createUser end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
		else
			DebugLog(@"createUser end: %d drugs exist", (int)[dataModel.drugList count]);

		if ([responseDelegate respondsToSelector:@selector(createUserServerProxyResponse:errorMessage:)])
		{
			[responseDelegate createUserServerProxyResponse:status errorMessage:errorMessage];
		}			
	}
    else if ([methodCalled caseInsensitiveCompare:SyncMethodName] == NSOrderedSame)
	{
		DataModel* dataModel = [DataModel getInstance];
		NSString* errorMessage = nil;
        BOOL shouldBeDetached = NO;
        BOOL success = [dataModel syncDrugData:wrappedResponse isInteractive:YES shouldBeDetached:&shouldBeDetached errorMessage:&errorMessage];
                
		ServerProxyStatus status = ServerProxySuccess;
		if (!success && errorMessage)
			status = ServerProxyInputError;
        else if (!success && shouldBeDetached)
        {
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        
		if (status != ServerProxySuccess)
			DebugLog(@"sync end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@)", errorMessage] : @""));
		else
			DebugLog(@"sync end: %d drugs exist", (int)[dataModel.drugList count]);
		
		if ([responseDelegate respondsToSelector:@selector(syncServerProxyResponse:errorMessage:)])
		{
			[responseDelegate syncServerProxyResponse:status errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupInfoByNameMethodName] == NSOrderedSame)
	{
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        Group* group = nil;
        BOOL groupFound = NO;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractGroupInfoFromGroupInfoByNameResponse:unwrappedResponse
                                                            groupFound:&groupFound
                                                               group:&group];
        }
        
		if (status != ServerProxySuccess)
            DebugLog(@"groupInfoByName end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
		else
			DebugLog(@"groupInfoByName end");
		
		if ([responseDelegate respondsToSelector:@selector(groupInfoByNameServerProxyResponse:groupFound:group:errorMessage:)])
		{
			[responseDelegate groupInfoByNameServerProxyResponse:status groupFound:groupFound group:group errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupInfoByIDMethodName] == NSOrderedSame)
	{
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        Group* group = nil;
        BOOL groupFound = NO;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractGroupInfoFromGroupInfoByIDResponse:unwrappedResponse
                                                          groupFound:&groupFound
                                                               group:&group];
        }
        
		if (status != ServerProxySuccess)
			DebugLog(@"groupInfoByID end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
		else
			DebugLog(@"groupInfoByID end");
		
		if ([responseDelegate respondsToSelector:@selector(groupInfoByIDServerProxyResponse:groupFound:group:errorMessage:)])
		{
			[responseDelegate groupInfoByIDServerProxyResponse:status groupFound:groupFound group:group errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupJoinMethodName] == NSOrderedSame)
	{
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSString* groupJoinResult = nil;
        NSMutableArray* groupsNewVal = [[NSMutableArray alloc] init];

        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL gavePremium = NO;
        BOOL gaveSubscription = NO;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractResultFromGroupJoinResponse:unwrappedResponse groupJoinResult:&groupJoinResult groups:groupsNewVal];
            AccountType oldType = [DataModel getInstance].globalSettings.accountType;
            [[DataModel getInstance].groups setArray:groupsNewVal]; // update the groups
            AccountType newType = [DataModel getInstance].globalSettings.accountType;
            gavePremium = (oldType == AccountTypeDemo && newType == AccountTypePremium);
            gaveSubscription = (oldType != AccountTypeSubscription && newType == AccountTypeSubscription);
            
            DebugLog(@"group join writing file");

            BOOL success = [[DataModel getInstance] writeToFile:&errorMessage];
			if (!success)
				status = ServerProxyInputError;
        }
        
		if (status != ServerProxySuccess)
			DebugLog(@"groupJoin end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
		else
			DebugLog(@"groupJoin end");
		
        if ([responseDelegate respondsToSelector:@selector(groupJoinServerProxyResponse:groupJoinResult:gaveSubscription:gavePremium:errorMessage:)])
		{
			[responseDelegate groupJoinServerProxyResponse:status groupJoinResult:groupJoinResult gaveSubscription:gaveSubscription gavePremium:gavePremium errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GroupLeaveMethodName] == NSOrderedSame)
	{
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSString* groupLeaveResult = nil;
        NSMutableArray* groupsNewVal = [[NSMutableArray alloc] init];

        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL tookAwayPremium = NO;
        BOOL tookAwaySubscription = NO;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractResultFromGroupLeaveResponse:unwrappedResponse groupLeaveResult:&groupLeaveResult groups:groupsNewVal];
            AccountType oldType = [DataModel getInstance].globalSettings.accountType;
            [[DataModel getInstance].groups setArray:groupsNewVal]; // update the groups
            AccountType newType = [DataModel getInstance].globalSettings.accountType;
            
            tookAwayPremium = (oldType == AccountTypePremium && newType == AccountTypeDemo);
            tookAwaySubscription = (oldType == AccountTypeSubscription && newType != AccountTypeSubscription);
            
            DebugLog(@"group leave writing file");

            BOOL success = [[DataModel getInstance] writeToFile:&errorMessage];
			if (!success)
				status = ServerProxyInputError;
        }
        
		if (status != ServerProxySuccess)
			DebugLog(@"groupLeave end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
		else
			DebugLog(@"groupLeave end");
		
		if ([responseDelegate respondsToSelector:@selector(groupLeaveServerProxyResponse:groupLeaveResult:tookAwaySubscription:tookAwayPremium:errorMessage:)])
		{
			[responseDelegate groupLeaveServerProxyResponse:status groupLeaveResult:groupLeaveResult tookAwaySubscription:tookAwaySubscription tookAwayPremium:tookAwayPremium errorMessage:errorMessage];
		}
	}
    else if ([methodCalled caseInsensitiveCompare:GetRendezvousCodeMethodName] == NSOrderedSame)
    {
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSString* rendezvousCode = nil;
        NSDate* expires = nil;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractResultFromGetRendezvousCodeResponse:unwrappedResponse rendezvousCode:&rendezvousCode expires:&expires];
        }
        
        if (status != ServerProxySuccess)
            DebugLog(@"getRendezvousCode end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
        else
            DebugLog(@"getRendezvousCode end");
        
        if ([responseDelegate respondsToSelector:@selector(getRendezvousCodeServerProxyResponse:rendezvousCode:expires:errorMessage:)])
        {
            [responseDelegate getRendezvousCodeServerProxyResponse:status rendezvousCode:rendezvousCode expires:expires errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:SubmitRendezvousCodeMethodName] == NSOrderedSame)
    {
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSString* rendezvousResult = nil;
        NSString* userID = nil;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            [JSONConverter extractResultFromSubmitRendezvousCodeResponse:unwrappedResponse rendezvousResult:&rendezvousResult userID:&userID];
            if ([rendezvousResult caseInsensitiveCompare:@"success"] == NSOrderedSame && userID)
            {
                DebugLog(@"submit rendezvous writing file");

                [DataModel getInstance].userID = userID;
                [[DataModel getInstance] writeToFile:nil];
            }
        }
        
        if (status != ServerProxySuccess)
            DebugLog(@"submitRendezvousCode end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
        else
            DebugLog(@"submitRendezvousCode end");
        
        if ([responseDelegate respondsToSelector:@selector(submitRendezvousCodeServerProxyResponse:rendezvousResult:errorMessage:)])
        {
            [responseDelegate submitRendezvousCodeServerProxyResponse:status rendezvousResult:rendezvousResult errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:GetAttachedDevicesMethodName] == NSOrderedSame)
    {
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSMutableArray* deviceList = nil;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            deviceList = [NSMutableArray arrayWithArray:[JSONConverter extractSyncDeviceListFromGetAttachedDevicesResponse:unwrappedResponse]];
            [deviceList sortUsingFunction:compareSyncDevices context:NULL];
        }
        
        if (status != ServerProxySuccess)
            DebugLog(@"getAttachedDevices end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
        else
            DebugLog(@"getAttachedDevices end");
        
        if ([responseDelegate respondsToSelector:@selector(getAttachedDevicesServerProxyResponse:syncDevices:errorMessage:)])
        {
            [responseDelegate getAttachedDevicesServerProxyResponse:status syncDevices:deviceList errorMessage:errorMessage];
        }
    }
    else if ([methodCalled caseInsensitiveCompare:DetachDeviceMethodName] == NSOrderedSame)
    {
        NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];
        NSArray* deviceList = nil;
        
        // Extract data model primitives from dictionary
        NSString *errorMessage = nil;
        NSString* devErrorMessage = nil;
        BOOL shouldBeDetached = NO;
        [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:&errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:&shouldBeDetached];
        
        ServerProxyStatus status = ServerProxySuccess;
        
        if (errorMessage)
            status = ServerProxyInputError;
        else if (shouldBeDetached)
        {
            DebugLog(@"should be detached");
            status = ServerProxyDeviceDetached;
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleDetached:) userInfo:nil repeats:NO];
        }
        else
        {
            deviceList = [JSONConverter extractSyncDeviceListFromGetAttachedDevicesResponse:unwrappedResponse];
        }
        
        if (status != ServerProxySuccess)
            DebugLog(@"detachDevice end: error%@", (errorMessage ? [NSString stringWithFormat:@" (%@ %@)", errorMessage, devErrorMessage] : @""));
        else
            DebugLog(@"detachDevice end");
        
        if ([responseDelegate respondsToSelector:@selector(detachDeviceServerProxyResponse:syncDevices:errorMessage:)])
        {
            [responseDelegate detachDeviceServerProxyResponse:status syncDevices:deviceList errorMessage:errorMessage];
        }
    }
}

-(void)handleDetached:(NSTimer*)theTimer
{
    DebugLog(@"execute detach: delete all data and write to file");
    DataModel* dataModel = [DataModel getInstance];
    dataModel.wasDetached = YES;
    [dataModel performDeleteAllData];
    [dataModel writeToFile:nil];
}

- (void)HTTPWrapper:(HTTPWrapper *)httpWrapper didReceiveStatusCode:(int)statusCode
{
	if (statusCode != 200)
	{
		NSString* errorMessageText = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalError", @"Dosecast", [DosecastUtil getResourceBundle], @"An internal error has occurred on the %@ server. Please try again in a few minutes, and if the issue persists, please contact us.", @"The error message when an internal server error occurs"]);
		NSString* errorMessage = [NSString stringWithFormat:errorMessageText, [DosecastUtil getProductAppName]];
		ServerProxyStatus status = ServerProxyServerError;
		
        [self stopServerCallTimers];
        
		if ([methodCalled caseInsensitiveCompare:CreateUserMethodName] == NSOrderedSame)
		{
			DebugLog(@"createUser end: error (server error)");

			if ([responseDelegate respondsToSelector:@selector(createUserServerProxyResponse:errorMessage:)])
			{
				[responseDelegate createUserServerProxyResponse:status errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:SyncMethodName] == NSOrderedSame)
		{
			DebugLog(@"sync end: error (server error)");
            
			if ([responseDelegate respondsToSelector:@selector(syncServerProxyResponse:errorMessage:)])
			{
				[responseDelegate syncServerProxyResponse:status errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GetBlobMethodName] == NSOrderedSame)
		{
			DebugLog(@"getBlob end: error (server error)");
            
			if ([responseDelegate respondsToSelector:@selector(getBlobServerProxyResponse:data:errorMessage:)])
			{
				[responseDelegate getBlobServerProxyResponse:status data:nil errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GroupInfoByNameMethodName] == NSOrderedSame)
		{
			DebugLog(@"groupInfoByName end: error (server error)");
            
			if ([responseDelegate respondsToSelector:@selector(groupInfoByNameServerProxyResponse:groupFound:group:errorMessage:)])
			{
				[responseDelegate groupInfoByNameServerProxyResponse:status groupFound:NO group:nil errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GroupInfoByIDMethodName] == NSOrderedSame)
		{
			DebugLog(@"groupInfoById end: error (server error)");
            
			if ([responseDelegate respondsToSelector:@selector(groupInfoByIDServerProxyResponse:groupFound:group:errorMessage:)])
			{
				[responseDelegate groupInfoByIDServerProxyResponse:status groupFound:NO group:nil errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GroupJoinMethodName] == NSOrderedSame)
		{
			DebugLog(@"groupJoin end: error (server error)");
            
            if ([responseDelegate respondsToSelector:@selector(groupJoinServerProxyResponse:groupJoinResult:gaveSubscription:gavePremium:errorMessage:)])
			{
				[responseDelegate groupJoinServerProxyResponse:status groupJoinResult:nil gaveSubscription:NO gavePremium:NO errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GroupLeaveMethodName] == NSOrderedSame)
		{
			DebugLog(@"groupLeave end: error (server error)");
            
			if ([responseDelegate respondsToSelector:@selector(groupLeaveServerProxyResponse:groupLeaveResult:tookAwaySubscription:tookAwayPremium:errorMessage:)])
			{
				[responseDelegate groupLeaveServerProxyResponse:status groupLeaveResult:nil tookAwaySubscription:NO tookAwayPremium:NO errorMessage:errorMessage];
			}
		}
        else if ([methodCalled caseInsensitiveCompare:GetRendezvousCodeMethodName] == NSOrderedSame)
        {
            DebugLog(@"getRendezvousCode end: error (server error)");
            
            if ([responseDelegate respondsToSelector:@selector(getRendezvousCodeServerProxyResponse:rendezvousCode:expires:errorMessage:)])
            {
                [responseDelegate getRendezvousCodeServerProxyResponse:status rendezvousCode:nil expires:nil errorMessage:errorMessage];
            }
        }
        else if ([methodCalled caseInsensitiveCompare:SubmitRendezvousCodeMethodName] == NSOrderedSame)
        {
            DebugLog(@"submitRendezvousCode end: error (server error)");
            
            if ([responseDelegate respondsToSelector:@selector(submitRendezvousCodeServerProxyResponse:rendezvousResult:errorMessage:)])
            {
                [responseDelegate submitRendezvousCodeServerProxyResponse:status rendezvousResult:nil errorMessage:errorMessage];
            }
        }
        else if ([methodCalled caseInsensitiveCompare:GetAttachedDevicesMethodName] == NSOrderedSame)
        {
            DebugLog(@"getAttachedDevices end: error (server error)");
            
            if ([responseDelegate respondsToSelector:@selector(getAttachedDevicesServerProxyResponse:syncDevices:errorMessage:)])
            {
                [responseDelegate getAttachedDevicesServerProxyResponse:status syncDevices:nil errorMessage:errorMessage];
            }
        }
        else if ([methodCalled caseInsensitiveCompare:DetachDeviceMethodName] == NSOrderedSame)
        {
            DebugLog(@"detachDevice end: error (server error)");
            
            if ([responseDelegate respondsToSelector:@selector(detachDeviceServerProxyResponse:syncDevices:errorMessage:)])
            {
                [responseDelegate detachDeviceServerProxyResponse:status syncDevices:nil errorMessage:errorMessage];
            }
        }
	}
}

-(void)handleCreateUserNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(createUserServerProxyResponse:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate createUserServerProxyResponse:ServerProxyCommunicationsError errorMessage:errorMessage];
	}
}

// Proxy for CreateUser call. If successful, updates data model with UserID.
- (void)createUser:(NSObject<ServerProxyDelegate>*)delegate
{		
	DataModel* dataModel = [DataModel getInstance];
 	
	DebugLog(@"createUser start: %d drugs exist", (int)[dataModel.drugList count]);

	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"createUser end: error (network unavailable)");

		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleCreateUserNetworkUnavailable:) userInfo:nil repeats:NO];
		return; 
	}
    
	[methodCalled setString:CreateUserMethodName];
	
	// Create JSON objects for CreateUser request
        
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    // If we are instructed to identify server account by the user data, do so now
    NSString* identifyByPref = nil;
    if ([dataModel.apiFlags getFlag:DosecastAPIIdentifyServerAccountByUserData])
        identifyByPref = UserDataKey;
    
	NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForCreateUserMethod:dataModel.hardwareID
                                                                                           partnerID:partnerIDName
                                                                                            language:[DosecastUtil getLanguageCountryCode]
                                                                                      identifyByPref:identifyByPref];
    
	NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
	
	// Generate JSON from JSON objects
	NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];
    
    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
	[httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];	
}

-(void)handleSyncNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(syncServerProxyResponse:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate syncServerProxyResponse:ServerProxyCommunicationsError errorMessage:errorMessage];
	}
}

// Proxy for Sync call. If successful, updates data model.
- (void)sync:(NSObject<ServerProxyDelegate>*)delegate
{
	DataModel* dataModel = [DataModel getInstance];
    
    DebugLog(@"sync start: %d drugs exist", (int)[dataModel.drugList count]);
    
    responseDelegate = delegate;
    if (![[ReachabilityManager getInstance] canReachInternet])
    {
        DebugLog(@"sync end: error (network unavailable)");
        
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleSyncNetworkUnavailable:) userInfo:nil repeats:NO];
        return;
    }
    
    [methodCalled setString:SyncMethodName];
        
    // Create JSON objects for request
    NSMutableArray* drugList = nil;
    NSMutableDictionary* globalPreferences = nil;
    [dataModel createInputsForSyncRequest:&drugList globalPreferences:&globalPreferences];

    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForSyncMethod:dataModel.hardwareID
                                                                                     partnerID:NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"])
                                                                                      language:[DosecastUtil getLanguageCountryCode]
                                                                                        userID:dataModel.userID
                                                                                      drugList:drugList
                                                                                deletedDrugIDs:dataModel.deletedDrugIDs
                                                                             globalPreferences:globalPreferences];
    
    
    // Add currentTime to unwrappedData dictionary
    long long currentTimeVal = (long long)[[NSDate date] timeIntervalSince1970];
    [unwrappedRequest setObject:[NSNumber numberWithLongLong:currentTimeVal] forKey:CurrentTimeKey];
    
    //Wrap request
    NSMutableDictionary *wrappedDictionary = [JSONConverter wrapRequest:unwrappedRequest];
    
    // Generate JSON from JSON objects
    NSString* jsonRequest = [jsonWriter stringWithObject:wrappedDictionary error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
    // Make the request
    [httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGetBlobNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(getBlobServerProxyResponse:data:errorMessage:)])
	{
        NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate getBlobServerProxyResponse:ServerProxyCommunicationsError data:nil errorMessage:errorMessage];
	}
}

// Proxy for GetBlob call. If successful, returns the blob data.
- (void)getBlob:(NSString*)guid
      respondTo:(NSObject<ServerProxyDelegate>*)delegate
{    
	DebugLog(@"getBlob start");
    
	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"getBlob end: error (network unavailable)");
        
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGetBlobNetworkUnavailable:) userInfo:nil repeats:NO];
		return;
	}
    
	[methodCalled setString:GetBlobMethodName];
			
    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
    [httpWrapper sendGETRequestTo:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self getServerURL], @"/getblob"]] withParameters:
     [NSDictionary dictionaryWithObjectsAndKeys:guid, @"guid", nil]];
}

-(void)handleGroupInfoByNameNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(groupInfoByNameServerProxyResponse:groupFound:group:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate groupInfoByNameServerProxyResponse:ServerProxyCommunicationsError groupFound:NO group:nil errorMessage:errorMessage];
	}
}

// Proxy for GroupInfoByName call. If successful, returns group info given the group name.
- (void)groupInfoByName:(NSString*)groupName
              respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
	DebugLog(@"groupInfoByName start");
    
	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"groupInfoByName end: error (network unavailable)");
        
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGroupInfoByNameNetworkUnavailable:) userInfo:nil repeats:NO];
		return;
	}
    
	[methodCalled setString:GroupInfoByNameMethodName];
	
	// Create JSON objects for getState request
	
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGroupInfoByNameMethod:partnerIDName
                                                                                                 language:[DosecastUtil getLanguageCountryCode]
                                                                                                groupName:groupName];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
	
	// Generate JSON from JSON objects
	NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
	
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
	[httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGroupInfoByIDNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(groupInfoByIDServerProxyResponse:groupFound:group:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate groupInfoByIDServerProxyResponse:ServerProxyCommunicationsError groupFound:NO group:nil errorMessage:errorMessage];
	}
}

// Proxy for GroupInfoByID call. If successful, returns group info given the group name.
- (void)groupInfoByID:(NSString*)groupId
              respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
	DebugLog(@"groupInfoByID start");
    
	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"groupInfoByID end: error (network unavailable)");
        
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGroupInfoByIDNetworkUnavailable:) userInfo:nil repeats:NO];
		return;
	}
    
	[methodCalled setString:GroupInfoByIDMethodName];
	
	// Create JSON objects for getState request
	
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGroupInfoByIDMethod:partnerIDName
                                                                                                 language:[DosecastUtil getLanguageCountryCode]
                                                                                                groupId:groupId];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
	
	// Generate JSON from JSON objects
	NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
	
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
	[httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGroupJoinNetworkUnavailable:(NSTimer*)theTimer
{
    if ([responseDelegate respondsToSelector:@selector(groupJoinServerProxyResponse:groupJoinResult:gaveSubscription:gavePremium:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate groupJoinServerProxyResponse:ServerProxyCommunicationsError groupJoinResult:nil gaveSubscription:NO gavePremium:NO errorMessage:errorMessage];
	}
}

// Proxy for GroupJoin call. If successful, returns expected result.
- (void)groupJoin:(NSString*)groupId
         password:(NSString*)password
        respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
	DebugLog(@"groupJoin start");
    
	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"groupJoin end: error (network unavailable)");
        
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGroupJoinNetworkUnavailable:) userInfo:nil repeats:NO];
		return;
	}
    
	[methodCalled setString:GroupJoinMethodName];
	
	// Create JSON objects for getState request
	
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGroupJoinMethod:dataModel.hardwareID
                                                                                          partnerID:partnerIDName
                                                                                           language:[DosecastUtil getLanguageCountryCode]
                                                                                             userID:dataModel.userID
                                                                                            groupId:groupId
                                                                                           password:password];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
	
	// Generate JSON from JSON objects
	NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
	
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
	[httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGroupLeaveNetworkUnavailable:(NSTimer*)theTimer
{
	if ([responseDelegate respondsToSelector:@selector(groupLeaveServerProxyResponse:groupLeaveResult:tookAwaySubscription:tookAwayPremium:errorMessage:)])
	{
		NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
		[responseDelegate groupLeaveServerProxyResponse:ServerProxyCommunicationsError groupLeaveResult:nil tookAwaySubscription:NO tookAwayPremium:NO errorMessage:errorMessage];
	}
}

// Proxy for GroupLeave call. If successful, returns expected result.
- (void)groupLeave:(NSString*)groupId
         respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
	DebugLog(@"groupLeave start");
    
	responseDelegate = delegate;
	if (![[ReachabilityManager getInstance] canReachInternet])
	{
		DebugLog(@"groupLeave end: error (network unavailable)");
        
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGroupLeaveNetworkUnavailable:) userInfo:nil repeats:NO];
		return;
	}
    
	[methodCalled setString:GroupLeaveMethodName];
	
	// Create JSON objects for getState request
	
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGroupLeaveMethod:dataModel.hardwareID
                                                                                          partnerID:partnerIDName
                                                                                           language:[DosecastUtil getLanguageCountryCode]
                                                                                             userID:dataModel.userID
                                                                                             groupId:groupId];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
	
	// Generate JSON from JSON objects
	NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
	
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
	// Make the request
	[httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGetRendezvousCodeNetworkUnavailable:(NSTimer*)theTimer
{
    if ([responseDelegate respondsToSelector:@selector(getRendezvousCodeServerProxyResponse:rendezvousCode:expires:errorMessage:)])
    {
        NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
        [responseDelegate getRendezvousCodeServerProxyResponse:ServerProxyCommunicationsError rendezvousCode:nil expires:nil errorMessage:errorMessage];
    }
}

// Proxy for GetRendezvousCode call. If successful, returns expected result.
- (void)getRendezvousCode:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
    DebugLog(@"getRendezvousCode start");
    
    responseDelegate = delegate;
    if (![[ReachabilityManager getInstance] canReachInternet])
    {
        DebugLog(@"getRendezvousCode end: error (network unavailable)");
        
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGetRendezvousCodeNetworkUnavailable:) userInfo:nil repeats:NO];
        return;
    }
    
    [methodCalled setString:GetRendezvousCodeMethodName];
    
    // Create JSON objects for getState request
    
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGetRendezvousCodeMethod:dataModel.hardwareID
                                                                                           partnerID:partnerIDName
                                                                                              userID:dataModel.userID];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
    
    // Generate JSON from JSON objects
    NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
    // Make the request
    [httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleSubmitRendezvousCodeNetworkUnavailable:(NSTimer*)theTimer
{
    if ([responseDelegate respondsToSelector:@selector(submitRendezvousCodeServerProxyResponse:rendezvousResult:errorMessage:)])
    {
        NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
        [responseDelegate submitRendezvousCodeServerProxyResponse:ServerProxyCommunicationsError rendezvousResult:nil errorMessage:errorMessage];
    }
}

// Proxy for SubmitRendezvousCode call. If successful, returns expected result given a rendezvous code.
- (void)submitRendezvousCode:(NSString*)rendezvousCode
                   respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
    DebugLog(@"submitRendezvousCode start");
    
    responseDelegate = delegate;
    if (![[ReachabilityManager getInstance] canReachInternet])
    {
        DebugLog(@"submitRendezvousCode end: error (network unavailable)");
        
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleSubmitRendezvousCodeNetworkUnavailable:) userInfo:nil repeats:NO];
        return;
    }
    
    [methodCalled setString:SubmitRendezvousCodeMethodName];
    
    // Create JSON objects for getState request
    
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForSubmitRendezvousCodeMethod:dataModel.hardwareID
                                                                                                  partnerID:partnerIDName
                                                                                                     userID:dataModel.userID
                                                                                                rendezvousCode:rendezvousCode];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
    
    // Generate JSON from JSON objects
    NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
    // Make the request
    [httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleGetAttachedDevicesNetworkUnavailable:(NSTimer*)theTimer
{
    if ([responseDelegate respondsToSelector:@selector(getAttachedDevicesServerProxyResponse:syncDevices:errorMessage:)])
    {
        NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
        [responseDelegate getAttachedDevicesServerProxyResponse:ServerProxyCommunicationsError syncDevices:nil errorMessage:errorMessage];
    }
}

// Proxy for GetAttachedDevices call. If successful, returns expected result.
- (void)getAttachedDevices:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
    DebugLog(@"getAttachedDevices start");
    
    responseDelegate = delegate;
    if (![[ReachabilityManager getInstance] canReachInternet])
    {
        DebugLog(@"getAttachedDevices end: error (network unavailable)");
        
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleGetAttachedDevicesNetworkUnavailable:) userInfo:nil repeats:NO];
        return;
    }
    
    [methodCalled setString:GetAttachedDevicesMethodName];
    
    // Create JSON objects for getState request
    
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForGetAttachedDevicesMethod:dataModel.hardwareID
                                                                                                     partnerID:partnerIDName
                                                                                                      userID:dataModel.userID];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
    
    // Generate JSON from JSON objects
    NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
    // Make the request
    [httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void)handleDetachDeviceNetworkUnavailable:(NSTimer*)theTimer
{
    if ([responseDelegate respondsToSelector:@selector(detachDeviceServerProxyResponse:syncDevices:errorMessage:)])
    {
        NSString* errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNetworkUnavailableMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ could not connect to the internet. Please ensure you have 3G or WiFi connectivity.", @"The message of the alert appearing when the network is unavailable"]), [DosecastUtil getProductAppName]];
        [responseDelegate detachDeviceServerProxyResponse:ServerProxyCommunicationsError syncDevices:nil errorMessage:errorMessage];
    }
}

// Proxy for DetachDevice call. If successful, returns expected result given a rendezvous code.
- (void)detachDevice:(NSString*)hardwareIDToDetach
           respondTo:(NSObject<ServerProxyDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];
    
    DebugLog(@"detachDevice start");
    
    responseDelegate = delegate;
    if (![[ReachabilityManager getInstance] canReachInternet])
    {
        DebugLog(@"detachDevice end: error (network unavailable)");
        
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY target:self selector:@selector(handleDetachDeviceNetworkUnavailable:) userInfo:nil repeats:NO];
        return;
    }
    
    [methodCalled setString:DetachDeviceMethodName];
    
    // Create JSON objects for getState request
    
    NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
    
    
    NSMutableDictionary* unwrappedRequest = [JSONConverter createUnwrappedRequestForDetachDeviceMethod:dataModel.hardwareID
                                                                                                     partnerID:partnerIDName
                                                                                                        userID:dataModel.userID
                                                                                                hardwareIDToDetach:hardwareIDToDetach];
    
    NSMutableDictionary* wrappedRequest = [JSONConverter wrapRequest:unwrappedRequest];
    
    // Generate JSON from JSON objects
    NSString* jsonRequest = [jsonWriter stringWithObject:wrappedRequest error:nil];
    
    NSString *stringToLog=[NSString stringWithFormat:@"Uploading JSON to server: %@", jsonRequest];
    [self showAlertWithString:stringToLog limitLengthToLog:YES];

    [self startServerCallTimers]; // start a timer to see if the server call takes too long
    
    // Make the request
    [httpWrapper sendPOSTRequestTo:[NSURL URLWithString:[self getServerURL]] withBody:jsonRequest withContentType:JSONContentType];
}

-(void) showAlertWithString:(NSString *)stringToShow limitLengthToLog:(BOOL)limitLengthToLog {
#ifdef DEBUG
        NSLog(@"ServerProxy: %@", stringToShow);
#endif
    
    if (limitLengthToLog)
    {
        if ([stringToShow length] > 50)
            stringToShow = [NSString stringWithFormat:@"%@...", [stringToShow substringToIndex:50]];
        DebugLog(@"ServerProxy: %@", stringToShow);
    }
    else
    {
        DebugLog(@"ServerProxy: %@", stringToShow);
    }
}

@end
