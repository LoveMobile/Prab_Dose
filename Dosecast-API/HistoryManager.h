//
//  HistoryManager.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/30/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HistoryDateEvents.h"

#define DebugLog( s, ... ) [[HistoryManager getInstance] addDebugLogEvent:[NSDate date] file:[[NSString stringWithUTF8String:__FILE__] lastPathComponent] line:__LINE__ eventDescription:[NSString stringWithFormat:(s), ##__VA_ARGS__]]

extern NSString *HistoryManagerTakePillOperationName;
extern NSString *HistoryManagerPostponePillOperationName;
extern NSString *HistoryManagerSkipPillOperationName;
extern NSString *HistoryManagerRefillOperationName;
extern NSString *HistoryManagerMissPillOperationName;
extern NSString *HistoryManagerSetInventoryOperationName;
extern NSString *HistoryManagerAdjustInventoryOperationName;
extern NSString *HistoryManagerAdjustRefillOperationName;

// Called to notify that the history was edited
extern NSString *HistoryManagerHistoryEditedNotification;

@class HistoryEvent;
@class DosecastDBDataFile;
@interface HistoryManager : NSObject
{
@private
    BOOL syncNeeded;
    DosecastDBDataFile* dbDataFile;
    NSMutableArray* historyBatchUpdatesStack;
    NSMutableArray* debugLogBatchUpdatesStack;
    NSMutableArray* cachedDebugLogEvents;
    BOOL needsCommit;
    BOOL needsDebugLogCommit;
    BOOL notifyHistoryEdited;
    BOOL completedStartup;
}

// Singleton methods
+ (HistoryManager*) getInstance;

// Dose history methods

// Perform initialization at startup when it is safe to do so
- (void) handleStartupTasks;

- (HistoryEvent*) addHistoryEvent:(NSString*)drugId
                             guid:(NSString*)guid
                     creationDate:(NSDate*)creationDate
                 eventDescription:(NSString*)eventDescription
                        operation:(NSString*)operation
                    operationData:(NSString*)operationData
                     scheduleDate:(NSDate*)scheduleDate
                  preferencesDict:(NSDictionary*)preferencesDict
                isManuallyCreated:(BOOL)isManuallyCreated
                     notifyServer:(BOOL)notifyServer
                     errorMessage:(NSString**)errorMessage;

- (HistoryEvent*) getEventForGUID:(NSString*)guid errorMessage:(NSString**)errorMessage;
- (BOOL) deleteAllEventsForDrugId:(NSString*)drugId notifyServer:(BOOL)notifyServer errorMessage:(NSString**)errorMessage;
- (BOOL) deleteAllEvents:(BOOL)notifyServer errorMessage:(NSString**)errorMessage;
- (BOOL) deleteEvent:(HistoryEvent*)event notifyServer:(BOOL)notifyServer;
- (BOOL) markHistoryEventAsSynched:(HistoryEvent*)event;
- (BOOL) eventsExistForDrugId:(NSString*)drugId;
- (void) updateRemainingRefillQuantityFromCompleteHistoryForDrug:(NSString*)drugId;
- (void) getOffsetToRemainingRefillQuantityFromHistoryEvent:(HistoryEvent*)event remainingQuantityOffset:(float*)remainingQuantityOffset refillQuantityOffset:(int*)refillQuantityOffset;
- (int) getNumTakePillEventsForDay:(NSDate*)date drugId:(NSString*)drugId;
- (int) getNumTakePillEventsForPrior24Hours:(NSDate*)date drugId:(NSString*)drugId earliestEventTime:(NSDate**)earliestEventTime;
- (NSDate*) getNotifyAfterTimeForDrugId:(NSString*)drugId fromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)lastTaken;
- (NSDate*) getLastTakenTimeForDrugId:(NSString*)drugId;
- (NSDate*) getEffectiveLastTakenTimeForDrugId:(NSString*)drugId;
- (NSArray*) getHistoryEventsForTodayForDrugId:(NSString*)drugId;
- (NSArray*) getHistoryEventsToSyncForDrugId:(NSString*)drugId;
- (NSArray*) getHistoryEventsForDrugId:(NSString *)drugId afterScheduledDate:(NSDate*)scheduledDate;
- (NSArray*) getHistoryEventsForDrugId:(NSString *)drugId afterCreationDate:(NSDate*)creationDate;
- (NSDate*) oldestEventForDrugId:(NSString*)drugId;
- (NSArray*) getHistoryDateEventsForDrugIds:(NSArray*)drugIds includePostponeEvents:(BOOL)includePostponeEvents errorMessage:(NSString**)errorMessage;
- (NSData*) getDoseHistoryAsCSVFileForDrugIds:(NSArray*)drugIds includePostponeEvents:(BOOL)includePostponeEvents errorMessage:(NSString**)errorMessage;
- (BOOL) checkForMissedDosesForDrugId:(NSString*)drugId errorMessage:(NSString**)errorMessage;

- (NSString*)getEventDescriptionForHistoryEvent:(NSString*)drugId
                       operation:(NSString*)operation
                   operationData:(NSString*)operationData
                      dosageType:(NSString*)dosageType
                 preferencesDict:(NSDictionary*)preferencesDict
          legacyEventDescription:(NSString*)legacyEventDescription
                 displayDrugName:(BOOL)displayDrugName;

// Returns dose times which are missing history entries for a particular drug. Assumes the doseTimes are in chronological order.
- (NSArray*) findMissedDosesForDrugId:(NSString*)drugId amongDoseTimes:(NSArray*)doseTimes errorMessage:(NSString**)errorMessage;

- (NSDictionary*) createHistoryEventPreferencesDict:(HistoryEvent*)event;

// Called prior to beginning a batch of HistoryManager calls - for performance purposes
- (void) beginBatchUpdates;

// Whether batch updates are in progress
- (BOOL) batchUpdatesInProgress;

// Called after ending a batch of HistoryManager calls - for performance purposes
- (void) endBatchUpdates:(BOOL)notifyEdit;

// Debug log methods
- (BOOL) addDebugLogEvent:(NSDate*)date
					 file:(NSString*)file
					 line:(int)line
		 eventDescription:(NSString*)eventDescription;

- (NSData*) getDebugLogAsCSVFile;
- (BOOL) deleteAllDebugLogEvents;
- (void) beginDebugLogBatchUpdates;
- (BOOL) debugLogBatchUpdatesInProgress;
- (void) endDebugLogBatchUpdates;

@property (nonatomic, strong) DosecastDBDataFile *dbDataFile;

@end
