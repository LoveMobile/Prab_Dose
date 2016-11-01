//
//  JSONConverter.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/10/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DosecastCoreTypes.h"

@class CustomNameIDList;
@class Group;
@class GlobalSettings;

@interface JSONConverter : NSObject {
}

// ------------ Methods for processing requests

// Creates the unwrapped request for the CreateUser method
+(NSMutableDictionary*)createUnwrappedRequestForCreateUserMethod:(NSString*)hardwareId
                                                       partnerID:(NSString*)partnerID
                                                        language:(NSString*)language
                                                  identifyByPref:(NSString*)identifyByPref;

// Creates the unwrapped request for Sync method
+(NSMutableDictionary*)createUnwrappedRequestForSyncMethod:(NSString*)hardwareId
                                                     partnerID:(NSString*)partnerID
                                                      language:(NSString*)language
                                                        userID:(NSString*)userID
                                                  drugList:(NSMutableArray*)drugList
                                           deletedDrugIDs:(NSMutableSet*)deletedDrugIDs
                                         globalPreferences:(NSMutableDictionary*)globalPreferences;

// Creates the unwrapped request for GetRendezvousCode method
+(NSMutableDictionary*)createUnwrappedRequestForGetRendezvousCodeMethod:(NSString*)hardwareId
                                                              partnerID:(NSString*)partnerID
                                                                 userID:(NSString*)userID;

// Creates the unwrapped request for SubmitRendezvousCode method
+(NSMutableDictionary*)createUnwrappedRequestForSubmitRendezvousCodeMethod:(NSString*)hardwareId
                                                                 partnerID:(NSString*)partnerID
                                                                    userID:(NSString*)userID
                                                            rendezvousCode:(NSString*)rendezvousCode;

// Creates the unwrapped request for GetAttachedDevices method
+(NSMutableDictionary*)createUnwrappedRequestForGetAttachedDevicesMethod:(NSString*)hardwareId
                                                               partnerID:(NSString*)partnerID
                                                                  userID:(NSString*)userID;

// Creates the unwrapped request for DetachDevice method
+(NSMutableDictionary*)createUnwrappedRequestForDetachDeviceMethod:(NSString*)hardwareId
                                                               partnerID:(NSString*)partnerID
                                                                  userID:(NSString*)userID
                                                      hardwareIDToDetach:(NSString*)hardwareIDToDetach;

// Creates the unwrapped request for DeleteAllHistoryEvents method
+(NSMutableDictionary*)createUnwrappedRequestForDeleteAllHistoryEventsMethod:(NSString*)hardwareId
                                                               partnerID:(NSString*)partnerID
                                                                language:(NSString*)language
                                                                  userID:(NSString*)userID
                                                                  drugID:(NSString*)drugID;

// Creates the unwrapped request for groupInfoByName method
+(NSMutableDictionary*)createUnwrappedRequestForGroupInfoByNameMethod:(NSString*)partnerID
                                                             language:(NSString*)language
                                                            groupName:(NSString*)groupName;

// Creates the unwrapped request for groupInfoById method
+(NSMutableDictionary*)createUnwrappedRequestForGroupInfoByIDMethod:(NSString*)partnerID
                                                             language:(NSString*)language
                                                            groupId:(NSString*)groupId;

// Creates the unwrapped request for groupJoin method
+(NSMutableDictionary*)createUnwrappedRequestForGroupJoinMethod:(NSString*)hardwareId
                                                      partnerID:(NSString*)partnerID
                                                       language:(NSString*)language
                                                         userID:(NSString*)userID
                                                            groupId:(NSString*)groupId
                                                       password:(NSString*)password;

// Creates the unwrapped request for groupLeave method
+(NSMutableDictionary*)createUnwrappedRequestForGroupLeaveMethod:(NSString*)hardwareId
                                                      partnerID:(NSString*)partnerID
                                                       language:(NSString*)language
                                                         userID:(NSString*)userID
                                                         groupId:(NSString*)groupId;

// Returns the wrapped request for an unwrapped request
+(NSMutableDictionary*)wrapRequest:(NSMutableDictionary*)unwrappedRequest;

// Returns the wrapped multi-request for an array of wrapped requests
+(NSMutableDictionary*)wrapMultiRequest:(NSMutableArray*)wrappedRequests
                           getAllOutput:(BOOL)getAllOutput; //Whether the server should use all output mode (YES) or last output mode (NO)

// Adds a given replayId to the given wrapped request
+(void)addReplayIdToWrappedRequest:(NSString*)replayId
                    wrappedRequest:(NSMutableDictionary*)wrappedRequest;

