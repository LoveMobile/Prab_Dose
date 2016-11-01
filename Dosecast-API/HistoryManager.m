//
//  HistoryManager.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/30/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "HistoryManager.h"
#import "HistoryEvent.h"
#import "EditableHistoryEvent.h"
#import "DebugLogEvent.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "Drug.h"
#import "ScheduledDrugReminder.h"
#import "DosecastDBDataFile.h"
#import "JSONConverter.h"
#import "ManagedDrugDosage.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DrugDosageManager.h"
#import "VersionNumber.h"
#import "LogManager.h"
#import "GlobalSettings.h"
#import "IntervalDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "Preferences.h"

static HistoryManager *gInstance = nil;
NSString *HistoryManagerTakePillOperationName = @"takePill";
NSString *HistoryManagerPostponePillOperationName = @"postponePill";
NSString *HistoryManagerSkipPillOperationName = @"skipPill";
NSString *HistoryManagerRefillOperationName = @"refill";
NSString *HistoryManagerMissPillOperationName = @"missPill";
NSString *HistoryManagerSetInventoryOperationName = @"setInventory";
NSString *HistoryManagerAdjustInventoryOperationName = @"adjustInventory";
NSString *HistoryManagerAdjustRefillOperationName = @"adjustRefills";
static NSString *HistoryManagerDebugLogCachedDateKey = @"HistoryManagerDebugLogCachedDateKey";
static NSString *HistoryManagerDebugLogCachedFileKey = @"HistoryManagerDebugLogCachedFileKey";
static NSString *HistoryManagerDebugLogCachedLineKey = @"HistoryManagerDebugLogCachedLineKey";
static NSString *HistoryManagerDebugLogCachedEventDescriptionKey = @"HistoryManagerDebugLogCachedEventDescriptionKey";

static NSString *DosageTypeKey = @"dosageType";
static NSString *SetInventoryRemainingQuantityKey = @"remainingQuantity";
static NSString *SetInventoryRefillsRemainingKey = @"refillQuantity";
static NSString *RefillQuantityKey = @"refillAmount";
static NSString *AdjustInventoryQuantityKey = @"inventoryAdjustment";
static NSString *AdjustRefillQuantityKey = @"refillAdjustment";
static NSString *SyncPreferencesKey = @"syncPreferences";
static NSString *KeyKey = @"key";
static NSString *ValueKey = @"value";

NSString *HistoryManagerHistoryEditedNotification = @"HistoryManagerHistoryEditedNotification";

static int MAX_NUM_DEBUGLOG_DAYS = 7;
static float epsilon = 0.0001;

@implementation HistoryManager

@synthesize dbDataFile;

- (id)init
{
    if((self = [super init]))
    {
        dbDataFile = nil;
        historyBatchUpdatesStack = [[NSMutableArray alloc] init];
        debugLogBatchUpdatesStack = [[NSMutableArray alloc] init];
        needsCommit = NO;
        needsDebugLogCommit = NO;
        syncNeeded = NO;
        notifyHistoryEdited = NO;
        completedStartup = NO;
        cachedDebugLogEvents = [[NSMutableArray alloc] init];

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAPIVersionUpgrade:)
                                                     name:GlobalSettingsAPIVersionUpgrade
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];

	}
	
    return self;
}

- (void)dealloc
{
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalSettingsAPIVersionUpgrade object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    // Delete all history & debug log entries
    [self deleteAllEvents:NO errorMessage:nil];
    // Don't delete debug logging - keep it around
    syncNeeded = NO;
    notifyHistoryEdited = NO;
    [historyBatchUpdatesStack removeAllObjects];
    needsCommit = NO;
}

// Singleton methods

