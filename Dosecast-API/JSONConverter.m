//
//  JSONConverter.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/10/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "JSONConverter.h"
#import "DosecastUtil.h"
#import "CustomNameIDList.h"
#import "Group.h"
#import "GlobalSettings.h"
#import "SyncDevice.h"
#import "HistoryManager.h"

// Keys for Drug info data in dictionary used for JSON I/O
static NSString *HistoryPreferencesKey = @"preferences";
static NSString *DrugIDKey = @"pillId";

// Keys for data model primitives in dictionary used for JSON I/O
static NSString *TOSAgreedKey = @"tosAgreed";

static NSString *DrugListKey = @"pillList";

// Keys for method parameters stored in dictionary used for JSON I/O
static NSString *ActionKey = @"action";
static NSString *CreateUserAction = @"CreateUser";
static NSString *GetStateAction = @"GetState";
static NSString *CreatePillAction = @"CreatePill";
static NSString *EditPillAction = @"EditPill";
static NSString *DeletePillAction = @"DeletePill";
static NSString *DeleteAllPillsAction = @"DeleteAllPills";
static NSString *UndoPillAction = @"UndoPill";
static NSString *TakePillAction = @"TakePill";
static NSString *SkipPillAction = @"SkipPill";
static NSString *PostponePillAction = @"PostponePill";
static NSString *GetRendezvousCodeAction = @"GetRendezvousCode";
static NSString *SubmitRendezvousCodeAction = @"SubmitRendezvousCode";
static NSString *GetAttachedDevicesAction = @"GetAttachedDevices";
static NSString *DetachDeviceAction = @"DetachDevice";
static NSString *SetBedtimeAction = @"SetBedtime";
static NSString *SetPreferencesAction = @"SetPreferences";
static NSString *EditHistoryEventAction = @"EditHistoryEvent";
static NSString *DeleteHistoryEventAction = @"DeleteHistoryEvent";
static NSString *DeleteAllHistoryEventsAction = @"DeleteAllHistoryEvents";
static NSString *GetHistoryEventsAction = @"GetHistoryEvents";
static NSString *GroupInfoByNameAction = @"GroupInfoByName";
static NSString *GroupInfoByIDAction = @"GroupInfoById";
static NSString *GroupJoinAction = @"GroupJoin";
static NSString *GroupLeaveAction = @"GroupLeave";
static NSString *SyncAction = @"Sync";
static NSString *SyncProtocolVersionKey = @"syncProtocol";