// Populates a list of groups from the given dictionary
+(void)populateGroupListFromDict:(NSMutableDictionary*)dict
                          groups:(NSMutableArray*)groups;

// Populates the given dictionary from the given groups
+(void)populateDictFromGroupList:(NSMutableDictionary*)dict
                                  groups:(NSMutableArray*)groups;

// ------------ Methods for processing responses

// Returns whether a valid wrapped response exists in the given NSDictionary
+(BOOL)isValidWrappedResponse:(NSMutableDictionary*)wrappedResponse;

// Extracts the wrapped multi responses from a wrapped multi-response
+(NSMutableArray*)extractWrappedMultiResponse:(NSMutableDictionary*)wrappedMultiResponse;

// Extracts the unwrapped response from a wrapped response
+(NSMutableDictionary*)unwrapResponse:(NSMutableDictionary*)wrappedResponse;

// Extracts any errors from an unwrapped response
+(void)extractErrorsFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                         userErrorMessage:(NSString**)userErrorMessage
                          devErrorMessage:(NSString**)devErrorMessage
                         shouldBeDetached:(BOOL*)shouldBeDetached;

// Extracts the replayID from an unwrapped response
+(void)extractReplayIDFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                                   replayID:(NSString**)replayID;

// Extracts the imageGUID from an unwrapped response
+(void)extractImageGUIDFromUnwrappedResponse:(NSMutableDictionary*)unwrappedResponse
                                   imageGUID:(NSString**)imageGUID;

// Extracts the user ID from the CreateUser response
+(NSString*)extractUserIDFromCreateUserResponse:(NSMutableDictionary*)unwrappedResponse;

// Extracts the result from the GetRendezvousCode response
+(void)extractResultFromGetRendezvousCodeResponse:(NSMutableDictionary*)unwrappedResponse
                                   rendezvousCode:(NSString**)rendezvousCode
                                          expires:(NSDate**)expires; // May be nil if no expiration

// Extracts the result from the SubmitRendezvousCode response
+(void)extractResultFromSubmitRendezvousCodeResponse:(NSMutableDictionary*)unwrappedResponse
                                    rendezvousResult:(NSString**)rendezvousResult
                                              userID:(NSString**)userID;

// Extracts the device list from the GetAttachedDevices response
+(NSMutableArray*)extractSyncDeviceListFromGetAttachedDevicesResponse:(NSMutableDictionary*)unwrappedResponse;

// Extracts the history event data from the given history event dictionary
+(void)extractHistoryEventDataFromHistoryEvent:(NSMutableDictionary*)historyEventDict
                                          guid:(NSString**)guid
                                  creationDate:(NSDate**)creationDate
                              eventDescription:(NSString**)eventDescription
                                     operation:(NSString**)operation
                                 operationData:(NSString**)operationData
                                  scheduleDate:(NSDate**)scheduleDate
                               preferencesDict:(NSDictionary**)preferencesDict;

// Creates a dictionary of a history event for a sync request
+(NSMutableDictionary*)createHistoryEventDictForSyncRequest:(NSString*)guid
                                             creationDate:(NSDate*)creationDate
                                             operation:(NSString*)operation
                                             operationData:(NSString*)operationData
                                             eventDescription:(NSString*)eventDescription
                                             scheduleDate:(NSDate*)scheduleDate
                                             preferencesDict:(NSDictionary*)preferencesDict;

// Extracts the group info from the GroupInfoByName response
+(void)extractGroupInfoFromGroupInfoByNameResponse:(NSMutableDictionary*)unwrappedResponse
                                        groupFound:(BOOL*)groupFound
                                             group:(Group**)group;

// Extracts the group info from the GroupInfoById response
+(void)extractGroupInfoFromGroupInfoByIDResponse:(NSMutableDictionary*)unwrappedResponse
                                      groupFound:(BOOL*)groupFound
                                           group:(Group**)group;

// Extracts the results from the GroupJoin response
+(void)extractResultFromGroupJoinResponse:(NSMutableDictionary*)unwrappedResponse
                          groupJoinResult:(NSString**)groupJoinResult
                                   groups:(NSMutableArray*)groups;

// Extracts the results from the GroupLeave response
+(void)extractResultFromGroupLeaveResponse:(NSMutableDictionary*)unwrappedResponse
                          groupLeaveResult:(NSString**)groupLeaveResult
                                    groups:(NSMutableArray*)groups;

@end