+ (HistoryManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

// Return the oldest date we keep history for
- (NSDate*) getHistoryBoundaryDateForDaysInPast:(int)daysInPast
{
	// Force the time to midnight
	NSDate* thisMorning = [DosecastUtil getMidnightOnDate:[NSDate date]];
	
	// Get the date of the event boundary
    return [DosecastUtil addDaysToDate:thisMorning numDays:-daysInPast];
}

- (NSMutableArray*) getHistoryEventsForDrugIds:(NSArray*)drugIds
                              withServerStatuses:(NSArray*)serverStatuses
                                        withGUID:(NSString*)guid
                              betweenCreationDate:(NSDate*)creationStartDate
                                  andCreationDate:(NSDate*)creationEndDate
                              betweenScheduleDate:(NSDate*)scheduleStartDate
                                  andScheduleDate:(NSDate*)scheduleEndDate
                                includeOperations:(NSArray*)includeOperations
                                excludeOperations:(NSArray*)excludeOperations
                             withPreferenceValues:(NSDictionary*)preferenceValues
                      isAscendingCreationDates:(NSNumber*)isAscendingCreationDatesNum
                      isAscendingScheduleDates:(NSNumber*)isAscendingScheduleDatesNum
                                            limit:(NSUInteger)limit // the max number to return (or 0 for all)
                                     errorMessage:(NSString**)errorMessage
{
    if (errorMessage)
        *errorMessage = nil;
    
    if (!dbDataFile || !dbDataFile.managedObjectContext)
        return nil;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"HistoryEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
    [request setEntity:entity];
    
    NSMutableArray* andPredicateArray = [[NSMutableArray alloc] init];
    
    if (drugIds)
    {
        NSMutableArray* orPredicateArray = [[NSMutableArray alloc] init];
        for (NSString* drugId in drugIds)
        {
            [orPredicateArray addObject:
             [NSPredicate predicateWithFormat:@"drugId = %@", drugId]];
        }
        [andPredicateArray addObject:
         [NSCompoundPredicate orPredicateWithSubpredicates:orPredicateArray]];
    }

    if (serverStatuses)
    {
        NSMutableArray* orPredicateArray = [[NSMutableArray alloc] init];
        for (NSNumber* serverStatus in serverStatuses)
        {
            [orPredicateArray addObject:
             [NSPredicate predicateWithFormat:@"serverStatus = %d", [serverStatus intValue]]];
        }
        [andPredicateArray addObject:
         [NSCompoundPredicate orPredicateWithSubpredicates:orPredicateArray]];
    }

    if (guid)
    {
        [andPredicateArray addObject:
         [NSPredicate predicateWithFormat:@"guid = %@", guid]];
    }
    
    if (creationStartDate)
    {
        [andPredicateArray addObject:
         [NSPredicate predicateWithFormat:@"creationDate >= %@", creationStartDate]];
    }
    
    if (creationEndDate)
    {
        [andPredicateArray addObject:
         [NSPredicate predicateWithFormat:@"creationDate < %@", creationEndDate]];
    }
    
    if (scheduleStartDate)
    {
        [andPredicateArray addObject:
         [NSPredicate predicateWithFormat:@"scheduleDate >= %@", scheduleStartDate]];
    }
    
    if (scheduleEndDate)
    {
        [andPredicateArray addObject:
         [NSPredicate predicateWithFormat:@"scheduleDate < %@", scheduleEndDate]];
    }
    
    if (includeOperations)
    {
        NSMutableArray* orPredicateArray = [[NSMutableArray alloc] init];
        for (NSString* operation in includeOperations)
        {
            [orPredicateArray addObject:
             [NSPredicate predicateWithFormat:@"operation = %@", operation]];
        }
        [andPredicateArray addObject:
         [NSCompoundPredicate orPredicateWithSubpredicates:orPredicateArray]];
    }
    
    if (excludeOperations)
    {
        for (NSString* operation in excludeOperations)
        {
            [andPredicateArray addObject:
             [NSPredicate predicateWithFormat:@"operation != %@", operation]];
        }
    }
    
    if (preferenceValues)
    {
        NSArray* keys = [preferenceValues allKeys];
        for (NSString* key in keys)
        {
            id value = [preferenceValues objectForKey:key];
            if (value)
            {
                NSMutableString* formatString = [NSMutableString stringWithFormat:@"%@ = ", key];
                if ([value isKindOfClass:[NSNull class]])
                {
                    [formatString appendString:@"nil"];
                    [andPredicateArray addObject:
                     [NSPredicate predicateWithFormat:formatString]];
                }
                else
                {
                    [formatString appendString:@"%@"];

                    [andPredicateArray addObject:
                     [NSPredicate predicateWithFormat:formatString, (NSString*)value]];
                }
            }
        }
    }
    
    NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates:andPredicateArray];
    [request setPredicate:predicate];
    
    [request setFetchLimit:limit];
    
    NSMutableArray* sortDescriptors = [[NSMutableArray alloc] init];
    
    if (isAscendingScheduleDatesNum)
    {
        [sortDescriptors addObject:
         [[NSSortDescriptor alloc] initWithKey:@"scheduleDate" ascending:[isAscendingScheduleDatesNum boolValue]]];
    }
    
    if (isAscendingCreationDatesNum)
    {
        [sortDescriptors addObject:
         [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:[isAscendingCreationDatesNum boolValue]]];
    }
        
    [request setSortDescriptors:sortDescriptors];
    
    NSError *error = nil;
    NSMutableArray *mutableFetchResults = [[dbDataFile.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (!mutableFetchResults && errorMessage && error)
    {
        NSString* errorText = NSLocalizedStringWithDefaultValue(@"ErrorHistoryNotAccessible", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history could not be accessed due to the following error: %@.", @"The error message when the dose history can't be accessed"]);
        *errorMessage = [NSString stringWithFormat:errorText, [error localizedDescription]];
    }
    
    return mutableFetchResults;
}

- (void) removeOldEvents
{		
	if (!dbDataFile || !dbDataFile.managedObjectContext)
		return;
	
    DebugLog(@"start removing old events");

	// Get the date of the event boundary
    DataModel* dataModel = [DataModel getInstance];
	NSDate* dateBoundary = [self getHistoryBoundaryDateForDaysInPast:dataModel.globalSettings.doseHistoryDays];
    
    // Delete the old event, but only if it has been synched with the server
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:nil
                                                  withServerStatuses:[NSArray arrayWithObject:[NSNumber numberWithInt:(int)HistoryEventServerStatusSynched]]
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:dateBoundary
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];
    
    if (!historyEvents)
    {
        DebugLog(@"end removing old events (no events found)");

		return;
    }
	
    [self beginBatchUpdates];
    
    for (HistoryEvent* event in historyEvents)
    {
        [self deleteEvent:event notifyServer:NO];
	}

    [self endBatchUpdates:NO];
    
    DebugLog(@"end removing old events");
}

- (void)handleAPIVersionUpgrade:(NSNotification*)notification
{
    VersionNumber* lastAPIVersionNumber = notification.object;
    BOOL isFileUpgrade = [((NSNumber*)[notification.userInfo objectForKey:GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade]) boolValue];
    if ([lastAPIVersionNumber compareWithVersionString:@"Version 6.0.9"] == NSOrderedSame) // upgrade from v6.0.9
    {
         // On a file upgrade, delete all history, set guids and server status, and create setInventory events. This will have been done if upgrading via sync.
        if (!isFileUpgrade)
            return;

        [self beginDebugLogBatchUpdates];
        
        // Delete all history on the server
        DataModel* dataModel = [DataModel getInstance];
        
        if (dataModel.userRegistered)
        {
            NSString* partnerIDName = NSLocalizedStringWithDefaultValue(@"PartnerID", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The partner ID reported to the server"]);
            
            // Delete the history
            for (Drug* d in dataModel.drugList)
            {
                NSMutableDictionary* unwrappedDict = [JSONConverter createUnwrappedRequestForDeleteAllHistoryEventsMethod:dataModel.hardwareID
                                                                                                                partnerID:partnerIDName
                                                                                                                 language:[DosecastUtil getLanguageCountryCode]
                                                                                                                   userID:dataModel.userID
                                                                                                                   drugID:d.drugId];
                [[LogManager sharedManager] addLogEntryWithUnwrappedRequest:unwrappedDict uploadLogsAfter:NO];
            }
        }
        
        NSMutableDictionary* remainingQuantityAdjustmentByDrugId = [[NSMutableDictionary alloc] init];
        NSMutableDictionary* refillQuantityAdjustmentByDrugId = [[NSMutableDictionary alloc] init];

        // Populate new history fields
        NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:nil
                                                      withServerStatuses:nil
                                                                withGUID:nil
                                                     betweenCreationDate:nil
                                                         andCreationDate:nil
                                                     betweenScheduleDate:nil
                                                         andScheduleDate:nil
                                                       includeOperations:nil
                                                       excludeOperations:nil
                                                    withPreferenceValues:nil
                                                isAscendingCreationDates:[NSNumber numberWithBool:NO]
                                                isAscendingScheduleDates:nil
                                                                   limit:0
                                                            errorMessage:nil];
        NSDate* earliestDate = [NSDate date];
        if (historyEvents)
        {
            for (HistoryEvent* historyEvent in historyEvents)
            {
                if (historyEvent.drugId)
                {
                    historyEvent.guid = [DosecastUtil createGUID];
                    historyEvent.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusNew]; // Let a Sync push this to the server
                    
                    // Populate a dictionary of the running tally of remaining quantity and refill quantity
                    float remainingQuantityOffset = 0.0f;
                    int refillQuantityOffset = 0;
                    [self getOffsetToRemainingRefillQuantityFromHistoryEvent:historyEvent remainingQuantityOffset:&remainingQuantityOffset refillQuantityOffset:&refillQuantityOffset];
                    
                    if (fabsf(remainingQuantityOffset) > epsilon)
                    {
                        NSNumber* num = [remainingQuantityAdjustmentByDrugId objectForKey:historyEvent.drugId];
                        if (!num)
                            num = [NSNumber numberWithFloat:0.0f];
                        [remainingQuantityAdjustmentByDrugId setObject:[NSNumber numberWithFloat:[num floatValue]+remainingQuantityOffset] forKey:historyEvent.drugId];
                    }
                    
                    if (abs(refillQuantityOffset) > 0)
                    {
                        NSNumber* num = [refillQuantityAdjustmentByDrugId objectForKey:historyEvent.drugId];
                        if (!num)
                            num = [NSNumber numberWithInt:0];
                        [refillQuantityAdjustmentByDrugId setObject:[NSNumber numberWithInt:[num intValue]+refillQuantityOffset] forKey:historyEvent.drugId];
                    }
                }
                else
                {
                    historyEvent.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusSynched]; // don't do anything with legacy history events
                }
            }
            
            // Note the oldest date and back it up by 1 sec
            if ([historyEvents count] > 0)
            {
                HistoryEvent* historyEvent = [historyEvents lastObject];
                earliestDate = [historyEvent.creationDate dateByAddingTimeInterval:-1];
            }
        }
        
        // Create new set inventory events (one per drug)
        [self beginBatchUpdates];
        
        for (Drug* d in dataModel.drugList)
        {
            float remainingQuantityOffset = 0.0f;
            int refillQuantityOffset = 0;
            
            NSNumber* remainingQuantityOffsetNum = [remainingQuantityAdjustmentByDrugId objectForKey:d.drugId];
            if (remainingQuantityOffsetNum)
                remainingQuantityOffset = [remainingQuantityOffsetNum floatValue];

            NSNumber* refillQuantityOffsetNum = [refillQuantityAdjustmentByDrugId objectForKey:d.drugId];
            if (refillQuantityOffsetNum)
                refillQuantityOffset = [refillQuantityOffsetNum intValue];
            
            float endRemainingQuantity = 0.0f;
            [d.dosage getValueForRemainingQuantity:&endRemainingQuantity];
            float remainingQuantity = endRemainingQuantity - remainingQuantityOffset;
            
            int endRefillQuantity = [d.dosage getRefillsRemaining];
            int refillQuantity = endRefillQuantity - refillQuantityOffset;

            int sigDigits = 0;
            int numDecimals = 0;
            BOOL displayNone = YES;
            BOOL allowZero = YES;
            [d.dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero];
            
            NSDictionary* preferencesDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [DrugDosage getStringFromQuantity:remainingQuantity unit:nil numDecimals:numDecimals], SetInventoryRemainingQuantityKey,
                                             [NSString stringWithFormat:@"%d", refillQuantity], SetInventoryRefillsRemainingKey,
                                             nil];
            
            [self addHistoryEvent:d.drugId
                             guid:nil
                     creationDate:earliestDate
                 eventDescription:nil
                        operation:HistoryManagerSetInventoryOperationName
                    operationData:nil
                     scheduleDate:nil
                  preferencesDict:preferencesDict
                isManuallyCreated:NO
                     notifyServer:YES
                     errorMessage:nil];
        }
        
        [self deleteAllDebugLogEvents];
        
        [self endBatchUpdates:NO];
        
        [self endDebugLogBatchUpdates];
    }
    else if ([lastAPIVersionNumber compareWithVersionString:@"Version 7.0.4"] == NSOrderedAscending) // upgrade from pre-7.0.4
    {
        [self beginDebugLogBatchUpdates];

        [self beginBatchUpdates];

        for (Drug* d in [DataModel getInstance].drugList)
        {
            if ([self takePillEventsWithNoDosageTypeExistForDrugId:d.drugId])
            {
                [self updateRemainingRefillQuantityFromCompleteHistoryForDrug:d.drugId];
            }
        }
        
        [self endBatchUpdates:NO];

        [self endDebugLogBatchUpdates];
    }
}

- (void) commitHistoryDatabaseChanges:(BOOL)notifyEdit notifyServer:(BOOL)notifyServer
{
    if (notifyEdit)
        notifyHistoryEdited = YES;
    if (notifyServer)
        syncNeeded = YES;
    
    // If we are in the middle of a batch operation, postpone this until later
    if ([self batchUpdatesInProgress])
    {
        needsCommit = YES;
        return;
    }

    if ([dbDataFile.managedObjectContext hasChanges])
    {
        if (dbDataFile)
            [dbDataFile saveChanges];
        if (syncNeeded)
        {
            DebugLog(@"sync requested");

            [DataModel getInstance].syncNeeded = YES;
            [[DataModel getInstance] writeToFile:nil];
        }
        
        if (notifyHistoryEdited)
        {
            [[NSNotificationCenter defaultCenter] postNotification:
             [NSNotification notificationWithName:HistoryManagerHistoryEditedNotification object:self]];
        }
    }
    
    syncNeeded = NO;
    needsCommit = NO;
    notifyHistoryEdited = NO;
}