static NSString *HardwareIDKey = @"hardwareId";
static NSString *UserIDKey = @"userId";
static NSString *SecondsKey = @"seconds";
static NSString *ErrorTextKey = @"errorText";
static NSString *DevInfoKey = @"devInfo";
static NSString *DetachedKey = @"detached";
static NSString *DoseTimeKey = @"pillTime";
static NSString *ReceiptKey = @"receipt";
static NSString *ReplayIDKey = @"replayId";
static NSString *RendezvousCodeKey = @"rendezvousCode";
static NSString *RendezvousCodeExpiresKey = @"expires";
static NSString *RendezvousResultKey = @"rendezvousResult";
static NSString *DeviceListKey = @"deviceList";
static NSString *HardwareToDetachKey = @"hardwareToDetach";
static NSString *FriendlyNameKey = @"friendlyName";
static NSString *LastSeenKey = @"lastSeen";
static NSString *ImageGUIDKey = @"guid";
static NSString *HistoryEventGUIDKey = @"guid";
static NSString *DeleteHistoryKey = @"deleteHistory";
static NSString *RequestKey = @"pillpopperRequest";
static NSString *MultiRequestKey = @"pillpopperMultiRequest";
static NSString *GetAllOutputKey = @"getAllOutput";
static NSString *MultiRequestArrayKey = @"requestArray";
static NSString *ResponseKey = @"pillpopperResponse";
static NSString *MultiResponseKey = @"pillpopperMultiResponse";
static NSString *MultiResponseArrayKey = @"responseArray";
static NSString *PartnerIDKey = @"partnerId";
static NSString *HistoryEventIDKey = @"opId";
static NSString *StopIntervalKey = @"stopInterval";
static NSString *CreationDateKey = @"creationDate";
static NSString *ScheduleDateKey = @"scheduleDate";
static NSString *OperationKey = @"operation";
static NSString *OperationDataKey = @"operationData";
static NSString *EventDescriptionKey = @"eventDescription";
static NSString *PersonIDKey = @"personId";
static NSString *HistoryEventsKey = @"historyEvents";
static NSString *IdentifyByPrefKey = @"identifyByPref";
static NSString *GroupNameKey = @"groupName";
static NSString *GroupInfoKey = @"groupInfo";
static NSString *GroupIDKey = @"groupId";
static NSString *GroupFoundKey = @"groupFound";
static NSString *GroupDescriptionsKey = @"descriptions";
static NSString *GroupDisplayNameKey = @"displayName";
static NSString *GroupTOSAddendumKey = @"tosAddendum";
static NSString *GroupDescriptionKey = @"description";
static NSString *GroupGivesPremiumKey = @"givesPremium";
static NSString *GroupGivesSubscriptionKey = @"givesSubscription";
static NSString *GroupLogoGUIDKey = @"logoGuid";
static NSString *GroupPasswordKey = @"password";
static NSString *GroupMembershipKey = @"groupMembership";
static NSString *GroupJoinResultKey = @"groupJoin";
static NSString *GroupLeaveResultKey = @"groupLeave";
static NSString *DeletedDrugIDsKey = @"deletedPillList";
static NSString *DeviceNameKey = @"deviceName";
static NSString *OSVersionKey = @"osVersion";
static NSString *LanguageKey = @"language";

@implementation JSONConverter

// Returns whether a valid wrapped response exists in the given NSDictionary
+(BOOL)isValidWrappedResponse:(NSMutableDictionary*)wrappedResponse
{
	if (!wrappedResponse)
		return NO;
	
	return [wrappedResponse objectForKey:ResponseKey] != nil;
}

// Extracts the wrapped multi responses from a wrapped multi-response
+(NSMutableArray*)extractWrappedMultiResponse:(NSMutableDictionary*)wrappedMultiResponse
{
    NSMutableDictionary* multiResponse = [wrappedMultiResponse objectForKey:MultiResponseKey];
    if (multiResponse)
        return [multiResponse objectForKey:MultiResponseArrayKey];
    else
        return nil;
}

// Extracts the unwrapped response from a wrapped response
+(NSMutableDictionary*)unwrapResponse:(NSMutableDictionary*)wrappedResponse
{
	return [wrappedResponse objectForKey:ResponseKey];
}

// Returns the wrapped request for an unwrapped request
+(NSMutableDictionary*)wrapRequest:(NSMutableDictionary*)unwrappedRequest
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:unwrappedRequest, RequestKey, nil];
}

// Returns the wrapped multi-request for an array of wrapped requests
+(NSMutableDictionary*)wrapMultiRequest:(NSMutableArray*)wrappedRequests
                           getAllOutput:(BOOL)getAllOutput //Whether the server should use all output mode (YES) or last output mode (NO)
{
    NSMutableDictionary* multiRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt:(getAllOutput ? 1 : 0)], GetAllOutputKey,
                                         wrappedRequests, MultiRequestArrayKey, nil];
    
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:multiRequest, MultiRequestKey, nil];
}

// Extracts any errors from an unwrapped response
+(void)extractErrorsFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                         userErrorMessage:(NSString**)userErrorMessage
                          devErrorMessage:(NSString**)devErrorMessage
                         shouldBeDetached:(BOOL*)shouldBeDetached
{
    *userErrorMessage = [unwrappedResponse objectForKey:ErrorTextKey];
    *devErrorMessage = [unwrappedResponse objectForKey:DevInfoKey];
    if (*userErrorMessage && (*devErrorMessage))
    {
#ifdef DEBUG
        NSLog(@"Server error: %@ (%@)", *userErrorMessage, *devErrorMessage);
#endif
        DebugLog(@"Server error: %@ (%@)", *userErrorMessage, *devErrorMessage);
    }
    else if (*userErrorMessage && !(*devErrorMessage))
        *devErrorMessage = @"";
    
    NSNumber* detachedNum = [unwrappedResponse objectForKey:DetachedKey];
    *shouldBeDetached = (detachedNum && [detachedNum intValue] == 1);
}

