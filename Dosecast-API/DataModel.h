//
//  DataModel.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/6/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataModelDelegate.h"
#import "DosecastCoreTypes.h"
#import "GlobalSettingsDelegate.h"
@class Drug;
@class GlobalSettings;
@class CustomNameIDList;
@class DosecastDataFile;
@class FlagDictionary;
@class VersionNumber;
@class DrugReminder;
@class ContactsHelper;

// This notification is fired when the data model is refreshed
extern NSString *DataModelDataRefreshNotification;

extern NSString *DataModelDataRefreshNotificationServerMethodCallsKey; // Key for NSSet inside NSDictionary stored in notification object
extern NSString *DataModelDataRefreshNotificationDeletedDrugIdsKey; // Key for NSSet inside NSDictionary stored in notification object

// This notification is fired when all data is deleted
extern NSString *DataModelDeleteAllDataNotification;

@interface DataModel : NSObject<GlobalSettingsDelegate> {
@private
    DosecastDataFile* dataFile;
	GlobalSettings* globalSettings;
    NSDate* appLastOpened;
	NSString* userID;
    NSString* hardwareID;
    NSObject<DataModelDelegate>* __weak delegate;
	BOOL notificationsPaused;
	BOOL fileWritesPaused;
	BOOL didNotifyDuringPause;
    BOOL wasExceedingMaxLocalNotifications;
    BOOL isSyncInProgress;
    BOOL requiresFollowOnSync;
	NSString* clientVersion;
	NSMutableSet* serverMethodCallsWhilePaused;
    NSMutableSet* deletedDrugIdsWhilePaused;
    BOOL userInteractionsAllowed;
    FlagDictionary* apiFlags;
    FlagDictionary* persistentFlags;
    BOOL completedInitialSync;
    BOOL syncNeeded;
    NSMutableSet* deletedDrugIDs;
    NSMutableArray* drugList;
    NSMutableArray* groups;
    NSDate* accountCreated;
    BOOL wasDetached;
    NSString* deviceToken;
    ContactsHelper* contactsHelper;
}

// Singleton methods
+ (DataModel*) getInstance;
+ (DataModel*) getInstanceWithAPIFlags:(NSArray*)flags;

// Writes persistent part of data model to file. Returns whether successful.
- (BOOL)writeToFile:(NSString**)errorMessage;

// Reads persistent part of data model from file. Returns whether successful.
- (BOOL)readFromFile:(NSString**)errorMessage;

// Returns number of overdue drugs
- (int)numOverdueDrugs;

// Returns whether any dose will be due between now and the given date
- (BOOL)willDoseBeDueBefore:(NSDate*)date;

// Returns the array of overdue drugs Ids
- (NSArray*)getOverdueDrugIds;

// Returns the ith 0-based overdue drug
- (Drug*)findOverdueDrug:(int)i;

// Returns drug with given ID
- (Drug*)findDrugWithId:(NSString*)drugId;

// Returns drug IDs for given person ID
- (NSArray*)findDrugIdsForPersonId:(NSString*)personId;

// Return the bedtime as dates
- (void)getBedtimeAsDates:(NSDate**)bedtimeStart bedtimeEnd:(NSDate**)bedtimeEnd;

// Updates drug data with the response from a sync server call
- (BOOL)syncDrugData:(NSMutableDictionary*)wrappedResponse
       isInteractive:(BOOL)isInteractive
    shouldBeDetached:(BOOL*)shouldBeDetached
        errorMessage:(NSString**)errorMessage;

// Updates any dependent state after the data model has been changed locally
- (void)updateAfterLocalDataModelChange:(NSSet*)serverMethodCalls deletedDrugIDs:(NSSet*)deletedDrugs;

// Returns whether the current drug list is over the max number of local notifications.
- (BOOL)isExceedingMaxLocalNotifications;

// Returns the date of the next (upcoming) bedtime end
- (NSDate*)getNextBedtimeEndDate;

// Returns the date of the bedtime on the given day
- (NSDate*)getBedtimeEndDateOnDay:(NSDate*)day;