- (NSString*)getOperationDescription:(NSString*)operation
{
	if ([operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
	{
		return NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Dose", @"The Take Dose button on the dose reminder alert"]);
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
	{
		return NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Dose", @"The Skip Dose button on the dose reminder alert"]);
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
	{
		return NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]);
	}	
	else if ([operation caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
	{
		return NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill", @"The Refill label in the Drug Edit view"]);
	}
    else if ([operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
	{
		return NSLocalizedStringWithDefaultValue(@"DrugHistoryMissDoseAction", @"Dosecast", [DosecastUtil getResourceBundle], @"Miss Dose", @"The Miss Dose action label in the drug history"]);
	}
	else
		return nil;
}


- (NSString*)getEventDescription:(NSString*)drugId
                       operation:(NSString*)operation
                   operationData:(NSString*)operationData
          descriptionForDrugDose:(NSString*)descriptionForDrugDose
                 preferencesDict:(NSDictionary*)preferencesDict
{
    if (!drugId)
        return nil;
    
	NSMutableString* eventDescription = [NSMutableString stringWithFormat:@""];
	Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
	   
	if ([operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
	{
		[eventDescription appendFormat:@"%@ ", descriptionForDrugDose];
		[eventDescription appendString:NSLocalizedStringWithDefaultValue(@"DrugHistoryTakenDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"taken", @"The description for taken doses in the drug history"])];
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
	{
		[eventDescription appendFormat:@"%@ ", descriptionForDrugDose];
		[eventDescription appendString:NSLocalizedStringWithDefaultValue(@"DrugHistorySkippedDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"skipped", @"The description for skipped doses in the drug history"])];
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
	{
		[eventDescription appendFormat:@"%@ ", descriptionForDrugDose];
		NSMutableString* postponeTimeLabel = [NSMutableString stringWithString:@""];
		
		int totalMinutes = [operationData intValue] / 60;
		int numHours = totalMinutes/60;
		int numMinutes = totalMinutes%60;
		
		if (numHours > 0)
		{
			NSString* hourSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"hour", @"The singular name for hour in interval drug descriptions"]);
			NSString* hourPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"hours", @"The plural name for hour in interval drug descriptions"]);
			
			if (![DosecastUtil shouldUseSingularForInteger:numHours])
				[postponeTimeLabel appendFormat:@"%d %@", numHours, hourPlural];
			else
				[postponeTimeLabel appendFormat:@"%d %@", numHours, hourSingular];
		}
		
		if (numMinutes > 0)
		{
			NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
			NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);
			
			if ([postponeTimeLabel length] > 0)
				[postponeTimeLabel appendString:@" "];
			
			if (![DosecastUtil shouldUseSingularForInteger:numMinutes])
				[postponeTimeLabel appendFormat:@"%d %@", numMinutes, minPlural];
			else
				[postponeTimeLabel appendFormat:@"%d %@", numMinutes, minSingular];
		}
		
		[eventDescription appendFormat:NSLocalizedStringWithDefaultValue(@"DrugHistoryPostponedDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"postponed %@", @"The description for postponed doses in the drug history"]), postponeTimeLabel];
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
	{
		[eventDescription appendFormat:@"%@ %@", d.name, NSLocalizedStringWithDefaultValue(@"DrugHistoryRefilledDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"refilled", @"The description for refilled drugs in the drug history"])];
		
        if (preferencesDict)
        {
            NSString* refillQuantityValStr = [preferencesDict objectForKey:RefillQuantityKey];

            if (refillQuantityValStr && [refillQuantityValStr length] > 0)
            {
                float refillQuantityVal = [refillQuantityValStr floatValue];
                
                if (refillQuantityVal > epsilon)
                {
                    NSString* refillQuantityDisplayStr = [DrugDosage getDescriptionForQuantity:refillQuantityVal unit:nil numDecimals:2];
                    
                    [eventDescription appendFormat:@" (%@: %@)",
                     [NSLocalizedStringWithDefaultValue(@"DrugHistoryRefillAmount", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Amount", @"The Scheduled Time label of the Drug History Event Time view"]) lowercaseString],
                     refillQuantityDisplayStr];
                }
            }
        }
	}
	else if ([operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
	{
		[eventDescription appendFormat:@"%@ ", descriptionForDrugDose];
		[eventDescription appendString:NSLocalizedStringWithDefaultValue(@"DrugHistoryMissedDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"missed", @"The description for missed doses in the drug history"])];
	}
	
	return eventDescription;
}

- (NSDictionary*) convertHistoryPreferencesToSyncDict:(NSDictionary*)dict
{
    NSMutableDictionary* syncPreferences = [[NSMutableDictionary alloc] init];
    
    NSArray* allKeys = [dict allKeys];
    for (NSString* key in allKeys)
    {
        NSString* value = [dict objectForKey:key];
        [Preferences populatePreferenceInDictionary:syncPreferences key:key value:value modifiedDate:nil perDevice:NO];
    }
        
    return syncPreferences;
}

- (NSString*)getEventDescriptionForHistoryEvent:(NSString*)drugId
                       operation:(NSString*)operation
                   operationData:(NSString*)operationData
                      dosageType:(NSString*)dosageType
                 preferencesDict:(NSDictionary*)preferencesDict
          legacyEventDescription:(NSString*)legacyEventDescription
                 displayDrugName:(BOOL)displayDrugName
{
    if (!drugId)
        return legacyEventDescription;
    else if ([operation isEqualToString:HistoryManagerSetInventoryOperationName] ||
        [operation isEqualToString:HistoryManagerAdjustInventoryOperationName] ||
        [operation isEqualToString:HistoryManagerAdjustRefillOperationName])
    {
        return nil;
    }
    
    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
    NSString* drugName = d.name;
    if (!displayDrugName)
        drugName = nil;
    if ([operation isEqualToString:HistoryManagerRefillOperationName])
    {
        return [self getEventDescription:drugId operation:operation operationData:operationData descriptionForDrugDose:nil preferencesDict:preferencesDict];
    }
    else if (dosageType && [dosageType length] > 0 && preferencesDict)
    {
        NSString* descriptionForDrugDose = [[DrugDosageManager getInstance] getDescriptionForDrugDoseWithFileTypeName:dosageType drugName:drugName withDictionary:[self convertHistoryPreferencesToSyncDict:preferencesDict]];
        return [self getEventDescription:drugId operation:operation operationData:operationData descriptionForDrugDose:descriptionForDrugDose preferencesDict:preferencesDict];
    }
    else if (!legacyEventDescription)
    {
        NSString* descriptionForDrugDose = [d.dosage getDescriptionForDrugDose:drugName];
        return [self getEventDescription:drugId operation:operation operationData:operationData descriptionForDrugDose:descriptionForDrugDose preferencesDict:preferencesDict];
    }
    else
        return legacyEventDescription;
}

- (void) updateHistoryEventWithPreferencesDict:(HistoryEvent*)event preferencesDict:(NSDictionary*)preferencesDict
{
    if (!preferencesDict)
        return;
    
    NSMutableDictionary* mutablePrefs = [NSMutableDictionary dictionaryWithDictionary:preferencesDict];
    if ([mutablePrefs objectForKey:DosageTypeKey])
    {
        event.dosageType = [mutablePrefs objectForKey:DosageTypeKey];
        [mutablePrefs removeObjectForKey:DosageTypeKey];
    }
    else
        event.dosageType = nil;
    
    NSMutableArray* allKeys = [NSMutableArray arrayWithArray:[mutablePrefs allKeys]];
    if ([allKeys count] > 0)
    {
        NSString* key = [allKeys objectAtIndex:0];
        event.dosageTypePrefKey1 = key;
        event.dosageTypePrefValue1 = [mutablePrefs objectForKey:key];
        [allKeys removeObjectAtIndex:0];
    }
    else
    {
        event.dosageTypePrefKey1 = nil;
        event.dosageTypePrefValue1 = nil;
    }
    
    if ([allKeys count] > 0)
    {
        NSString* key = [allKeys objectAtIndex:0];
        event.dosageTypePrefKey2 = key;
        event.dosageTypePrefValue2 = [mutablePrefs objectForKey:key];
        [allKeys removeObjectAtIndex:0];
    }
    else
    {
        event.dosageTypePrefKey2 = nil;
        event.dosageTypePrefValue2 = nil;
    }
    
    if ([allKeys count] > 0)
    {
        NSString* key = [allKeys objectAtIndex:0];
        event.dosageTypePrefKey3 = key;
        event.dosageTypePrefValue3 = [mutablePrefs objectForKey:key];
        [allKeys removeObjectAtIndex:0];
    }
    else
    {
        event.dosageTypePrefKey3 = nil;
        event.dosageTypePrefValue3 = nil;
    }
    
    if ([allKeys count] > 0)
    {
        NSString* key = [allKeys objectAtIndex:0];
        event.dosageTypePrefKey4 = key;
        event.dosageTypePrefValue4 = [mutablePrefs objectForKey:key];
        [allKeys removeObjectAtIndex:0];
    }
    else
    {
        event.dosageTypePrefKey4 = nil;
        event.dosageTypePrefValue4 = nil;
    }
    
    if ([allKeys count] > 0)
    {
        NSString* key = [allKeys objectAtIndex:0];
        event.dosageTypePrefKey5 = key;
        event.dosageTypePrefValue5 = [mutablePrefs objectForKey:key];
        [allKeys removeObjectAtIndex:0];
    }
    else
    {
        event.dosageTypePrefKey5 = nil;
        event.dosageTypePrefValue5 = nil;
    }
}

- (NSString*) createStandardEventGuidWithActionString:(NSString*)actionString forDrugId:(NSString*)drugId andScheduleDate:(NSDate*)scheduleDate
{
    if (!actionString || !drugId || !scheduleDate)
        return [DosecastUtil createGUID];
    else
        return [NSString stringWithFormat:@"%@-%@-%lld", actionString, drugId, (long long)[scheduleDate timeIntervalSince1970]];
}

- (NSDictionary*) extractHistoryPreferencesFromSyncDict:(NSDictionary*)dict
{
    NSMutableDictionary* historyPreferences = [[NSMutableDictionary alloc] init];
    
    NSMutableArray* syncPreferences = [dict objectForKey:SyncPreferencesKey];
    if (syncPreferences)
    {
        for (NSMutableDictionary* thisPref in syncPreferences)
        {
            NSString* key = [thisPref objectForKey:KeyKey];
            if (key)
            {
                NSString* value = [thisPref objectForKey:ValueKey];
                if (value)
                    [historyPreferences setObject:value forKey:key];
            }
        }
    }
    
    return historyPreferences;
}

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
                     errorMessage:(NSString**)errorMessage
{
    if (errorMessage)
		*errorMessage = nil;
	
	if (!dbDataFile || !dbDataFile.managedObjectContext || !drugId || !creationDate )
		return nil;
    
    DebugLog(@"start adding history event (%@) for drug (%@)", operation, drugId);
    
	// Create and configure a new instance of the HistoryEvent entity
	HistoryEvent *event = (HistoryEvent *)[NSEntityDescription insertNewObjectForEntityForName:@"HistoryEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
	event.operation = operation;
    event.operationData = operationData;
	event.drugId = drugId;
    if (notifyServer)
        event.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusNew];
    else
        event.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusSynched];
	event.creationDate = creationDate;
    event.scheduleDate = scheduleDate;
	event.eventDescription = eventDescription;
    
    if (!guid && [operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame && !isManuallyCreated)
        guid = [self createStandardEventGuidWithActionString:@"miss" forDrugId:drugId andScheduleDate:scheduleDate];
    else if (!guid)
        guid = [DosecastUtil createGUID];
    event.guid = guid;

    if (!preferencesDict)
    {
        NSMutableDictionary* prefDict = [[NSMutableDictionary alloc] init];
        
        Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
        if ([operation isEqualToString:HistoryManagerRefillOperationName])
        {
            float refillAmount = 0.0f;
            [d.dosage getValueForRefillQuantity:&refillAmount];
            NSString* refillQuantityString = [DrugDosage getStringFromQuantity:refillAmount unit:nil numDecimals:2];

            [prefDict setObject:refillQuantityString forKey:RefillQuantityKey];
        }
        else if (![operation isEqualToString:HistoryManagerSetInventoryOperationName] &&
                 ![operation isEqualToString:HistoryManagerAdjustInventoryOperationName] &&
                 ![operation isEqualToString:HistoryManagerAdjustRefillOperationName])
        {
            [prefDict addEntriesFromDictionary:[self extractHistoryPreferencesFromSyncDict:[d.dosage getDoseData]]];
            NSString* fileTypeName = [d.dosage getFileTypeName];
            if (fileTypeName)
                [prefDict setObject:fileTypeName forKey:DosageTypeKey];
        }
        preferencesDict = prefDict;
    }
    [self updateHistoryEventWithPreferencesDict:event preferencesDict:preferencesDict];

    [self commitHistoryDatabaseChanges:YES notifyServer:notifyServer];
    
    DebugLog(@"end adding history event (%@) for drug (%@)", operation, drugId);

	return event;
}

- (BOOL) deleteAllEventsForDrugId:(NSString*)drugId notifyServer:(BOOL)notifyServer errorMessage:(NSString**)errorMessage
{
	if (errorMessage)
		*errorMessage = nil;

	if (!dbDataFile || !dbDataFile.managedObjectContext || !drugId )
		return NO;

    DebugLog(@"start deleting all drug events (%@)", drugId);

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:errorMessage];
	if (!historyEvents)
    {
        DebugLog(@"end deleting all drug events (%@, no events found)", drugId);
		return NO;
    }
				
    [self beginBatchUpdates];
    
	for (HistoryEvent* event in historyEvents)
	{
        [self deleteEvent:event notifyServer:notifyServer];
	}
	
    [self endBatchUpdates:NO];
    
    DebugLog(@"end deleting all drug events (%@)", drugId);

	return YES;
}

- (BOOL) deleteAllEvents:(BOOL)notifyServer errorMessage:(NSString**)errorMessage
{
  	if (errorMessage)
		*errorMessage = nil;
    
	if (!dbDataFile || !dbDataFile.managedObjectContext )
		return NO;
    
	// Query for any events and delete old ones
    
    DebugLog(@"start deleting all events");

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:nil
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:errorMessage];
	if (!historyEvents)
    {
        DebugLog(@"end deleting all events (no events found)");

		return NO;
    }
    
    [self beginBatchUpdates];
    
	for (HistoryEvent* event in historyEvents)
	{
        [self deleteEvent:event notifyServer:notifyServer];
	}
    
    [self endBatchUpdates:NO];
    
    DebugLog(@"end deleting all events");

	return YES;
}

- (HistoryEvent*) getEventForGUID:(NSString*)guid errorMessage:(NSString**)errorMessage
{
    if (errorMessage)
		*errorMessage = nil;
	
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !guid)
		return nil;
	
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:nil
                                                  withServerStatuses:nil
                                                            withGUID:guid
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:errorMessage];

	if (!historyEvents || [historyEvents count] == 0)
		return nil;
	
    HistoryEvent* event = [historyEvents objectAtIndex:0];
    return event;
}

- (BOOL) deleteEvent:(HistoryEvent*)event notifyServer:(BOOL)notifyServer
{	
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !event)
		return NO;
    
    BOOL serverNeedsNotification = NO;
    if (notifyServer && event.drugId && event.guid && event.serverStatus && [event.serverStatus intValue] != (int)HistoryEventServerStatusNew)
    {
        serverNeedsNotification = YES;
        Drug* d = [[DataModel getInstance] findDrugWithId:event.drugId];
        [d.deletedHistoryGUIDs addObject:event.guid];
    }
    
    [dbDataFile.managedObjectContext deleteObject:event];

    [self commitHistoryDatabaseChanges:YES notifyServer:serverNeedsNotification];
    
	return YES;	
}

- (NSDate*) getLastTakenTimeForDrugId:(NSString*)drugId
{
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
	
    DebugLog(@"start getLastTaken for drug (%@)", drugId);

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObject:HistoryManagerTakePillOperationName]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:NO]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];
    
    DebugLog(@"end getLastTaken for drug (%@)", drugId);

	if (!historyEvents || [historyEvents count] == 0)
		return nil;
	
	NSDate* creationDate = nil;
    HistoryEvent* event = [historyEvents objectAtIndex:0];
    creationDate = event.creationDate;
	
	return creationDate;	
}

- (NSDate*) getEffectiveLastTakenTimeForDrugId:(NSString*)drugId
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
        return nil;
    
    DebugLog(@"start getEffLastTaken for drug (%@)", drugId);

    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObjects:HistoryManagerTakePillOperationName, HistoryManagerSkipPillOperationName, HistoryManagerMissPillOperationName, nil]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:NO]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];

    DebugLog(@"end getEffLastTaken for drug (%@)", drugId);

	if (!historyEvents || [historyEvents count] == 0)
		return nil;
    
	NSDate* result = nil;
    HistoryEvent* event = [historyEvents objectAtIndex:0];
    
    if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        result = event.scheduleDate;
    else if ([event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
        result = event.creationDate;
	
	return result;
}

- (NSDate*) getNotifyAfterTimeForDrugId:(NSString*)drugId fromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)lastTaken
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
        return nil;

    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

    if ([d.reminder isKindOfClass:[AsNeededDrugReminder class]])
        return nil;
    
    NSDate* currentScheduledTime = [d.reminder getCurrentScheduledTimeFromEffLastTaken:effLastTaken andLastTaken:lastTaken];
    if (!currentScheduledTime)
        return nil;
    
    DebugLog(@"start getNotifyAfter for drug (%@)", drugId);

    NSDate* scheduleDateStart = [DosecastUtil addTimeIntervalToDate:[DosecastUtil removeSecondsFromDate:currentScheduledTime] timeInterval:-1]; // calculate the second before the minute starts

    NSDate* scheduleDateEnd = [DosecastUtil addTimeIntervalToDate:scheduleDateStart timeInterval:61]; // calculate the second after the minute ends
    
    // Look for postpone events after the most recent takePill or skipPill - and only if it was a takePill
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:scheduleDateStart
                                                     andScheduleDate:scheduleDateEnd
                                                   includeOperations:[NSArray arrayWithObjects:HistoryManagerPostponePillOperationName, nil]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];

    if (!historyEvents || [historyEvents count] == 0)
    {
        DebugLog(@"end getNotifyAfter for drug (%@, no events found)", drugId);

        return nil;
    }
    
    NSDate* basePostponeTime = ((HistoryEvent*)[historyEvents firstObject]).scheduleDate;
    
    for (HistoryEvent* event in historyEvents)
    {
        int postponeDurationSecs = 0;
        if (event.operationData)
            postponeDurationSecs = [event.operationData intValue];

        if ([event.creationDate timeIntervalSinceDate:basePostponeTime] < 0)
            basePostponeTime = [DosecastUtil addTimeIntervalToDate:basePostponeTime timeInterval:postponeDurationSecs];
        else
            basePostponeTime = [DosecastUtil addTimeIntervalToDate:event.creationDate timeInterval:postponeDurationSecs];
    }
    
    DebugLog(@"end getNotifyAfter for drug (%@)", drugId);

    return basePostponeTime;
}

- (NSDate*) oldestEventForDrugId:(NSString*)drugId
{
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
	
    DebugLog(@"start get oldest event for drug (%@)", drugId);

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];
    
    DebugLog(@"end get oldest event for drug (%@)", drugId);

	if (!historyEvents || [historyEvents count] == 0)
		return nil;
	
	NSDate* creationDate = nil;
    HistoryEvent* event = [historyEvents objectAtIndex:0];
    creationDate = event.creationDate;
	
	return creationDate;
}

// Returns a list of scheduled HistoryEvents for today for the drug
- (NSArray*) getHistoryEventsForTodayForDrugId:(NSString*)drugId
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
	
    DebugLog(@"start get events for today for drug (%@)", drugId);

	// Query for any events and delete old ones
    NSDate* morning = [DosecastUtil getMidnightOnDate:[NSDate date]];
    NSDate* night = [DosecastUtil getLastSecondOnDate:morning];

    NSArray* result = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:morning
                                                     andCreationDate:night
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];
    
    DebugLog(@"end get events for today for drug (%@)", drugId);

    return result;
}

- (NSArray*) getHistoryEventsForDrugId:(NSString *)drugId afterScheduledDate:(NSDate*)scheduledDate
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
	   
    DebugLog(@"start get events after scheduled date for drug (%@)", drugId);

    NSArray* result = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                         withServerStatuses:nil
                                   withGUID:nil
                        betweenCreationDate:nil
                            andCreationDate:nil
                        betweenScheduleDate:scheduledDate
                            andScheduleDate:nil
                          includeOperations:nil
                          excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                       withPreferenceValues:nil
                   isAscendingCreationDates:[NSNumber numberWithBool:YES]
                   isAscendingScheduleDates:[NSNumber numberWithBool:YES]
                                      limit:0
                               errorMessage:nil];
    
    DebugLog(@"end get events after scheduled date for drug (%@)", drugId);
    
    return result;
}

- (NSArray*) getHistoryEventsToSyncForDrugId:(NSString*)drugId
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
    
    DebugLog(@"start get events to sync for drug (%@)", drugId);

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:[NSArray arrayWithObjects:[NSNumber numberWithInt:(int)HistoryEventServerStatusNew], [NSNumber numberWithInt:(int)HistoryEventServerStatusSynching], nil]
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];

	if (!historyEvents)
    {
        DebugLog(@"end get events to sync for drug (%@) (none found)", drugId);

		return nil;
    }
	
    for (HistoryEvent* event in historyEvents)
    {
        if ([event.serverStatus intValue] == (int)HistoryEventServerStatusNew)
            event.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusSynching];
    }
	
    [self commitHistoryDatabaseChanges:NO notifyServer:NO];
    
    DebugLog(@"end get events to sync for drug (%@)", drugId);

	return historyEvents;
}