// Extracts the replayID from an unwrapped response
+(void)extractReplayIDFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                                   replayID:(NSString**)replayID
{
    *replayID = [unwrappedResponse objectForKey:ReplayIDKey];
}

// Extracts the imageGUID from an unwrapped response
+(void)extractImageGUIDFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                                   imageGUID:(NSString**)imageGUID
{
    *imageGUID = [unwrappedResponse objectForKey:ImageGUIDKey];
}

// Adds a given replayId to the given wrapped request
+(void)addReplayIdToWrappedRequest:(NSString*)replayId
                    wrappedRequest:(NSMutableDictionary*)wrappedRequest
{
    NSMutableDictionary* unwrappedRequest = [wrappedRequest objectForKey:RequestKey];
    if (unwrappedRequest && replayId)
    {
        [unwrappedRequest setObject:replayId forKey:ReplayIDKey];
        [wrappedRequest setObject:unwrappedRequest forKey:RequestKey];
    }
}

+(void)extractGroupInfoFromDictionary:(NSMutableDictionary*)dict
                           groupFound:(BOOL*)groupFound
                              group:(Group**)group
{
    *groupFound = NO;
    *group = nil;
    
    if (!dict)
        return;
    
    NSNumber* groupFoundNum = [dict objectForKey:GroupFoundKey];
    if (groupFoundNum && [groupFoundNum intValue] > 0)
    {
        *groupFound = YES;
        NSMutableDictionary* descriptions = [dict objectForKey:GroupDescriptionsKey];
        if (descriptions)
        {
            NSMutableDictionary* language = [descriptions objectForKey:[DosecastUtil getLanguageCode]];
            if (!language)
                language = [descriptions objectForKey:@"en"];
            
            if (language)
            {
                BOOL givesPremium = NO;
                NSNumber* givesPremiumNum = [dict objectForKey:GroupGivesPremiumKey];
                if (givesPremiumNum && [givesPremiumNum intValue] > 0)
                    givesPremium = YES;

                BOOL givesSubscription = NO;
                NSNumber* givesSubscriptionNum = [dict objectForKey:GroupGivesSubscriptionKey];
                if (givesSubscriptionNum && [givesSubscriptionNum intValue] > 0)
                    givesSubscription = YES;

                *group = [[Group alloc] init:[dict objectForKey:GroupIDKey]
                                 displayName:[language objectForKey:GroupDisplayNameKey]
                                 tosAddendum:[language objectForKey:GroupTOSAddendumKey]
                                 description:[language objectForKey:GroupDescriptionKey]
                                    logoGUID:[language objectForKey:GroupLogoGUIDKey]
                                givesPremium:givesPremium
                          givesSubscription:givesSubscription];
            }
        }
    }
}

+(void)populateGroupListFromDict:(NSMutableDictionary*)dict
                                  groups:(NSMutableArray*)groups
{
    NSMutableArray* groupList = [dict objectForKey:GroupMembershipKey];
	if (groups && groupList)
    {
        [groups removeAllObjects];
        for (NSMutableDictionary* groupBlock in groupList)
        {
            BOOL found = NO;
            Group* group = nil;
            [JSONConverter extractGroupInfoFromDictionary:groupBlock
                                               groupFound:&found
                                                    group:&group];
            if (found)
                [groups addObject:group];
        }
    }
}