// Returns whether a timezone change occurred and needs to be resolved
- (BOOL)needsToResolveTimezoneChange;

// Return key diagnostics as a string
- (NSString*)getKeyDiagnosticsString;

// Return the drug list as a string
- (NSString*)getDrugListHTMLString;

// Return the drug history as a string.
- (NSString*)getDrugHistoryStringForDrug:(NSString*)drugId;

// Return the drug history as a string.
- (NSString*)getDrugHistoryStringForPersonId:(NSString*)personId;

// For future times that lie across a daylight savings boundary, unapply the daylight savings period 
- (void) unapplyDaylightSavingsToFutureTimesAcrossDaylightSavingsBoundary;

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message;

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message;

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation;

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress; // A number between 0 and 1

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress; // A number between 0 and 1

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message;

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation;

// Callback for when user attempts to change the passcode
- (void)handleChangePasscode;

// Callback for when user attempts to delete all data
- (void)performDeleteAllData;

// Returns whether leaving a particular group the user belongs to will take away premium
- (BOOL)willLeavingGroupTakeAwayPremium:(NSString*)groupId;

// Returns whether leaving a particular group the user belongs to will take away the subscription
- (BOOL)willLeavingGroupTakeAwaySubscription:(NSString*)groupId;

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService;

// Returns the terms of service addenda from all groups the user joined
- (NSString*)getGroupTermsOfServiceAddenda;

// Returns whether the given time occurs during bedtime
- (BOOL)dateOccursDuringBedtime:(NSDate*)date;

// Returns inputs needed for sync request
- (void)createInputsForSyncRequest:(NSMutableArray**)drugListDicts
                 globalPreferences:(NSMutableDictionary**)globalPreferences;

// Returns whether any group gives a premium license away
- (BOOL)doesAnyGroupGivePremium;

// Returns whether the given date occurs during bedtime
+ (BOOL)dateOccursDuringBedtime:(NSDate*)date bedtimeStart:(int)bedtimeStart bedtimeEnd:(int)bedtimeEnd;

// Convert the given bedtime to dates
+ (void)convertBedtimetoDates:(int)bedtimeStart
				   bedtimeEnd:(int)bedtimeEnd
			 bedtimeStartDate:(NSDate**)bedtimeStartDate
			   bedtimeEndDate:(NSDate**)bedtimeEndDate;

// Convert the given dates to bedtime
+ (void)convertDatestoBedtime:(NSDate*)bedtimeStartDate
			   bedtimeEndDate:(NSDate*)bedtimeEndDate
		     	 bedtimeStart:(int*)bedtimeStart
			       bedtimeEnd:(int*)bedtimeEnd;

@property (nonatomic, strong) NSString* userID;
@property (weak, nonatomic, readonly) NSString* userIDAbbrev;
@property (nonatomic, readonly) NSString* hardwareID;
@property (nonatomic, readonly) NSDate* appLastOpened;
@property (nonatomic, strong) NSString* clientVersion;
@property (nonatomic, readonly) BOOL notificationsPaused;
@property (nonatomic, assign) BOOL fileWritesPaused;
@property (nonatomic, readonly) BOOL userRegistered;
@property (nonatomic, assign) BOOL userInteractionsAllowed;
@property (nonatomic, assign) BOOL syncNeeded;
@property (nonatomic, readonly) FlagDictionary* apiFlags;
@property (nonatomic, readonly) FlagDictionary* persistentFlags;
@property (nonatomic, weak) NSObject<DataModelDelegate>* delegate;
@property (nonatomic, readonly) GlobalSettings* globalSettings;
@property (nonatomic, assign) BOOL wasExceedingMaxLocalNotifications;
@property (nonatomic, readonly) NSMutableSet* deletedDrugIDs;
@property (nonatomic, readonly) NSMutableArray* drugList;
@property (nonatomic, readonly) NSMutableArray* groups;
@property (nonatomic, readonly) NSDate* accountCreated;
@property (nonatomic, assign) BOOL wasDetached;
@property (nonatomic, strong) NSString* deviceToken;
@property (nonatomic, readonly) ContactsHelper* contactsHelper;

@end