- (BOOL) markHistoryEventAsSynched:(HistoryEvent*)event

{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !event)
		return NO;
    
    event.serverStatus = [NSNumber numberWithInt:(int)HistoryEventServerStatusSynched];
	
    [self commitHistoryDatabaseChanges:NO notifyServer:NO];
    
	return YES;
}

- (NSArray*) getHistoryEventsForDrugId:(NSString *)drugId afterCreationDate:(NSDate*)creationDate
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return nil;
    
    DebugLog(@"start get events after creationDate date for drug (%@)", drugId);

    NSArray* result = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                         withServerStatuses:nil
                                   withGUID:nil
                        betweenCreationDate:creationDate
                            andCreationDate:nil
                        betweenScheduleDate:nil
                            andScheduleDate:nil
                          includeOperations:nil
                          excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                       withPreferenceValues:nil
                   isAscendingCreationDates:[NSNumber numberWithBool:YES]
                   isAscendingScheduleDates:nil
                                      limit:0
                               errorMessage:nil];
    
    DebugLog(@"end get events after creationDate date for drug (%@)", drugId);

    return result;
}

- (BOOL) eventsExistForDrugId:(NSString*)drugId
{
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return NO;
	
    DebugLog(@"start events exist for drug (%@)", drugId);

    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];
    
    DebugLog(@"end events exist for drug (%@)", drugId);

	if (!historyEvents)
		return NO;
		
	return ([historyEvents count] > 0);
}