+(NSMutableDictionary*) createFileWriteDictionaryFromGroupInfo:(BOOL)groupFound
                                                       groupId:(NSString*)groupId
                                                  languageCode:(NSString*)languageCode
                                                   displayName:(NSString*)displayName
                                                   description:(NSString*)description
                                                   tosAddendum:(NSString*)tosAddendum
                                                      logoGUID:(NSString*)logoGUID
                                                  givesPremium:(BOOL)givesPremium
                                             givesSubscription:(BOOL)givesSubscription
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    
    [dict setObject:[NSNumber numberWithInt:(groupFound ? 1 : 0)] forKey:GroupFoundKey];
    
    [dict setObject:[NSNumber numberWithInt:(givesPremium ? 1 : 0)] forKey:GroupGivesPremiumKey];

    [dict setObject:[NSNumber numberWithInt:(givesSubscription ? 1 : 0)] forKey:GroupGivesSubscriptionKey];

    if (groupId)
        [dict setObject:groupId forKey:GroupIDKey];
    
    NSMutableDictionary* descriptions = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary* language = [[NSMutableDictionary alloc] init];
    
    if (displayName)
        [language setObject:displayName forKey:GroupDisplayNameKey];
    
    if (tosAddendum)
        [language setObject:tosAddendum forKey:GroupTOSAddendumKey];
    
    if (description)
        [language setObject:description forKey:GroupDescriptionKey];
    
    if (logoGUID)
        [language setObject:logoGUID forKey:GroupLogoGUIDKey];
    
    [descriptions setObject:language forKey:languageCode];
    
    [dict setObject:descriptions forKey:GroupDescriptionsKey];
    
    return dict;
}

// Populates the given dictionary from the given groups
+(void)populateDictFromGroupList:(NSMutableDictionary*)dict
                          groups:(NSMutableArray*)groups
{
    NSMutableArray* groupList = [[NSMutableArray alloc] init];
    for (Group* group in groups)
    {
        NSMutableDictionary* groupBlock = [JSONConverter createFileWriteDictionaryFromGroupInfo:YES
                                                                               groupId:group.groupID
                                                                          languageCode:@"en"
                                                                           displayName:group.displayName
                                                                           description:group.description
                                                                           tosAddendum:group.tosAddendum
                                                                              logoGUID:group.logoGUID
                                                                          givesPremium:group.givesPremium
                                                                     givesSubscription:group.givesSubscription];
        [groupList addObject:groupBlock];
    }
    [dict setObject:groupList forKey:GroupMembershipKey];
}


// Creates the unwrapped request for the CreateUser method
+(NSMutableDictionary*)createUnwrappedRequestForCreateUserMethod:(NSString*)hardwareId
                                                       partnerID:(NSString*)partnerID
                                                        language:(NSString*)language
                                                  identifyByPref:(NSString*)identifyByPref
{
	NSNumber* tosAgreedNum = [NSNumber numberWithInt:1];
	NSMutableDictionary* unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 CreateUserAction, ActionKey,
									 partnerID, PartnerIDKey,
									 hardwareId, HardwareIDKey,
                                     language, LanguageKey,
									 tosAgreedNum, TOSAgreedKey,
                                     nil];
        
    if (identifyByPref)
        [unwrappedRequest setObject:identifyByPref forKey:IdentifyByPrefKey];

    return unwrappedRequest;
}

// Creates the unwrapped request for Sync method
+(NSMutableDictionary*)createUnwrappedRequestForSyncMethod:(NSString*)hardwareId
                                                 partnerID:(NSString*)partnerID
                                                  language:(NSString*)language
                                                    userID:(NSString*)userID
                                                  drugList:(NSMutableArray*)drugList
                                           deletedDrugIDs:(NSMutableSet*)deletedDrugIDs
                                         globalPreferences:(NSMutableDictionary*)globalPreferences
{
	NSMutableDictionary* unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             SyncAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             language, LanguageKey,
                                             [NSNumber numberWithInt:2], SyncProtocolVersionKey,
                                             userID, UserIDKey,
                                             [NSNumber numberWithInt:1], TOSAgreedKey,
                                             [NSMutableArray arrayWithArray:[deletedDrugIDs allObjects]], DeletedDrugIDsKey,
                                             drugList, DrugListKey,
                                             nil];
    
    if (globalPreferences)
        [unwrappedRequest addEntriesFromDictionary:globalPreferences];
    
    return unwrappedRequest;
}

// Extracts the user ID from the CreateUser response
+(NSString*)extractUserIDFromCreateUserResponse:(NSMutableDictionary*)unwrappedResponse
{
	return [unwrappedResponse objectForKey:UserIDKey];
}