- (BOOL) takePillEventsWithNoDosageTypeExistForDrugId:(NSString*)drugId
{
    if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
        return NO;
    
    DebugLog(@"start events exist for drug (%@)", drugId);
    
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObjects:HistoryManagerTakePillOperationName, nil]
                                                   excludeOperations:nil
                                                withPreferenceValues:[NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], @"dosageType", nil]
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];
    
    DebugLog(@"end events exist for drug (%@)", drugId);
    
    if (!historyEvents)
        return NO;
    
    return ([historyEvents count] > 0);
}

- (NSString*) getDosageTypePrefValueForEvent:(HistoryEvent*)event prefKey:(NSString*)prefKey
{
    if (!prefKey)
        return nil;
    
    NSString* valStr = nil;
    if (event.dosageTypePrefKey1 && [event.dosageTypePrefKey1 isEqualToString:prefKey])
        valStr = event.dosageTypePrefValue1;
    else if (event.dosageTypePrefKey2 && [event.dosageTypePrefKey2 isEqualToString:prefKey])
        valStr = event.dosageTypePrefValue2;
    else if (event.dosageTypePrefKey3 && [event.dosageTypePrefKey3 isEqualToString:prefKey])
        valStr = event.dosageTypePrefValue3;
    else if (event.dosageTypePrefKey4 && [event.dosageTypePrefKey4 isEqualToString:prefKey])
        valStr = event.dosageTypePrefValue4;
    else if (event.dosageTypePrefKey5 && [event.dosageTypePrefKey5 isEqualToString:prefKey])
        valStr = event.dosageTypePrefValue5;
    return valStr;
}

// Returns whether to clamp the values when adding
- (void) getOffsetToRemainingRefillQuantityFromHistoryEvent:(HistoryEvent*)event remainingQuantityOffset:(float*)remainingQuantityOffset refillQuantityOffset:(int*)refillQuantityOffset
{
    *remainingQuantityOffset = 0.0f;
    *refillQuantityOffset = 0;
    
    if ([event.operation isEqualToString:HistoryManagerTakePillOperationName])
    {
        float thisRemainingQuantityOffset = 0.0f;
        if (event.dosageType)
        {
            NSString* remainingQuantityPrefKey = [[DrugDosageManager getInstance] getDoseQuantityToDecrementRemainingQuantityWithFileTypeName:event.dosageType];
            if (!remainingQuantityPrefKey)
                thisRemainingQuantityOffset = -1.0f;
            NSString* dosageStr = [self getDosageTypePrefValueForEvent:event prefKey:remainingQuantityPrefKey];
            if (dosageStr && [dosageStr length] > 0 && [dosageStr floatValue] > epsilon)
                thisRemainingQuantityOffset = -[dosageStr floatValue];
        }
        else
        {
            Drug* d = [[DataModel getInstance] findDrugWithId:event.drugId];
            if (d)
            {
                NSString* remainingQuantityPrefKey = [d.dosage getDoseQuantityToDecrementRemainingQuantity];
                if (!remainingQuantityPrefKey)
                    thisRemainingQuantityOffset = -1.0f;
            }
        }
        
        *remainingQuantityOffset += thisRemainingQuantityOffset;
   }
    else if ([event.operation isEqualToString:HistoryManagerRefillOperationName])
    {
        NSString* remainingQuantityAmountStr = [self getDosageTypePrefValueForEvent:event prefKey:RefillQuantityKey];
        if (remainingQuantityAmountStr && [remainingQuantityAmountStr length] > 0 && [remainingQuantityAmountStr floatValue] > epsilon)
            *remainingQuantityOffset = [remainingQuantityAmountStr floatValue];
        
        *refillQuantityOffset = -1;
    }
    else if ([event.operation isEqualToString:HistoryManagerAdjustInventoryOperationName])
    {
        NSString* remainingQuantityAmountStr = [self getDosageTypePrefValueForEvent:event prefKey:AdjustInventoryQuantityKey];
        if (remainingQuantityAmountStr && [remainingQuantityAmountStr length] > 0)
            *remainingQuantityOffset = [remainingQuantityAmountStr floatValue];
    }
    else if ([event.operation isEqualToString:HistoryManagerAdjustRefillOperationName])
    {
        NSString* refillQuantityAmountStr = [self getDosageTypePrefValueForEvent:event prefKey:AdjustRefillQuantityKey];
        if (refillQuantityAmountStr && [refillQuantityAmountStr length] > 0)
            *refillQuantityOffset = [refillQuantityAmountStr intValue];
    }
}

- (void) createSetInventoryEventForDrug:(NSString*)drugId
{
    DebugLog(@"start create setInventory event for drug (%@)", drugId);

    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

    NSMutableArray* historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObjects:HistoryManagerTakePillOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerRefillOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:NO]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];

    float remainingQuantityOffset = 0.0f;
    int refillQuantityOffset = 0;
    float endRemainingQuantity = 0.0f;
    int endRefillQuantity = [d.dosage getRefillsRemaining];
    [d.dosage getValueForRemainingQuantity:&endRemainingQuantity];
    
    NSDate* earliestDate = [NSDate date];
    if (historyEvents)
    {
        for (HistoryEvent* historyEvent in historyEvents)
        {
            float thisRemainingQuantityOffset = 0.0f;
            int thisRefillQuantityOffset = 0;
            [self getOffsetToRemainingRefillQuantityFromHistoryEvent:historyEvent remainingQuantityOffset:&thisRemainingQuantityOffset refillQuantityOffset:&thisRefillQuantityOffset];
            
            remainingQuantityOffset += thisRemainingQuantityOffset;
            refillQuantityOffset += thisRefillQuantityOffset;
        }
        
        // Note the oldest date and back it up by 1 sec
        if ([historyEvents count] > 0)
        {
            HistoryEvent* historyEvent = [historyEvents lastObject];
            earliestDate = [historyEvent.creationDate dateByAddingTimeInterval:-1];
        }
    }
    
    float remainingQuantity = endRemainingQuantity - remainingQuantityOffset;
    int refillQuantity = endRefillQuantity - refillQuantityOffset;

    int sigDigits = 0;
    int numDecimals = 0;
    BOOL displayNone = YES;
    BOOL allowZero = YES;
    [d.dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero];
    
    NSDictionary* preferencesDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [DrugDosage getStringFromQuantity:remainingQuantity unit:nil numDecimals:numDecimals], SetInventoryRemainingQuantityKey,
                                     [NSString stringWithFormat:@"%d", refillQuantity], SetInventoryRefillsRemainingKey,
                                     nil];
    
    [self addHistoryEvent:d.drugId
                     guid:nil
             creationDate:earliestDate
         eventDescription:nil
                operation:HistoryManagerSetInventoryOperationName
            operationData:nil
             scheduleDate:nil
          preferencesDict:preferencesDict
        isManuallyCreated:NO
             notifyServer:YES
             errorMessage:nil];
    
    DebugLog(@"end create setInventory event for drug (%@)", drugId);
}

- (void) updateRemainingRefillQuantityFromCompleteHistoryForDrug:(NSString*)drugId
{
    DebugLog(@"start update quantities from complete history for drug (%@)", drugId);

    // Find the set inventory event
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObject:HistoryManagerSetInventoryOperationName]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:NO]
                                            isAscendingScheduleDates:nil
                                                               limit:1
                                                        errorMessage:nil];
    
    if (!historyEvents || [historyEvents count] == 0)
    {
        [self createSetInventoryEventForDrug:drugId];
        
        DebugLog(@"end update quantities from complete history for drug (%@, setInventory created)", drugId);

        return;
    }
    
    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

    float remainingQuantityVal = 0.0f;
    int refillsRemainingVal = 0;

    HistoryEvent* event = [historyEvents firstObject];
    NSString* remainingQuantityStr = [self getDosageTypePrefValueForEvent:event prefKey:SetInventoryRemainingQuantityKey];
    NSString* refillsRemainingStr = [self getDosageTypePrefValueForEvent:event prefKey:SetInventoryRefillsRemainingKey];
    BOOL foundInitialRemainingQuantity = (remainingQuantityStr && [remainingQuantityStr length] > 0);
    BOOL foundInitialRefillsRemaining = (refillsRemainingStr && [refillsRemainingStr length] > 0);
    
    if (foundInitialRemainingQuantity || foundInitialRefillsRemaining)
    {
        if (foundInitialRemainingQuantity)
            remainingQuantityVal = [remainingQuantityStr floatValue];
        if (foundInitialRefillsRemaining)
            refillsRemainingVal = [refillsRemainingStr intValue];
        
        // Find all relevant pill events after that
        historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                      withServerStatuses:nil
                                                withGUID:nil
                                     betweenCreationDate:event.creationDate
                                         andCreationDate:nil
                                     betweenScheduleDate:nil
                                         andScheduleDate:nil
                                       includeOperations:[NSArray arrayWithObjects:HistoryManagerTakePillOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerRefillOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                       excludeOperations:nil
                                    withPreferenceValues:nil
                                isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                isAscendingScheduleDates:nil
                                                   limit:0
                                            errorMessage:nil];
        
        if (historyEvents)
        {
            // Adjust remaining quantity and refills remaining for each event
            for (HistoryEvent* event in historyEvents)
            {
                float remainingQuantityOffset = 0.0f;
                int refillQuantityOffset = 0;
                [self getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&remainingQuantityOffset refillQuantityOffset:&refillQuantityOffset];
                
                remainingQuantityVal += remainingQuantityOffset;
                refillsRemainingVal += refillQuantityOffset;
            }
       }
    }
    
    [d.dosage setValueForRemainingQuantity:remainingQuantityVal];
    [d.dosage setRefillsRemaining:refillsRemainingVal];
    
    DebugLog(@"end update quantities from complete history for drug (%@)", drugId);
}

- (NSArray*) getHistoryDateEventsForDrugIds:(NSArray*)drugIds
                     includePostponeEvents:(BOOL)includePostponeEvents
                              errorMessage:(NSString**)errorMessage
{
	if (errorMessage)
		*errorMessage = nil;

	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugIds || [drugIds count] == 0)
		return [[NSArray alloc] init];
	   
    DebugLog(@"start get history date events for drugs");

	// Query for any events and delete old ones
    NSMutableArray* excludeOperations = [[NSMutableArray alloc] init];
    [excludeOperations addObject:HistoryManagerSetInventoryOperationName];
    [excludeOperations addObject:HistoryManagerAdjustInventoryOperationName];
    [excludeOperations addObject:HistoryManagerAdjustRefillOperationName];

    if (!includePostponeEvents)
        [excludeOperations addObject:HistoryManagerPostponePillOperationName];
    
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:drugIds
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:nil
                                                   excludeOperations:excludeOperations
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];
	if (!historyEvents)
    {
        DebugLog(@"end get history date events for drugs (no events found)");

		return [[NSArray alloc] init];
    }
    
	NSArray* results = [HistoryDateEvents historyDateEventsListFromHistoryEvents:historyEvents];
    
    DebugLog(@"end get history date events for drugs");

    return results;
}

- (int) getNumTakePillEventsForDay:(NSDate*)date drugId:(NSString*)drugId
{
    if (!dbDataFile || !dbDataFile.managedObjectContext || !date || !drugId )
        return 0;
    
    DebugLog(@"start get # take pill events for day for drug (%@)", drugId);

    NSDate* startPeriod = [DosecastUtil getMidnightOnDate:date];
    NSDate* endPeriod = [DosecastUtil addDaysToDate:startPeriod numDays:1];

    // Query for any events
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:startPeriod
                                                     andCreationDate:endPeriod
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObject:HistoryManagerTakePillOperationName]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];
    
    DebugLog(@"end get # take pill events for day for drug (%@)", drugId);

	if (!historyEvents)
		return 0;
    
	return (int)[historyEvents count];
}

- (int) getNumTakePillEventsForPrior24Hours:(NSDate*)date drugId:(NSString*)drugId earliestEventTime:(NSDate**)earliestEventTime
{
    if (earliestEventTime)
        *earliestEventTime = nil;
    
    if (!dbDataFile || !dbDataFile.managedObjectContext || !date || !drugId )
        return 0;
    
    DebugLog(@"start get # take pill events for 24h for drug (%@)", drugId);

    NSDate* startPeriod = [DosecastUtil addDaysToDate:date numDays:-1];
    
    // Query for any events
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:startPeriod
                                                     andCreationDate:date
                                                 betweenScheduleDate:nil
                                                     andScheduleDate:nil
                                                   includeOperations:[NSArray arrayWithObject:HistoryManagerTakePillOperationName]
                                                   excludeOperations:nil
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:nil
                                                               limit:0
                                                        errorMessage:nil];
    
    DebugLog(@"end get # take pill events for 24h for drug (%@)", drugId);

	if (!historyEvents)
		return 0;
    
    int numEvents = (int)[historyEvents count];
    if (numEvents > 0 && earliestEventTime)
    {
        HistoryEvent* event = [historyEvents objectAtIndex:0];
        *earliestEventTime = event.creationDate;
    }
        
	return numEvents;		    
}