// Creates the unwrapped request for GetRendezvous method
+(NSMutableDictionary*)createUnwrappedRequestForGetRendezvousCodeMethod:(NSString*)hardwareId
                                                              partnerID:(NSString*)partnerID
                                                                 userID:(NSString*)userID
{
    NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GetRendezvousCodeAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             userID, UserIDKey,
                                             nil];
    
    return unwrappedRequest;
}

// Extracts the result from the GetRendezvousCode response
+(void)extractResultFromGetRendezvousCodeResponse:(NSMutableDictionary*)unwrappedResponse
                                   rendezvousCode:(NSString**)rendezvousCode
                                          expires:(NSDate**)expires
{
    *rendezvousCode = [unwrappedResponse objectForKey:RendezvousCodeKey];
    
    *expires = nil;
    NSNumber* expiresNum = [unwrappedResponse objectForKey:RendezvousCodeExpiresKey];
    if (expiresNum && [expiresNum longLongValue] > 0)
        *expires = [NSDate dateWithTimeIntervalSince1970:[expiresNum longLongValue]];
}

// Creates the unwrapped request for SubmitRendezvousCode method
+(NSMutableDictionary*)createUnwrappedRequestForSubmitRendezvousCodeMethod:(NSString*)hardwareId
                                                                 partnerID:(NSString*)partnerID
                                                                    userID:(NSString*)userID
                                                            rendezvousCode:(NSString*)rendezvousCode
{
    NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             SubmitRendezvousCodeAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             userID, UserIDKey,
                                             rendezvousCode, RendezvousCodeKey,
                                             nil];
    
    return unwrappedRequest;
}

// Extracts the result from the SubmitRendezvousCode response
+(void)extractResultFromSubmitRendezvousCodeResponse:(NSMutableDictionary*)unwrappedResponse
                                    rendezvousResult:(NSString**)rendezvousResult
                                              userID:(NSString**)userID
{
    *rendezvousResult = [unwrappedResponse objectForKey:RendezvousResultKey];
    *userID = [unwrappedResponse objectForKey:UserIDKey];
}

// Creates the unwrapped request for GetAttachedDevices method
+(NSMutableDictionary*)createUnwrappedRequestForGetAttachedDevicesMethod:(NSString*)hardwareId
                                                               partnerID:(NSString*)partnerID
                                                                  userID:(NSString*)userID
{
    NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GetAttachedDevicesAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             userID, UserIDKey,
                                             nil];
    
    return unwrappedRequest;
}


// Extracts the device list from the GetAttachedDevices response
+(NSMutableArray*)extractSyncDeviceListFromGetAttachedDevicesResponse:(NSMutableDictionary*)unwrappedResponse
{
    NSMutableArray* syncDeviceList = [[NSMutableArray alloc] init];
    NSMutableArray* syncDeviceDictArray = [unwrappedResponse objectForKey:DeviceListKey];
    if (syncDeviceDictArray)
    {
        for (NSMutableDictionary* syncDeviceDict in syncDeviceDictArray)
        {
            NSString* friendlyName = [syncDeviceDict objectForKey:FriendlyNameKey];
            NSString* hardwareID = [syncDeviceDict objectForKey:HardwareIDKey];
            
            NSDate* lastSeen = nil;
            NSNumber* lastSeenNum = [syncDeviceDict objectForKey:LastSeenKey];
            if (lastSeenNum && [lastSeenNum longLongValue] > 0)
                lastSeen = [NSDate dateWithTimeIntervalSince1970:[lastSeenNum longLongValue]];

            [syncDeviceList addObject:
             [[SyncDevice alloc] init:friendlyName hardwareID:hardwareID lastSeen:lastSeen]];
        }
    }
    
    return syncDeviceList;
}

// Creates the unwrapped request for DetachDevice method
+(NSMutableDictionary*)createUnwrappedRequestForDetachDeviceMethod:(NSString*)hardwareId
                                                         partnerID:(NSString*)partnerID
                                                            userID:(NSString*)userID
                                                hardwareIDToDetach:(NSString*)hardwareIDToDetach
{
    NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             DetachDeviceAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             userID, UserIDKey,
                                             hardwareIDToDetach, HardwareToDetachKey,
                                             nil];
    
    return unwrappedRequest;
}

// Creates a dictionary of a history event for a sync request
+(NSMutableDictionary*)createHistoryEventDictForSyncRequest:(NSString*)guid
                                               creationDate:(NSDate*)creationDate
                                                  operation:(NSString*)operation
                                              operationData:(NSString*)operationData
                                           eventDescription:(NSString*)eventDescription
                                               scheduleDate:(NSDate*)scheduleDate
                                            preferencesDict:(NSDictionary*)preferencesDict
{
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithLongLong:(long long)[creationDate timeIntervalSince1970]], CreationDateKey,
                                             operation, OperationKey,
                                             guid, HistoryEventGUIDKey, nil];
    
    if (eventDescription)
        [unwrappedRequest setObject:eventDescription forKey:EventDescriptionKey];
    
    if (scheduleDate)
        [unwrappedRequest setObject:[NSNumber numberWithLongLong:(long long)[scheduleDate timeIntervalSince1970]] forKey:ScheduleDateKey];
    
    if (operationData && [operationData caseInsensitiveCompare:@"nil"] != NSOrderedSame)
        [unwrappedRequest setObject:operationData forKey:OperationDataKey];
    
    if (preferencesDict)
        [unwrappedRequest setObject:preferencesDict forKey:HistoryPreferencesKey];
    
    return unwrappedRequest;
}

// Creates the unwrapped request for DeleteAllHistoryEvents method
+(NSMutableDictionary*)createUnwrappedRequestForDeleteAllHistoryEventsMethod:(NSString*)hardwareId
                                                                   partnerID:(NSString*)partnerID
                                                                    language:(NSString*)language
                                                                      userID:(NSString*)userID
                                                                      drugID:(NSString*)drugID
{
    if (!drugID)
        drugID = @"*";
    
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             DeleteAllHistoryEventsAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             language, LanguageKey,
                                             userID, UserIDKey,
                                             drugID, DrugIDKey,
                                             @"*", PersonIDKey,
                                             nil];
    
    return unwrappedRequest;
}

// Creates the unwrapped request for groupInfoByName method
+(NSMutableDictionary*)createUnwrappedRequestForGroupInfoByNameMethod:(NSString*)partnerID
                                                             language:(NSString*)language
                                                            groupName:(NSString*)groupName
{
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GroupInfoByNameAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             language, LanguageKey,
                                             groupName, GroupNameKey,
                                             nil];
        
    return unwrappedRequest;
}

// Creates the unwrapped request for groupInfoById method
+(NSMutableDictionary*)createUnwrappedRequestForGroupInfoByIDMethod:(NSString*)partnerID
                                                           language:(NSString*)language
                                                            groupId:(NSString*)groupId
{
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GroupInfoByIDAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             language, LanguageKey,
                                             groupId, GroupIDKey,
                                             nil];
    
    return unwrappedRequest;
}

// Creates the unwrapped request for groupJoin method
+(NSMutableDictionary*)createUnwrappedRequestForGroupJoinMethod:(NSString*)hardwareId
                                                      partnerID:(NSString*)partnerID
                                                       language:(NSString*)language
                                                         userID:(NSString*)userID
                                                        groupId:(NSString*)groupId
                                                       password:(NSString*)password
{
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GroupJoinAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             language, LanguageKey,
                                             userID, UserIDKey,
                                             groupId, GroupIDKey,
                                             password, GroupPasswordKey,
                                             nil];
    
    return unwrappedRequest;
}
// Creates the unwrapped request for groupLeave method
+(NSMutableDictionary*)createUnwrappedRequestForGroupLeaveMethod:(NSString*)hardwareId
                                                       partnerID:(NSString*)partnerID
                                                        language:(NSString*)language
                                                          userID:(NSString*)userID
                                                         groupId:(NSString*)groupId
{
    // Create a mutable dictionary of drug data so far
	NSMutableDictionary *unwrappedRequest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             GroupLeaveAction, ActionKey,
                                             partnerID, PartnerIDKey,
                                             hardwareId, HardwareIDKey,
                                             language, LanguageKey,
                                             userID, UserIDKey,
                                             groupId, GroupIDKey,
                                             nil];
    
    return unwrappedRequest;
}