- (NSData*) createCSVFileFromHistoryDateEvents:(NSArray*)historyDateEvents
{	    
	DataModel* dataModel = [DataModel getInstance];
	int numHistoryDateEvents = (int)[historyDateEvents count];
	if (numHistoryDateEvents == 0)
		return nil;
	
    BOOL flagLateDoses = (dataModel.globalSettings.lateDosePeriodSecs > 0);
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSMutableString* columnNames = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryCSVColumnNames", @"Dosecast", [DosecastUtil getResourceBundle], @"Date,Time,Drug,Action,Description,ScheduledDate,ScheduledTime", @"The column names of the CSV file containing drug history"])];
    
    if (flagLateDoses)
    {
        [columnNames appendFormat:@",%@", 
         NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryCSVColumnNamesLate", @"Dosecast", [DosecastUtil getResourceBundle], @"Late,LatePeriod", @"The late column names of the CSV file containing drug history"])];
    }
    
	NSString* deletedDrugStr = NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryCSVDrugNameDeleted", @"Dosecast", [DosecastUtil getResourceBundle], @"<Deleted>", @"The drug name entered in the CSV file containing drug history when a drug has been deleted"]);
	NSMutableString* output = [NSMutableString stringWithFormat:@"%@\n", columnNames];
	for (int i = 0; i < numHistoryDateEvents; i++)
	{
		HistoryDateEvents* historyDateEvent = (HistoryDateEvents*)[historyDateEvents objectAtIndex:i];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];			
		NSString* dateStr = [dateFormatter stringFromDate:historyDateEvent.creationDate];
		
		int numEvents = (int)[historyDateEvent.editableHistoryEvents count];
		for (int j = 0; j < numEvents; j++)
		{
			EditableHistoryEvent* event = [historyDateEvent.editableHistoryEvents objectAtIndex:j];
			[output appendFormat:@"\"%@\",", dateStr];
            
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];

			[output appendFormat:@"\"%@\",", [dateFormatter stringFromDate:event.creationDate]];
			NSString* drugName = nil;
			if (event.drugId)
			{
				Drug* d = [dataModel findDrugWithId:event.drugId];
				drugName = [d.name stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
			}
			else
				drugName = deletedDrugStr;
			[output appendFormat:@"\"%@\",", drugName];
			[output appendFormat:@"\"%@\",", [self getOperationDescription:event.operation]];
            
            NSString* eventDescription = [self getEventDescriptionForHistoryEvent:event.drugId
                                                                      operation:event.operation
                                                                  operationData:event.operationData
                                                                     dosageType:event.dosageType
                                                                preferencesDict:[event createHistoryEventPreferencesDict]
                                                         legacyEventDescription:event.eventDescription
                                                                displayDrugName:YES];
            
			[output appendFormat:@"\"%@\",",
			 [eventDescription stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
            if (event.scheduleDate)
            {
                [dateFormatter setDateStyle:NSDateFormatterShortStyle];
                [dateFormatter setTimeStyle:NSDateFormatterNoStyle];			
                [output appendFormat:@"\"%@\",", [dateFormatter stringFromDate:event.scheduleDate]];

                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                [output appendFormat:@"\"%@\"", [dateFormatter stringFromDate:event.scheduleDate]];
            }
            else
            {
                [output appendString:@"\"\","];
                [output appendString:@"\"\""];
            }
            
            if (flagLateDoses)
            {
                BOOL isLate = (event.late && [event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame);
                [output appendFormat:@",%d,\"%@\"", (isLate ? 1 : 0), (isLate ? [event latePeriodDescription] : @"")];
            }
            
            [output appendString:@"\n"];
		}
	}
	
	return [output dataUsingEncoding:NSUTF8StringEncoding];	
}

- (NSData*) getDoseHistoryAsCSVFileForDrugIds:(NSArray*)drugIds
                       includePostponeEvents:(BOOL)includePostponeEvents
                                errorMessage:(NSString**)errorMessage
{
	NSArray* historyDateEvents = [self getHistoryDateEventsForDrugIds:drugIds
                                                includePostponeEvents:includePostponeEvents
                                                         errorMessage:errorMessage];
	if (historyDateEvents)
		return [self createCSVFileFromHistoryDateEvents:historyDateEvents];
	else
		return nil;
}

// Client must release the returned array
- (void) removeOldDebugLogEvents
{
	if (!dbDataFile || !dbDataFile.managedObjectContext || ![DataModel getInstance].globalSettings.debugLoggingEnabled)
		return;
		
    DebugLog(@"start remove old debug events");

	// Force the time to midnight
	NSDate* thisMorning = [DosecastUtil getMidnightOnDate:[NSDate date]];
	
	// Get the date of the event boundary
 	NSDate* dateBoundary = [DosecastUtil addDaysToDate:thisMorning numDays:-MAX_NUM_DEBUGLOG_DAYS];
	
	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"DebugLogEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
	[request setEntity:entity];
	
	NSPredicate* predicate = [NSPredicate predicateWithFormat:@"creationDate < %@", dateBoundary];
	[request setPredicate:predicate];
		
	NSError *error = nil;
	NSMutableArray *mutableFetchResults = [[dbDataFile.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];

	int numResults = (int)[mutableFetchResults count];
	if (numResults > 0)
	{
		for (int i = 0; i < numResults; i++)
		{
			[dbDataFile.managedObjectContext deleteObject:[mutableFetchResults objectAtIndex:i]];
		}
	}
	
    DebugLog(@"end remove old debug events");
}

- (BOOL) deleteAllDebugLogEvents
{
    if (!dbDataFile || !dbDataFile.managedObjectContext)
        return NO;
    
    DebugLog(@"start delete all debug events");

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"DebugLogEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
	[request setEntity:entity];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:YES];
	NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
	[request setSortDescriptors:sortDescriptors];
	
	NSError *error = nil;
    NSArray* results = [[dbDataFile.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    
    if (!results)
    {
        DebugLog(@"end delete all debug events (none found)");

        return NO;
    }
    
    int numResults = (int)[results count];
    for (int i = 0; i < numResults; i++)
    {
        DebugLogEvent* event = (DebugLogEvent*)[results objectAtIndex:i];
        [dbDataFile.managedObjectContext deleteObject:event];
    }    
    
    [self commitDebugLogChanges];
    
    DebugLog(@"end delete all debug events");

    return YES;
}

- (void) commitDebugLogChanges
{
    // If we are in the middle of a batch operation, postpone this until later
    if ([self debugLogBatchUpdatesInProgress])
    {
        needsDebugLogCommit = YES;
        return;
    }

    if ([dbDataFile.managedObjectContext hasChanges])
    {
        if (dbDataFile)
            [dbDataFile saveChanges];
    }
    
    needsDebugLogCommit = NO;
}

- (BOOL) addDebugLogEvent:(NSDate*)date
					 file:(NSString*)file
					 line:(int)line
		 eventDescription:(NSString*)eventDescription
{	
	if (!dbDataFile || !dbDataFile.managedObjectContext || !date || !file)
		return NO;
    
    if (completedStartup && [DataModel getInstance].globalSettings.debugLoggingEnabled)
    {
        // Create and configure a new instance of the DebugLogEvent entity
        DebugLogEvent *event = (DebugLogEvent *)[NSEntityDescription insertNewObjectForEntityForName:@"DebugLogEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
        event.creationDate = date;
        event.apiVersion = [DataModel getInstance].globalSettings.apiVersion.versionString;
        if (eventDescription)
            event.eventDescription = eventDescription;
        else
            event.eventDescription = @"";
        event.file = file;
        event.line = [NSNumber numberWithInt:line];
        
        [self commitDebugLogChanges];

        return YES;
    }
    else if (!completedStartup)
    {
        [cachedDebugLogEvents addObject:
         [NSDictionary dictionaryWithObjectsAndKeys:date, HistoryManagerDebugLogCachedDateKey,
          file, HistoryManagerDebugLogCachedFileKey,
          [NSNumber numberWithInt:line], HistoryManagerDebugLogCachedLineKey,
          eventDescription, HistoryManagerDebugLogCachedEventDescriptionKey, nil]];

        return YES;
    }
    else
        return NO;
}

- (BOOL) addDebugLogCachedEvent:(NSDictionary*)event
{
    NSDate* date = [event objectForKey:HistoryManagerDebugLogCachedDateKey];
    NSString* file = [event objectForKey:HistoryManagerDebugLogCachedFileKey];
    int line = [[event objectForKey:HistoryManagerDebugLogCachedLineKey] intValue];
    NSString* eventDescription = [event objectForKey:HistoryManagerDebugLogCachedEventDescriptionKey];
    return [self addDebugLogEvent:date file:file line:line eventDescription:eventDescription];
}

- (NSArray*) getAllDebugLogEvents
{
	if (!dbDataFile || !dbDataFile.managedObjectContext || ![DataModel getInstance].globalSettings.debugLoggingEnabled)
		return nil;
	
	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"DebugLogEvent" inManagedObjectContext:dbDataFile.managedObjectContext];
	[request setEntity:entity];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:YES];
	NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
	[request setSortDescriptors:sortDescriptors];
	
	NSError *error = nil;
    NSArray* results = [[dbDataFile.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    
    return results;
}

- (NSData*) getDebugLogAsCSVFile
{
	NSArray* debugLogEvents = [self getAllDebugLogEvents];
	if (!debugLogEvents)
		return nil;
	
	int numEvents = (int)[debugLogEvents count];
	if (numEvents == 0)
		return nil;
	
	NSMutableString* output = [NSMutableString stringWithString:@"apiVersion,creationDate,eventDescription,file,line\n"];
	for (int i = 0; i < numEvents; i++)
	{
		DebugLogEvent* event = (DebugLogEvent*)[debugLogEvents objectAtIndex:i];
		[output appendFormat:@"\"%@\",", event.apiVersion];
		[output appendFormat:@"\"%@\",", event.creationDate];
		[output appendFormat:@"\"%@\",", 
		 [event.eventDescription stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
		[output appendFormat:@"\"%@\",", event.file];
		[output appendFormat:@"\"%d\"\n", [event.line intValue]];
	}
	
	return [output dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL) checkForMissedDosesForDrugId:(NSString*)drugId errorMessage:(NSString**)errorMessage
{    
    if (errorMessage)
		*errorMessage = nil;
    
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId)
		return NO;

    DataModel* dataModel = [DataModel getInstance];
    Drug* d = [dataModel findDrugWithId:drugId];
    if (!d || ![d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        return NO;
    
    ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;
    if (!scheduledReminder.logMissedDoses ||
        (scheduledReminder.remindersEnabled && !scheduledReminder.overdueReminder) || // only check for missed doses if this is a scheduled drug that is overdue
        ([d isManaged] && ((ManagedDrugDosage*)d.dosage).isDiscontinued)) // ignore discontinued managed meds
    {
        return YES;
    }
    
    [self beginDebugLogBatchUpdates];
    
    DebugLog(@"checkForMissedDoses start for drug (%@)", drugId);
    
    // Get the start and end date of the period to check
    NSDate* checkPeriodStart = nil;
    NSDate* effLastTaken = [self getEffectiveLastTakenTimeForDrugId:drugId];
    if (effLastTaken)
        checkPeriodStart = [DosecastUtil addTimeIntervalToDate:effLastTaken timeInterval:1]; // don't include the effLastTaken time, since we have that covered
    else if (!scheduledReminder.treatmentEndDate || [scheduledReminder.treatmentEndDate timeIntervalSinceNow] > 0)
    {
        NSDate* beginDate = scheduledReminder.treatmentStartDate;
        if (d.created && [d.created timeIntervalSinceDate:beginDate] > 0)
            beginDate = d.created;

        beginDate = [beginDate dateByAddingTimeInterval:-1];
        
        checkPeriodStart = [scheduledReminder getReminderTimeAfterTime:beginDate remindAtLimit:NO];
    }
    
    NSDate* checkPeriodEnd = [scheduledReminder getCurrentScheduledTime];
    
    // Only continue if we have a valid start period
    if (checkPeriodStart)
    {
        NSString* thisDrugError = nil;
        
        // Query for any events for this drug after the lastChecked date
        NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                      withServerStatuses:nil
                                                                withGUID:nil
                                                     betweenCreationDate:nil
                                                         andCreationDate:nil
                                                     betweenScheduleDate:checkPeriodStart
                                                         andScheduleDate:checkPeriodEnd
                                                       includeOperations:nil
                                                       excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                    withPreferenceValues:nil
                                                isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                                isAscendingScheduleDates:[NSNumber numberWithBool:YES]
                                                                   limit:0
                                                            errorMessage:&thisDrugError];
        if (!historyEvents)
        {
            DebugLog(@"checkForMissedDoses end for drug (%@): error (%@)", drugId, thisDrugError);
            if (errorMessage)
                *errorMessage = thisDrugError;
            [self endDebugLogBatchUpdates];
            return NO;
        }
        
        // Find the first reminder time on or after checkPeriodStart (but back up 1 second to include checkPeriodStart)
        NSDate* currReminderTime = [scheduledReminder getReminderTimeAfterTime:[DosecastUtil addTimeIntervalToDate:checkPeriodStart timeInterval:-1] remindAtLimit:NO];
        
        int numResults = (int)[historyEvents count];
        int historyEventIndex = 0;
        NSDate* postponeAdjustedCreationDate = currReminderTime;

        // Loop through reminder times until the end of the period is encountered (within a minute)
        while ([currReminderTime timeIntervalSinceDate:checkPeriodEnd] < -60)
        {
            HistoryEvent* event = nil;
            if (historyEventIndex < numResults)
                event = [historyEvents objectAtIndex:historyEventIndex];
            
            NSTimeInterval reminderTimeScheduleTimeDiff = 0;
            if (event)
            {
                reminderTimeScheduleTimeDiff = fabs([currReminderTime timeIntervalSinceDate:event.scheduleDate]);
            }
            
            if (historyEventIndex == numResults || !event) // no event exists
            {
                // Log a missed pill event and move to the next reminder
                [self addHistoryEvent:d.drugId
                                 guid:nil
                         creationDate:postponeAdjustedCreationDate
                     eventDescription:nil
                            operation:HistoryManagerMissPillOperationName
                        operationData:nil
                         scheduleDate:currReminderTime
                      preferencesDict:nil
                    isManuallyCreated:NO
                         notifyServer:YES
                         errorMessage:nil];

                currReminderTime = [scheduledReminder getReminderTimeAfterTime:currReminderTime remindAtLimit:NO];
                postponeAdjustedCreationDate = currReminderTime;
            }
            else if (!event.scheduleDate) // no schedule time exists for this event
            {
                // Skip this event
                historyEventIndex++;
            }
            else if (reminderTimeScheduleTimeDiff < 60.0-epsilon) // if the reminder time and schedule time are within a minute of each other
            {
                // If we found a take, skip, or missed pill, then we can advance the current reminder time and look at the next event.
                // If we didn't find one of these (like we found a postpone), then only look at the next event because this dose may have been missed.
                if ([event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame ||
                    [event.operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame ||
                    [event.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
                {
                    // Skip this event and move to the next reminder
                    currReminderTime = [scheduledReminder getReminderTimeAfterTime:currReminderTime remindAtLimit:NO];
                    postponeAdjustedCreationDate = currReminderTime;
                }
                // If we found a postpone event
                else if ([event.operation caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame && event.operationData)
                {
                    // Find the postpone duration, calculate the new postponed reminder time, and set that as the new creation date for the next miss event
                    int postponeDurationSecs = [event.operationData intValue];
                    postponeAdjustedCreationDate = [DosecastUtil addTimeIntervalToDate:event.creationDate timeInterval:postponeDurationSecs];
                }
                historyEventIndex++;
            }
            else if ([currReminderTime timeIntervalSinceDate:event.scheduleDate] < 0) // if the reminder time is earlier than a minute away from the schedule time
            {
                // Log a missed pill and move to the next reminder
                [self addHistoryEvent:d.drugId
                                 guid:nil
                         creationDate:postponeAdjustedCreationDate
                     eventDescription:nil
                            operation:HistoryManagerMissPillOperationName
                        operationData:nil
                         scheduleDate:currReminderTime
                      preferencesDict:nil
                    isManuallyCreated:NO
                         notifyServer:YES
                         errorMessage:nil];
                currReminderTime = [scheduledReminder getReminderTimeAfterTime:currReminderTime remindAtLimit:NO];
                postponeAdjustedCreationDate = currReminderTime;
            }
            else // if ([currReminderTime timeIntervalSinceDate:event.scheduleDate] > 0) // if the reminder time is later than a minute away from the schedule time
            {
                // Skip this event
                historyEventIndex++;                        
            }
        }
                                        
    }
        
    DebugLog(@"checkForMissedDoses end for drug (%@)", drugId);

    [self endDebugLogBatchUpdates];
    
    return YES;
}

// Returns dose times which are missing history entries for a particular drug. Assumes the doseTimes are in chronological order.
- (NSArray*) findMissedDosesForDrugId:(NSString*)drugId amongDoseTimes:(NSArray*)doseTimes errorMessage:(NSString**)errorMessage
{
    if (errorMessage)
		*errorMessage = nil;
    
	if (!dbDataFile || !dbDataFile.managedObjectContext  || !drugId || !doseTimes || [doseTimes count] == 0)
		return nil;
    
    [self beginDebugLogBatchUpdates];
    
    DebugLog(@"findMissedDosesForDrugId start for drug (%@)", drugId);

    NSMutableArray* missedDoses = [[NSMutableArray alloc] init];

    doseTimes = [doseTimes sortedArrayUsingSelector:@selector(compare:)];
    NSDate* checkPeriodStart = [doseTimes objectAtIndex:0];

    NSDate* checkPeriodEnd = [DosecastUtil addTimeIntervalToDate:[doseTimes lastObject] timeInterval:1]; // Add 1 to the last time so we include it when searching for history events

    NSString* thisDrugError = nil;
    
    // Query for any events for this drug
    NSMutableArray *historyEvents = [self getHistoryEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                                  withServerStatuses:nil
                                                            withGUID:nil
                                                 betweenCreationDate:nil
                                                     andCreationDate:nil
                                                 betweenScheduleDate:checkPeriodStart
                                                     andScheduleDate:checkPeriodEnd
                                                   includeOperations:nil
                                                   excludeOperations:[NSArray arrayWithObjects:HistoryManagerSetInventoryOperationName, HistoryManagerAdjustInventoryOperationName, HistoryManagerAdjustRefillOperationName, nil]
                                                withPreferenceValues:nil
                                            isAscendingCreationDates:[NSNumber numberWithBool:YES]
                                            isAscendingScheduleDates:[NSNumber numberWithBool:YES]
                                                               limit:0
                                                        errorMessage:&thisDrugError];
    if (!historyEvents)
    {
        DebugLog(@"findMissedDosesForDrugId end for drug (%@): error (%@)", drugId, thisDrugError);
        if (errorMessage)
            *errorMessage = thisDrugError;
        [self endDebugLogBatchUpdates];
        return nil;
    }
    
    // Find the first dose time
    int doseTimeNum = 0;
    int numDoseTimes = (int)[doseTimes count];
    
    int numResults = (int)[historyEvents count];
    int historyEventIndex = 0;
    
    // Loop through dose times
    while (doseTimeNum < numDoseTimes)
    {
        NSDate* currDoseTime = [doseTimes objectAtIndex:doseTimeNum];

        HistoryEvent* event = nil;
        if (historyEventIndex < numResults)
            event = [historyEvents objectAtIndex:historyEventIndex];
        
        NSTimeInterval reminderTimeScheduleTimeDiff = 0;
        if (event)
        {
            reminderTimeScheduleTimeDiff = fabs([currDoseTime timeIntervalSinceDate:event.scheduleDate]);
        }
        
        if (historyEventIndex == numResults || !event) // no event exists
        {
            // Add this time to our missed dose time list
            [missedDoses addObject:currDoseTime];
            doseTimeNum++;
        }
        else if (!event.scheduleDate) // no schedule time exists for this event
        {
            // Skip this event
            historyEventIndex++;
        }
        else if (reminderTimeScheduleTimeDiff < 60.0-epsilon) // if the reminder time and schedule time are within a minute of each other
        {
            // If we found a take, skip, or missed pill, then we can advance the current reminder time and look at the next event.
            // If we didn't find one of these (like we found a postpone), then only look at the next event because this dose may have been missed.
            if ([event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame ||
                [event.operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame ||
                [event.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            {
                // Skip this event and move to the next dose time
                doseTimeNum++;
            }
            historyEventIndex++;
        }
        else if ([currDoseTime timeIntervalSinceDate:event.scheduleDate] < 0) // if the reminder time is earlier than a minute away from the schedule time
        {
            // Add this time to our missed dose time list
            [missedDoses addObject:currDoseTime];
            doseTimeNum++;
        }
        else // if ([currDoseTime timeIntervalSinceDate:event.scheduleDate] > 0) // if the reminder time is later than a minute away from the schedule time
        {
            // Skip this event
            historyEventIndex++;
        }
    }
    
    DebugLog(@"findMissedDosesForDrugId end for drug (%@)", drugId);
    [self endDebugLogBatchUpdates];
    
    return missedDoses;
}

- (NSDictionary*) createHistoryEventPreferencesDict:(HistoryEvent*)event
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    if (event.dosageType && [event.dosageType length] > 0)
        [dict setObject:event.dosageType forKey:DosageTypeKey];
    if (event.dosageTypePrefKey1 && [event.dosageTypePrefKey1 length] > 0)
        [dict setObject:event.dosageTypePrefValue1 forKey:event.dosageTypePrefKey1];
    if (event.dosageTypePrefKey2 && [event.dosageTypePrefKey2 length] > 0)
        [dict setObject:event.dosageTypePrefValue2 forKey:event.dosageTypePrefKey2];
    if (event.dosageTypePrefKey3 && [event.dosageTypePrefKey3 length] > 0)
        [dict setObject:event.dosageTypePrefValue3 forKey:event.dosageTypePrefKey3];
    if (event.dosageTypePrefKey4 && [event.dosageTypePrefKey4 length] > 0)
        [dict setObject:event.dosageTypePrefValue4 forKey:event.dosageTypePrefKey4];
    if (event.dosageTypePrefKey5 && [event.dosageTypePrefKey5 length] > 0)
        [dict setObject:event.dosageTypePrefValue5 forKey:event.dosageTypePrefKey5];
    return dict;
}

// Perform initialization at startup when it is safe to do so
- (void) handleStartupTasks
{
    completedStartup = YES;
    
    [self beginDebugLogBatchUpdates];
    
    // Write any cached debug log entries now
    if ([DataModel getInstance].globalSettings.debugLoggingEnabled)
    {
        for (NSDictionary* cachedLogEntry in cachedDebugLogEvents)
            [self addDebugLogCachedEvent:cachedLogEntry];
    }
    
    [self endDebugLogBatchUpdates];
    [cachedDebugLogEvents removeAllObjects];
    
    // Cleanup old events
    [self removeOldEvents];
    [self removeOldDebugLogEvents];
    
    if ([dbDataFile.managedObjectContext hasChanges])
    {
        if (dbDataFile)
            [dbDataFile saveChanges];
    }
}

// Called prior to beginning a batch of LocalNotificationManager calls - for performance purposes
- (void) beginBatchUpdates
{
    [historyBatchUpdatesStack addObject:[NSNumber numberWithBool:YES]];
}

// Whether batch updates are in progress
- (BOOL) batchUpdatesInProgress
{
    return ([historyBatchUpdatesStack count] > 0);
}

// Called after ending a batch of LocalNotificationManager calls - for performance purposes
- (void) endBatchUpdates:(BOOL)notifyEdit
{
    if ([self batchUpdatesInProgress])
        [historyBatchUpdatesStack removeLastObject];
    
    if (![self batchUpdatesInProgress])
    {
        if (needsCommit)
            [self commitHistoryDatabaseChanges:notifyEdit notifyServer:NO];
    }
}

- (void) beginDebugLogBatchUpdates
{
    if (![DataModel getInstance].globalSettings.debugLoggingEnabled)
        return;
    
    [debugLogBatchUpdatesStack addObject:[NSNumber numberWithBool:YES]];
}

- (BOOL) debugLogBatchUpdatesInProgress
{
    if (![DataModel getInstance].globalSettings.debugLoggingEnabled)
        return NO;

    return ([debugLogBatchUpdatesStack count] > 0);
}

- (void) endDebugLogBatchUpdates
{
    if (![DataModel getInstance].globalSettings.debugLoggingEnabled)
        return;

    if ([self debugLogBatchUpdatesInProgress])
        [debugLogBatchUpdatesStack removeLastObject];
    
    if (![self debugLogBatchUpdatesInProgress])
    {
        if (needsDebugLogCommit)
            [self commitDebugLogChanges];
    }
}

@end