// Extracts the history event data from the given history event dictionary
+(void)extractHistoryEventDataFromHistoryEvent:(NSMutableDictionary*)historyEventDict
                                          guid:(NSString**)guid
                                  creationDate:(NSDate**)creationDate
                              eventDescription:(NSString**)eventDescription
                                     operation:(NSString**)operation
                                 operationData:(NSString**)operationData
                                  scheduleDate:(NSDate**)scheduleDate
                               preferencesDict:(NSDictionary**)preferencesDict
{
    *eventDescription = [historyEventDict objectForKey:EventDescriptionKey];
    *operation = [historyEventDict objectForKey:OperationKey];
    
    NSString *operationDataStr = [historyEventDict objectForKey:OperationDataKey];
    if (operationDataStr && [operationDataStr caseInsensitiveCompare:@"nil"] == NSOrderedSame)
        operationDataStr = nil;
    *operationData = operationDataStr;
    
    *guid = [historyEventDict objectForKey:HistoryEventGUIDKey];
    
    *creationDate = nil;
    NSNumber* creationDateNum = [historyEventDict objectForKey:CreationDateKey];
    if (creationDateNum && [creationDateNum longLongValue] > 0)
        *creationDate = [NSDate dateWithTimeIntervalSince1970:[creationDateNum longLongValue]];

    *scheduleDate = nil;
    NSNumber* scheduleDateNum = [historyEventDict objectForKey:ScheduleDateKey];
    if (scheduleDateNum && [scheduleDateNum longLongValue] > 0)
        *scheduleDate = [NSDate dateWithTimeIntervalSince1970:[scheduleDateNum longLongValue]];
    
    NSDictionary* dict = [historyEventDict objectForKey:HistoryPreferencesKey];
    if (!dict)
        dict = [NSDictionary dictionary];
    *preferencesDict = dict;
}

// Extracts the group info from the GroupInfoByName response
+(void)extractGroupInfoFromGroupInfoByNameResponse:(NSMutableDictionary*)unwrappedResponse
                                        groupFound:(BOOL*)groupFound
                                             group:(Group**)group
{
    *groupFound = NO;
    *group = nil;
    
    return [JSONConverter extractGroupInfoFromDictionary:[unwrappedResponse objectForKey:GroupInfoKey]
                                              groupFound:groupFound
                                                   group:group];
}

// Extracts the group info from the GroupInfoById response
+(void)extractGroupInfoFromGroupInfoByIDResponse:(NSMutableDictionary*)unwrappedResponse
                                      groupFound:(BOOL*)groupFound
                                           group:(Group**)group
{
    *groupFound = NO;
    *group = nil;
    
    return [JSONConverter extractGroupInfoFromDictionary:[unwrappedResponse objectForKey:GroupInfoKey]
                                              groupFound:groupFound
                                                   group:group];
}

// Extracts the results from the GroupJoin response
+(void)extractResultFromGroupJoinResponse:(NSMutableDictionary*)unwrappedResponse
                          groupJoinResult:(NSString**)groupJoinResult
                                   groups:(NSMutableArray*)groups
{
    *groupJoinResult = [unwrappedResponse objectForKey:GroupJoinResultKey];
    
    [JSONConverter populateGroupListFromDict:unwrappedResponse groups:groups];
}

// Extracts the results from the GroupLeave response
+(void)extractResultFromGroupLeaveResponse:(NSMutableDictionary*)unwrappedResponse
                          groupLeaveResult:(NSString**)groupLeaveResult
                                    groups:(NSMutableArray*)groups
{
    *groupLeaveResult = [unwrappedResponse objectForKey:GroupLeaveResultKey];
    
    [JSONConverter populateGroupListFromDict:unwrappedResponse groups:groups];
}

@end
