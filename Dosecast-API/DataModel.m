//
//  DataModel.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/6/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DataModel.h"
#import "Drug.h"
#import "JSONConverter.h"
#import "PurchaseManager.h"
#import "DosecastUtil.h"
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "LocalNotificationManager.h"
#import "ReachabilityManager.h"
#import "GlobalSettings.h"
#import "HistoryManager.h"
#import "AddressBookContact.h"
#import "CustomNameIDList.h"
#import "CustomDrugDosage.h"
#import "PillNotificationManager.h"
#import "DrugDosageManager.h"
#import "DosecastDataFile.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "EditableHistoryEvent.h"
#import "DatabaseDrugDosage.h"
#import "DrugImageManager.h"
#import "ManagedDrugDosage.h"
#import "Group.h"
#import "VersionNumber.h"
#import "LogManager.h"
#import "HistoryEvent.h"
#import "ContactsHelper.h"

static DataModel *gInstance = nil;

// Name of data file
static NSString *DataFilename = @"PillPopperData.plist";

// Keys for data in mutable dictionary used for file I/O
static NSString *UserIDKey = @"UserID";
static NSString *HardwareIDKey = @"HardwareID";

// Keys for data in dictionary used for JSON parsing
static NSString *DrugListKey = @"pillList";

static NSString *CurrentTimeKey = @"currentTime";
static NSString *DatabaseRoutePicklistName = @"databaseRoute";
static NSString *DatabaseAmountQuantityName = @"databaseAmount";
static NSString *DatabaseStrengthQuantityName = @"databaseStrength";

static NSString *DosageTypeKey = @"dosageType";
static NSString *DrugIDKey = @"pillId";
static NSString *SyncNeededKey = @"syncNeeded";
static NSString *WasExceedingMaxLocalNotificationsKey = @"wasExceedingMaxLocalNotifications";
static NSString *IsDiscontinuedKey = @"managedDropped";
static NSString *DeletedDrugIDsKey = @"deletedPillList";
static NSString *ServerEditTimeKey = @"serverEditTime";
static NSString *ServerEditSourceKey = @"serverEditSource";
static NSString *DrugHistoryKey = @"history";
static NSString *DrugHistoryEntriesKey = @"entries";
static NSString *ServerLastTakenKey = @"last_taken";
static NSString *ServerEffLastTakenKey = @"eff_last_taken";
static NSString *ServerNotifyAfterKey = @"notify_after";
static NSString *GroupNameKey = @"groupName";
static NSString *GroupInfoKey = @"groupInfo";
static NSString *GroupIDKey = @"groupId";
static NSString *GroupFoundKey = @"groupFound";
static NSString *GroupDescriptionsKey = @"descriptions";
static NSString *GroupDisplayNameKey = @"displayName";
static NSString *GroupTOSAddendumKey = @"tosAddendum";
static NSString *GroupDescriptionKey = @"description";
static NSString *GroupGivesPremiumKey = @"givesPremium";
static NSString *GroupLogoGUIDKey = @"logoGuid";
static NSString *GroupPasswordKey = @"password";
static NSString *GroupMembershipKey = @"groupMembership";
static NSString *GroupJoinResultKey = @"groupJoin";
static NSString *GroupLeaveResultKey = @"groupLeave";
static NSString *AccountCreatedKey = @"created";
static NSString *WasDetachedKey = @"wasDetached";
static NSString *CompletedInitialSyncKey = @"completedInitialSync";

static const int MAX_LOCAL_NOTIFICATIONS = 64;
static float epsilon = 0.0001;

// Notifications
NSString *DataModelDataRefreshNotification = @"DataModelDataRefreshNotification";
NSString *DataModelDeleteAllDataNotification = @"DataModelDeleteAllDataNotification";

NSString *DataModelDataRefreshNotificationServerMethodCallsKey = @"DataModelDataRefreshNotificationServerMethodCallsKey";
NSString *DataModelDataRefreshNotificationDeletedDrugIdsKey = @"DataModelDataRefreshNotificationDeletedDrugIdsKey";

@implementation DataModel

// Auto-generated property accessors
@synthesize appLastOpened;
@synthesize notificationsPaused;
@synthesize fileWritesPaused;
@synthesize clientVersion;
@synthesize userInteractionsAllowed;
@synthesize apiFlags;
@synthesize persistentFlags;
@synthesize delegate;
@synthesize globalSettings;
@synthesize wasExceedingMaxLocalNotifications;
@synthesize deletedDrugIDs;
@synthesize drugList;
@synthesize groups;
@synthesize accountCreated;
@synthesize wasDetached;
@synthesize contactsHelper;

- (id)init
{
    return [self initWithAPIFlags:[[NSArray alloc] init]];
}

- (id)initWithAPIFlags:(NSArray*)flags
{
    if ((self = [super init]))
    {
        apiFlags = [[FlagDictionary alloc] initWithFlags:flags];
        NSURL* dataFileURL = [NSURL fileURLWithPath:[DosecastUtil getPathToLocalFile:DataFilename]];
        dataFile = [[DosecastDataFile alloc] initWithURL:dataFileURL];
		globalSettings = [[GlobalSettings alloc] initWithAPIFlags:flags];
        globalSettings.delegate = self;
		userID = nil;
        hardwareID = nil;
        appLastOpened = [NSDate date];
		delegate = nil;
		notificationsPaused = NO;
		fileWritesPaused = NO;
		didNotifyDuringPause = NO;
		clientVersion = @"Version 1.0";
		serverMethodCallsWhilePaused = [[NSMutableSet alloc] init];
        deletedDrugIdsWhilePaused = [[NSMutableSet alloc] init];
        userInteractionsAllowed = YES;
        persistentFlags = [[FlagDictionary alloc] init];
        syncNeeded = NO;
        isSyncInProgress = NO;
        requiresFollowOnSync = NO;
        wasExceedingMaxLocalNotifications = NO;
        deletedDrugIDs = [[NSMutableSet alloc] init];
        drugList = [[NSMutableArray alloc] init];
        groups = [[NSMutableArray alloc] init];
        accountCreated = nil;
        wasDetached = NO;
        deviceToken = @"";
        completedInitialSync = NO;
        contactsHelper = [[ContactsHelper alloc] init];
        
        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAPIVersionUpgrade:)
                                                     name:GlobalSettingsAPIVersionUpgrade
                                                   object:nil];
    }
	
    return self;
}

- (void)dealloc
{
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalSettingsAPIVersionUpgrade object:nil];
}

// Singleton methods

+ (DataModel*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

+ (DataModel*) getInstanceWithAPIFlags:(NSArray*)flags
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] initWithAPIFlags:flags];
    }
    
    return(gInstance);    
}

- (void)handleAPIVersionUpgrade:(NSNotification*)notification
{
    VersionNumber* lastAPIVersionNumber = notification.object;
    if ([lastAPIVersionNumber compareWithVersionString:@"Version 6.0.9"] == NSOrderedSame) // upgrade from v6.0.9
    {
        self.syncNeeded = YES;
    }
}

- (NSString*) deviceToken
{
    return deviceToken;
}

- (void) setDeviceToken:(NSString *)token
{
    if (!token)
        token = @"";
    if (![deviceToken isEqualToString:token])
    {
        deviceToken = token;
        self.syncNeeded = YES;
    }
}

- (void) addReminderTime:(NSNumber*)reminderTime toReminderTimeFrequencyDict:(NSMutableDictionary*)reminderTimeFrequencyDict
{
    int val = 0;
    NSNumber* valNum = [reminderTimeFrequencyDict objectForKey:reminderTime];
    if (valNum)
        val = [valNum intValue];
    val += 1;
    [reminderTimeFrequencyDict setObject:[NSNumber numberWithInt:val] forKey:reminderTime];
}

// Returns whether the current drug list is over the max number of local notifications.
- (BOOL)isExceedingMaxLocalNotifications
{
    // Calculate the total reminders used
    int totalEstimated = 0;
    
    NSMutableDictionary* dailyScheduledDoseFrequency = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* weeklyScheduledDoseFrequency = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* monthlyScheduledDoseFrequency = [[NSMutableDictionary alloc] init];
    int secondaryReminderPeriodSecs = globalSettings.secondaryReminderPeriodSecs;
    
	for (Drug* d in drugList)
	{
		totalEstimated += [d.reminder getMaxNumLocalNotificationsUsed];
        
        // For scheduled reminders, create a histogram of all reminder times for daily, weekly, and monthly reminders - so we can count frequencies for each
        if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]] &&
            d.reminder.remindersEnabled &&
            (!d.reminder.treatmentEndDate || [d.reminder.treatmentEndDate timeIntervalSinceNow] > 0))
        {
            ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;
            
            // Add reminder times into the historygram for daily doses (including secondary ones)
            if (scheduledReminder.frequency == ScheduledDrugFrequencyDaily)
            {
                for (NSNumber* reminderTime in scheduledReminder.reminderTimes)
                {
                    [self addReminderTime:reminderTime toReminderTimeFrequencyDict:dailyScheduledDoseFrequency];
                    
                    if (d.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                    {
                        NSDate* reminderTimeDate = [DosecastUtil get24hrTimeAsDate:[reminderTime intValue]];
                        reminderTimeDate = [DosecastUtil addTimeIntervalToDate:reminderTimeDate timeInterval:secondaryReminderPeriodSecs];
                        NSNumber* secondaryReminderTime = [NSNumber numberWithInt:[DosecastUtil getDateAs24hrTime:reminderTimeDate]];
                        [self addReminderTime:secondaryReminderTime toReminderTimeFrequencyDict:dailyScheduledDoseFrequency];
                    }
                }
            }
            // Add reminder times into the historygram for weekly doses (including secondary ones) - for each day of the week
            else if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly)
            {
                for (NSNumber* weekday in scheduledReminder.weekdays)
                {
                    NSMutableDictionary* timeDict = [weeklyScheduledDoseFrequency objectForKey:weekday];
                    if (!timeDict)
                        timeDict = [[NSMutableDictionary alloc] init];
                    for (NSNumber* reminderTime in scheduledReminder.reminderTimes)
                    {
                        [self addReminderTime:reminderTime toReminderTimeFrequencyDict:timeDict];
                        
                        if (d.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                        {
                            NSDate* reminderTimeDate = [DosecastUtil get24hrTimeAsDate:[reminderTime intValue]];
                            reminderTimeDate = [DosecastUtil addTimeIntervalToDate:reminderTimeDate timeInterval:secondaryReminderPeriodSecs];
                            NSNumber* secondaryReminderTime = [NSNumber numberWithInt:[DosecastUtil getDateAs24hrTime:reminderTimeDate]];
                            [self addReminderTime:secondaryReminderTime toReminderTimeFrequencyDict:timeDict];
                        }
                    }
                    [weeklyScheduledDoseFrequency setObject:timeDict forKey:weekday];
                }
            }
            // Add reminder times into the historygram for monthly doses (including secondary ones) - for the day of month
            else if (scheduledReminder.frequency == ScheduledDrugFrequencyMonthly)
            {
                NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
                unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
                NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
                NSDateComponents* startDateComponents = [cal components:unitFlags fromDate:scheduledReminder.treatmentStartDate];
                NSNumber* dayOfMonth = [NSNumber numberWithInteger:[startDateComponents day]];

                NSMutableDictionary* timeDict = [monthlyScheduledDoseFrequency objectForKey:dayOfMonth];
                if (!timeDict)
                    timeDict = [[NSMutableDictionary alloc] init];
                for (NSNumber* reminderTime in scheduledReminder.reminderTimes)
                {
                    [self addReminderTime:reminderTime toReminderTimeFrequencyDict:timeDict];
                    
                    if (d.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                    {
                        NSDate* reminderTimeDate = [DosecastUtil get24hrTimeAsDate:[reminderTime intValue]];
                        reminderTimeDate = [DosecastUtil addTimeIntervalToDate:reminderTimeDate timeInterval:secondaryReminderPeriodSecs];
                        NSNumber* secondaryReminderTime = [NSNumber numberWithInt:[DosecastUtil getDateAs24hrTime:reminderTimeDate]];
                        [self addReminderTime:secondaryReminderTime toReminderTimeFrequencyDict:timeDict];
                    }
                }
                [monthlyScheduledDoseFrequency setObject:timeDict forKey:dayOfMonth];
            }
        }
	}
    
    // Now add up all the excess reminders (i.e. reminders that have been double-counted because their notifications will be merged during scheduling)
    int excessReminders = 0;
    for (NSNumber* val in [dailyScheduledDoseFrequency allValues])
    {
        excessReminders += [val intValue]-1;
    }
    for (NSMutableDictionary* dict in [weeklyScheduledDoseFrequency allValues])
    {
        for (NSNumber* val in [dict allValues])
        {
            excessReminders += [val intValue]-1;
        }
    }
    for (NSMutableDictionary* dict in [monthlyScheduledDoseFrequency allValues])
    {
        for (NSNumber* val in [dict allValues])
        {
            excessReminders += [val intValue]-1;
        }
    }
    
    totalEstimated -= excessReminders;
    
    return totalEstimated > MAX_LOCAL_NOTIFICATIONS;
}

// Populates the given dictionary with the data model elements
- (void)populateDictionaryWithDataModel:(NSMutableDictionary*)dict
{
	// Populate primitives
    [globalSettings populateDictionary:dict forSyncRequest:NO completedInitialSync:completedInitialSync];
	
    NSMutableArray* thisDeletedDrugIDs = [NSMutableArray arrayWithArray:[deletedDrugIDs allObjects]];
    [dict setObject:thisDeletedDrugIDs forKey:DeletedDrugIDsKey];

	// Populate drugs
	NSMutableArray* dictDrugList = [[NSMutableArray alloc] init];
	for (int i = 0; i < [drugList count]; i++)
	{
		Drug* d = (Drug*)[drugList objectAtIndex:i];
		NSMutableDictionary *drugInfo = [[NSMutableDictionary alloc] init];
		[d populateDictionary:drugInfo forSyncRequest:NO];
		[dictDrugList addObject:drugInfo];
	}
	[dict setObject:dictDrugList forKey:DrugListKey];
    
    // Set the accountCreated value
    NSNumber* accountCreatedNum = nil;
    if (accountCreated)
        accountCreatedNum = [NSNumber numberWithLongLong:(long long)[accountCreated timeIntervalSince1970]];
    
    if (accountCreatedNum)
        [dict setObject:accountCreatedNum forKey:AccountCreatedKey];
    
    [JSONConverter populateDictFromGroupList:dict groups:groups];
}

// Writes persistent part of data model to file. Returns whether successful.
- (BOOL)writeToFile:(NSString**)errorMessage
{	
	DebugLog(@"Writing file start");

	if (errorMessage)
		*errorMessage = nil;
	
	if (fileWritesPaused)
	{
		DebugLog(@"Writing file end: file writes paused");
		return YES;
	}
	
	// Create a mutable dictionary containing persistent objects to be written
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		
    if (wasDetached)
    {
        [dict setObject:[NSNumber numberWithInt:1] forKey:WasDetachedKey];
    }
    else
    {
        if (userID)
            [dict setObject:userID forKey:UserIDKey];
        else
        {
            DebugLog(@"*** Writing file without userId ***");
        }

        if (hardwareID)
            [dict setObject:hardwareID forKey:HardwareIDKey];
        else
        {
            DebugLog(@"*** Writing file without hardwareId ***");
        }

        // Write all persistent flags
        [persistentFlags populateDictionary:dict];
        
        [dict setObject:[NSNumber numberWithBool:syncNeeded] forKey:SyncNeededKey];
        [dict setObject:[NSNumber numberWithBool:wasExceedingMaxLocalNotifications] forKey:WasExceedingMaxLocalNotificationsKey];
        [dict setObject:[NSNumber numberWithBool:completedInitialSync] forKey:CompletedInitialSyncKey];
        
        // Save rest of data model
        [self populateDictionaryWithDataModel:dict];
    }
    
    BOOL result = [dataFile writeToFile:dict errorMessage:errorMessage];
    if (result)
    {
        DebugLog(@"Writing file end: %d drugs written", (int)[drugList count]);
        return YES;
    }
    else
    {
        DebugLog(@"Writing file end: error");
        return NO;
    }    
}

// Populates the data model elements from the given dictionary
- (void)populateDataModelWithDictionary:(NSMutableDictionary*)dict
{
    [globalSettings readFromDictionary:dict];
		
    NSNumber* accountCreatedNum = [dict objectForKey:AccountCreatedKey];
    if (accountCreatedNum && [accountCreatedNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        accountCreated = [NSDate dateWithTimeIntervalSince1970:[accountCreatedNum longLongValue]];
    }

    NSMutableArray* thisDeletedDrugIDs = [dict objectForKey:DeletedDrugIDsKey];
    if (thisDeletedDrugIDs)
    {
        [deletedDrugIDs removeAllObjects];
        [deletedDrugIDs addObjectsFromArray:thisDeletedDrugIDs];
    }

	// Create the drugs in the drugList
	[drugList removeAllObjects];
	NSArray* responseDrugList = [dict objectForKey:DrugListKey];
	if (responseDrugList)
	{
		for (int i = 0; i < [responseDrugList count]; i++)
		{
			NSMutableDictionary *drugInfo = [responseDrugList objectAtIndex:i];
			Drug* d = [[Drug alloc] initWithDictionary:drugInfo];
            
			[drugList addObject:d];
		}
	}
    
    [JSONConverter populateGroupListFromDict:dict groups:groups];
}

// Reads persistent part of data model from file. Returns whether successful.
- (BOOL)readFromFile:(NSString**)errorMessage
{
	DebugLog(@"Reading file start");

	if (errorMessage)
		*errorMessage = nil;
	
    NSMutableDictionary *dict = nil;
    NSString* localErrorMessage = nil;
    BOOL result = [dataFile readFromFile:&dict errorMessage:&localErrorMessage];
    if (result)
    {
        NSNumber* wasDetachedNum = [dict objectForKey:WasDetachedKey];
        wasDetached = (wasDetachedNum && [wasDetachedNum intValue] == 1);

        if (!wasDetached)
        {
            // Populate local elements of data model
            userID = [dict objectForKey:UserIDKey];
            hardwareID = [dict objectForKey:HardwareIDKey];
            
            // Read all persistent flags
            [persistentFlags readFromDictionary:dict];
            
            NSNumber* syncNeededNum = [dict objectForKey:SyncNeededKey];
            if (syncNeededNum)
                syncNeeded = [syncNeededNum boolValue];

            NSNumber* completedInitialSyncNum = [dict objectForKey:CompletedInitialSyncKey];
            if (completedInitialSyncNum)
                completedInitialSync = [completedInitialSyncNum boolValue];

            NSNumber* wasExceedingMaxLocalNotificationsNum = [dict objectForKey:WasExceedingMaxLocalNotificationsKey];
            if (wasExceedingMaxLocalNotificationsNum)
                wasExceedingMaxLocalNotifications = [wasExceedingMaxLocalNotificationsNum boolValue];

            [self populateDataModelWithDictionary:dict];
        }
        
        DebugLog(@"Reading file end: file exists, %d drugs found", (int)[drugList count]);

        return (!wasDetached && userID);
    }
    else
    {
        if (localErrorMessage)
        {
            if (errorMessage)
                *errorMessage = localErrorMessage;
            DebugLog(@"Reading file end: error");
        }
        else
        {
            DebugLog(@"Reading file end: no file exists");
        }

        return NO;
    }
}

// Returns drug with given ID
- (Drug*)findDrugWithId:(NSString*)drugId
{
	Drug* result = nil;
	int numDrugs = (int)[drugList count];
	for (int i = 0; i < numDrugs && result == nil; i++)
	{
		Drug* d = (Drug*)[drugList objectAtIndex:i];
		if ([drugId caseInsensitiveCompare:d.drugId] == NSOrderedSame)
			result = d;
	}
	return result;
}

// Returns drug IDs for given person ID
- (NSArray*)findDrugIdsForPersonId:(NSString*)personId
{
    NSMutableArray* drugIds = [[NSMutableArray alloc] init];
    
    for (Drug* d in drugList)
    {
        if ([personId caseInsensitiveCompare:d.personId] == NSOrderedSame)
            [drugIds addObject:d.drugId];
    }
    
    return drugIds;
}

// Called to temporarily pause and later resume notifications from being sent to delegates
- (void)pauseNotifications
{
	if (notificationsPaused)
		return;
    
	notificationsPaused = YES;
	didNotifyDuringPause = NO;
	[serverMethodCallsWhilePaused removeAllObjects];
    [deletedDrugIdsWhilePaused removeAllObjects];
    
    [PillNotificationManager getInstance].notificationsPaused = YES;
}

- (void)resumeNotifications
{
	if (!notificationsPaused)
		return;
	
	// Notify the delegates, if a notification was pending
	if (didNotifyDuringPause)
	{
		didNotifyDuringPause = NO;
        
        NSMutableDictionary* notificationDict = [[NSMutableDictionary alloc] init];
        [notificationDict setObject:[serverMethodCallsWhilePaused mutableCopy] forKey:DataModelDataRefreshNotificationServerMethodCallsKey];
        [notificationDict setObject:[deletedDrugIdsWhilePaused mutableCopy] forKey:DataModelDataRefreshNotificationDeletedDrugIdsKey];
        
        // Post a notification about this, in case anyone cares.
        [[NSNotificationCenter defaultCenter] postNotification:
         [NSNotification notificationWithName:DataModelDataRefreshNotification object:notificationDict]];
        
		[serverMethodCallsWhilePaused removeAllObjects];
        [deletedDrugIdsWhilePaused removeAllObjects];
	}
	notificationsPaused = NO;
    
    [PillNotificationManager getInstance].notificationsPaused = NO;
}

// Returns whether any group the user belongs to gives the premium edition
- (BOOL)doesAnyGroupGivePremium
{
    BOOL givesPremium = NO;
    
    int numGroups = (int)[self.groups count];
    for (int i = 0; i < numGroups && !givesPremium; i++)
    {
        Group* group = (Group*)[self.groups objectAtIndex:i];
        if (group.givesPremium)
            givesPremium = YES;
    }
    
    return givesPremium;
}

// Returns whether any group the user belongs to gives the subscription edition
- (BOOL)doesAnyGroupGiveSubscription
{
    BOOL givesSubscription = NO;
    
    int numGroups = (int)[self.groups count];
    for (int i = 0; i < numGroups && !givesSubscription; i++)
    {
        Group* group = (Group*)[self.groups objectAtIndex:i];
        if (group.givesSubscription)
            givesSubscription = YES;
    }
    
    return givesSubscription;
}

// Updates drug data with the response from a sync server call
- (BOOL)syncDrugData:(NSMutableDictionary*)wrappedResponse
       isInteractive:(BOOL)isInteractive
    shouldBeDetached:(BOOL*)shouldBeDetached
        errorMessage:(NSString**)errorMessage
{
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginDebugLogBatchUpdates];
    
    NSMutableDictionary* unwrappedResponse = [JSONConverter unwrapResponse:wrappedResponse];

    // Extract data model primitives from dictionary
    *errorMessage = nil;
    
    NSString* devErrorMessage = nil;
    [JSONConverter extractErrorsFromUnwrappedResponse:unwrappedResponse userErrorMessage:errorMessage devErrorMessage:&devErrorMessage shouldBeDetached:shouldBeDetached];
        
    if (*shouldBeDetached || *errorMessage != nil)
    {
        isSyncInProgress = NO;
        NSMutableString* logEntry = [NSMutableString stringWithString:@"sync end: detach or error"];
        if (*errorMessage != nil)
        {
            [logEntry appendFormat:@", error (%@ %@)", *errorMessage, devErrorMessage];
        }
        DebugLog(@"%@", logEntry);
        [historyManager endDebugLogBatchUpdates];

        return NO;
    }
    
    // Find the current time on the server
    NSDate* serverCurrentTime = nil;
    NSNumber* serverCurrentTimeNum = [unwrappedResponse objectForKey:CurrentTimeKey];
    if (serverCurrentTimeNum && [serverCurrentTimeNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        serverCurrentTime = [NSDate dateWithTimeIntervalSince1970:[serverCurrentTimeNum longLongValue]];
    }

    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    [localNotificationManager beginBatchUpdates];
    
    // Process groups now - so we can detect if we were added to a group that gives a subscription
    [JSONConverter populateGroupListFromDict:unwrappedResponse groups:groups];

    // Do a partial processing of global prefs - just enough to detect if the product status changed
    [globalSettings updateFromServerDictionary:unwrappedResponse isInteractive:isInteractive currentServerTime:serverCurrentTime limitToProductStatusOnly:YES];

    // Only continue if we have a subscription or haven't done it once
    if (globalSettings.accountType != AccountTypeSubscription && completedInitialSync)
    {
        [localNotificationManager endBatchUpdates:YES];
        isSyncInProgress = NO;
        
        DebugLog(@"sync end: limit to product status");
        [historyManager endDebugLogBatchUpdates];

        return YES;
    }

    if ([globalSettings updateFromServerDictionary:unwrappedResponse isInteractive:isInteractive currentServerTime:serverCurrentTime limitToProductStatusOnly:NO])
        [localNotificationManager refreshAllNotifications];

    NSNumber* accountCreatedNum = [unwrappedResponse objectForKey:AccountCreatedKey];
    if (accountCreatedNum && [accountCreatedNum longLongValue] > 0)
    {
        // Convert to NSDate from UNIX time
        accountCreated = [NSDate dateWithTimeIntervalSince1970:[accountCreatedNum longLongValue]];
    }
    
    // Handle drug deletions
    NSMutableArray* serverDeletedDrugIDs = [unwrappedResponse objectForKey:DeletedDrugIDsKey];
    if (serverDeletedDrugIDs)
    {
        NSMutableSet* serverDeletedDrugIDSet = [NSMutableSet setWithArray:serverDeletedDrugIDs];
        [serverDeletedDrugIDSet minusSet:deletedDrugIDs];
        NSArray* drugIDsToDelete = [serverDeletedDrugIDSet allObjects];
        for (NSString* deletedDrugID in drugIDsToDelete)
        {
            [localNotificationManager deletePill:deletedDrugID updateServer:NO respondTo:nil async:NO];
        }
    }
    
    [historyManager beginBatchUpdates];

	// Create the drugs in the drugList
	NSArray* serverDrugList = [unwrappedResponse objectForKey:DrugListKey];
	if (serverDrugList)
	{
		for (int i = 0; i < [serverDrugList count]; i++)
		{
			NSMutableDictionary *serverDrugInfo = [serverDrugList objectAtIndex:i];
			Drug* serverDrug = [[Drug alloc] initWithDictionary:serverDrugInfo];
            
            DebugLog(@"sync begin for drug (%@)", serverDrug.drugId);

            NSString* serverEditSource = [serverDrugInfo objectForKey:ServerEditSourceKey];
            NSDate* serverEditTime = nil;
            NSNumber* serverEditTimeNum = [serverDrugInfo objectForKey:ServerEditTimeKey];
            if (serverEditTimeNum && [serverEditTimeNum longLongValue] > 0)
            {
                // Convert to NSDate from UNIX time
                serverEditTime = [NSDate dateWithTimeIntervalSince1970:[serverEditTimeNum longLongValue]];
            }
            
            NSDate* localServerEditTime = nil;
            if (serverCurrentTime && serverEditTime)
            {
                NSTimeInterval serverInterval = [serverCurrentTime timeIntervalSinceDate:serverEditTime];
                localServerEditTime = [[NSDate date] dateByAddingTimeInterval:-serverInterval];
            }
            
            NSMutableDictionary* drugHistoryDict = [serverDrugInfo objectForKey:DrugHistoryKey];
            NSMutableArray* drugHistoryEntries = nil;
            if (drugHistoryDict)
                drugHistoryEntries = [drugHistoryDict objectForKey:DrugHistoryEntriesKey];

            Drug* localDrug = [self findDrugWithId:serverDrug.drugId];
            
            // See if this drug exists locally
            if (localDrug)
            {
                DebugLog(@"sync drug - found local drug");

                float remainingQuantityOffset = 0.0f;
                int refillQuantityOffset = 0;
                
                // Process deleted history
                NSMutableSet* historyGUIDsToDeleteSet = [serverDrug.deletedHistoryGUIDs mutableCopy];
                [historyGUIDsToDeleteSet minusSet:localDrug.deletedHistoryGUIDs];
                NSArray* historyGUIDsToDelete = [historyGUIDsToDeleteSet allObjects];
                
                BOOL historyEdited = NO;
                
                DebugLog(@"sync drug deleting history begin");

                for (NSString* guid in historyGUIDsToDelete)
                {
                    HistoryEvent* event = [historyManager getEventForGUID:guid errorMessage:nil];
                    if (event)
                    {
                        // Calculate impact to remaining/refill quantity of deleting this record
                        float thisRemainingQuantityOffset = 0.0f;
                        int thisRefillQuantityOffset = 0;
                        [historyManager getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&thisRemainingQuantityOffset refillQuantityOffset:&thisRefillQuantityOffset];
                        remainingQuantityOffset -= thisRemainingQuantityOffset;
                        refillQuantityOffset -= thisRefillQuantityOffset;
                        
                        historyEdited = YES;
                        [historyManager deleteEvent:event notifyServer:NO];
                    }
                    else
                        [localDrug.deletedHistoryGUIDs addObject:guid]; // just in case this event was added and deleted before our sync, add the guid to our deleted list
                }
                
                DebugLog(@"sync drug deleting history end - deleted %ld events", (long)[historyGUIDsToDelete count]);

                if (drugHistoryEntries)
                {
                    DebugLog(@"sync drug processing history begin");

                    for (NSMutableDictionary* historyDict in drugHistoryEntries)
                    {
                        NSString* guid = nil;
                        NSDate* creation = nil;
                        NSString* eventDescription = nil;
                        NSString* operation = nil;
                        NSString* operationData = nil;
                        NSDate* scheduleDate = nil;
                        NSDictionary* preferences = nil;
                        [JSONConverter extractHistoryEventDataFromHistoryEvent:historyDict
                                                                          guid:&guid
                                                                  creationDate:&creation
                                                              eventDescription:&eventDescription
                                                                     operation:&operation
                                                                 operationData:&operationData
                                                                  scheduleDate:&scheduleDate
                                                               preferencesDict:&preferences];
                        
                        // See if this event exists. If so, mark it as synched; otherwise, add it.
                        HistoryEvent* event = [historyManager getEventForGUID:guid errorMessage:nil];
                        if (event)
                            [historyManager markHistoryEventAsSynched:event];
                        else
                        {
                            historyEdited = YES;
                            
                            HistoryEvent* event =
                            [historyManager addHistoryEvent:serverDrug.drugId
                                                       guid:guid
                                               creationDate:creation
                                           eventDescription:eventDescription
                                                  operation:operation
                                              operationData:operationData
                                               scheduleDate:scheduleDate
                                            preferencesDict:preferences
                                          isManuallyCreated:NO
                                               notifyServer:NO
                                               errorMessage:nil];
                            
                            // Calculate impact to remaining/refill quantity of deleting this record
                            float thisRemainingQuantityOffset = 0.0f;
                            int thisRefillQuantityOffset = 0;
                            [historyManager getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&thisRemainingQuantityOffset refillQuantityOffset:&thisRefillQuantityOffset];
                            remainingQuantityOffset += thisRemainingQuantityOffset;
                            refillQuantityOffset += thisRefillQuantityOffset;
                        }
                    }
                    
                    DebugLog(@"sync drug processing history end - processed %ld events", (long)[drugHistoryEntries count]);
                }
                
                BOOL editedDrug = NO;

                // See if the edit GUIDs differ
                if (localDrug.clientEditGUID && serverDrug.serverEditGUID &&
                    ![localDrug.clientEditGUID isEqualToString:serverDrug.serverEditGUID])
                {
                    // See if the edit sources differ
                    if (serverEditSource && localServerEditTime && localDrug.clientEditTime &&
                        ![serverEditSource isEqualToString:self.hardwareID])
                    {
                        // See if the server's edit occurred later than ours
                        if ([localServerEditTime timeIntervalSinceDate:localDrug.clientEditTime] > 0)
                        {
                            DebugLog(@"sync drug - updating local drug with server copy");

                            // Detect if a new drug image needs to be downloaded
                            if (serverDrug.drugImageGUID && [serverDrug.drugImageGUID length] > 0 &&
                                ![[DrugImageManager sharedManager] doesImageExistForImageGUID:serverDrug.drugImageGUID])
                            {
                                [[DrugImageManager sharedManager] downloadImageWithImageGUID:serverDrug.drugImageGUID];
                            }

                            // Detect if the old drug image needs to be removed
                            if (localDrug.drugImageGUID && [localDrug.drugImageGUID length] > 0 &&
                                (!serverDrug.drugImageGUID || [serverDrug.drugImageGUID length] == 0 || ![serverDrug.drugImageGUID isEqualToString:localDrug.drugImageGUID]))
                            {
                                [[DrugImageManager sharedManager] removeImageForImageGUID:localDrug.drugImageGUID shouldRemoveServerImage:NO];
                            }
                            
                            DrugDosage* updatedDosage = [serverDrug.dosage mutableCopy];
                            
                            // Update remaining quantity and refills remaining, if they were changed by the history
                            float remainingQuantity = 0.0f;
                            [localDrug.dosage getValueForRemainingQuantity:&remainingQuantity];
                            if (fabsf(remainingQuantityOffset) > epsilon)
                                remainingQuantity += remainingQuantityOffset;
                            [updatedDosage setValueForRemainingQuantity:remainingQuantity];

                            int refillQuantity = [localDrug.dosage getRefillsRemaining];
                            if (abs(refillQuantityOffset) > 0)
                                refillQuantity += refillQuantityOffset;
                            [updatedDosage setRefillsRemaining:refillQuantity];
                            
                            [localNotificationManager editPill:serverDrug.drugId
                                                      drugName:serverDrug.name
                                                     imageGUID:serverDrug.drugImageGUID
                                                      personId:serverDrug.personId
                                                    directions:serverDrug.directions
                                                 doctorContact:serverDrug.doctorContact
                                               pharmacyContact:serverDrug.pharmacyContact
                                               prescriptionNum:serverDrug.prescriptionNum
                                                  drugReminder:serverDrug.reminder
                                                    drugDosage:updatedDosage
                                                         notes:serverDrug.notes
                                          undoHistoryEventGUID:serverDrug.undoHistoryEventGUID
                                                  updateServer:NO
                                                     respondTo:nil
                                                         async:NO];

                            [localDrug refreshDrugInternalState];

                            localDrug.clientEditGUID = serverDrug.serverEditGUID;
                            localDrug.clientEditTime = localServerEditTime;
                            editedDrug = YES;
                        }
                    }
                }
                
                if (historyEdited)
                {
                    // If the history was edited but we haven't already edited the pill, edit the pill silently to respond to history changes
                    if (!editedDrug)
                    {
                        DebugLog(@"sync drug - editing drug due to history updates");

                        DrugDosage* updatedDosage = [localDrug.dosage mutableCopy];

                        // Update remaining quantity and refills remaining, if they were changed by the history
                        if (fabsf(remainingQuantityOffset) > epsilon)
                        {
                            float remainingQuantity = 0.0f;
                            [updatedDosage getValueForRemainingQuantity:&remainingQuantity];
                            [updatedDosage setValueForRemainingQuantity:remainingQuantity + remainingQuantityOffset];
                        }
                        
                        if (abs(refillQuantityOffset) > 0)
                        {
                            int refillQuantity = [updatedDosage getRefillsRemaining];
                            [updatedDosage setRefillsRemaining:refillQuantity + refillQuantityOffset];
                        }

                        [localNotificationManager editPill:localDrug.drugId
                                                  drugName:localDrug.name
                                                 imageGUID:localDrug.drugImageGUID
                                                  personId:localDrug.personId
                                                directions:localDrug.directions
                                             doctorContact:localDrug.doctorContact
                                           pharmacyContact:localDrug.pharmacyContact
                                           prescriptionNum:localDrug.prescriptionNum
                                              drugReminder:localDrug.reminder
                                                drugDosage:updatedDosage
                                                     notes:localDrug.notes
                                      undoHistoryEventGUID:localDrug.undoHistoryEventGUID
                                              updateServer:NO
                                                 respondTo:nil
                                                     async:NO];
                        
                        [localDrug refreshDrugInternalState];
                    }
                }
                
                localDrug.serverEditGUID = serverDrug.serverEditGUID;
                localDrug.lastHistoryToken = serverDrug.lastHistoryToken;
            }
            else // Must create a new drug
            {
                DebugLog(@"sync drug - creating new drug");

                if (drugHistoryEntries)
                {
                    DebugLog(@"sync drug adding history begin");

                    for (NSMutableDictionary* historyDict in drugHistoryEntries)
                    {
                        NSString* guid = nil;
                        NSDate* creation = nil;
                        NSString* eventDescription = nil;
                        NSString* operation = nil;
                        NSString* operationData = nil;
                        NSDate* scheduleDate = nil;
                        NSDictionary* preferences = nil;
                        [JSONConverter extractHistoryEventDataFromHistoryEvent:historyDict
                                                                          guid:&guid
                                                                  creationDate:&creation
                                                              eventDescription:&eventDescription
                                                                     operation:&operation
                                                                 operationData:&operationData
                                                                  scheduleDate:&scheduleDate
                                                               preferencesDict:&preferences];
                        [historyManager addHistoryEvent:serverDrug.drugId
                                                   guid:guid
                                           creationDate:creation
                                       eventDescription:eventDescription
                                              operation:operation
                                          operationData:operationData
                                           scheduleDate:scheduleDate
                                        preferencesDict:preferences
                                      isManuallyCreated:NO
                                           notifyServer:NO
                                           errorMessage:nil];
                    }
                    
                    DebugLog(@"sync drug adding history end");
                }

                // Detect if a new drug image needs to be downloaded
                if (serverDrug.drugImageGUID && [serverDrug.drugImageGUID length] > 0 &&
                    ![[DrugImageManager sharedManager] doesImageExistForImageGUID:serverDrug.drugImageGUID])
                {
                    [[DrugImageManager sharedManager] downloadImageWithImageGUID:serverDrug.drugImageGUID];
                }
                
                Drug* localDrug = [[Drug alloc] init:serverDrug.drugId
                                        name:serverDrug.name
                               drugImageGUID:serverDrug.drugImageGUID
                                     created:(serverDrug.created ? serverDrug.created : [NSDate date])
                                    personId:serverDrug.personId
                                  directions:serverDrug.directions
                               doctorContact:serverDrug.doctorContact
                             pharmacyContact:serverDrug.pharmacyContact
                             prescriptionNum:serverDrug.prescriptionNum
                                    reminder:serverDrug.reminder
                                      dosage:serverDrug.dosage
                                       notes:serverDrug.notes
                              clientEditGUID:serverDrug.serverEditGUID
                              clientEditTime:localServerEditTime
                              serverEditGUID:serverDrug.serverEditGUID
                            lastHistoryToken:serverDrug.lastHistoryToken
                         deletedHistoryGUIDs:serverDrug.deletedHistoryGUIDs
                        undoHistoryEventGUID:serverDrug.undoHistoryEventGUID
                                otherDrugPreferences:serverDrug.otherDrugPreferences];

                [drugList addObject:localDrug];
                
                [historyManager updateRemainingRefillQuantityFromCompleteHistoryForDrug:localDrug.drugId];
                
                [localNotificationManager editPill:localDrug.drugId
                                          drugName:localDrug.name
                                         imageGUID:localDrug.drugImageGUID
                                          personId:localDrug.personId
                                        directions:localDrug.directions
                                     doctorContact:localDrug.doctorContact
                                   pharmacyContact:localDrug.pharmacyContact
                                   prescriptionNum:localDrug.prescriptionNum
                                      drugReminder:localDrug.reminder
                                        drugDosage:localDrug.dosage
                                             notes:localDrug.notes
                              undoHistoryEventGUID:localDrug.undoHistoryEventGUID
                                      updateServer:NO
                                         respondTo:nil
                                             async:NO];
                
                [localDrug refreshDrugInternalState];
            }
            
            DebugLog(@"sync end for drug (%@)", serverDrug.drugId);
		}
	}
    
    [historyManager endBatchUpdates:YES];    
    
    [localNotificationManager getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    if (!completedInitialSync)
        completedInitialSync = YES;

    [localNotificationManager endBatchUpdates:YES];
    
    isSyncInProgress = NO;
    
    DebugLog(@"sync end");
    [historyManager endDebugLogBatchUpdates];

    return YES;
}

// Returns whether any dose will be due between now and the given date
- (BOOL)willDoseBeDueBefore:(NSDate*)date
{    
    for (Drug* d in drugList)
    {
        if (d.reminder.overdueReminder ||
            (d.reminder.nextReminder && date && [d.reminder.nextReminder timeIntervalSinceDate:date] < 0))
        {
            return YES;
        }
    }
    
    return NO;
}

// Updates any dependent state after the data model has been changed locally
- (void)updateAfterLocalDataModelChange:(NSSet*)serverMethodCalls deletedDrugIDs:(NSSet*)deletedDrugs
{
	DebugLog(@"update after local data model change start: %d drugs exist", (int)[drugList count]);

	// Notify the delegate if we aren't paused
	if (notificationsPaused)
	{
        [serverMethodCallsWhilePaused addObjectsFromArray:[serverMethodCalls allObjects]];
        [deletedDrugIdsWhilePaused addObjectsFromArray:[deletedDrugs allObjects]];

		didNotifyDuringPause = YES;
	}
	else
    {
        NSMutableDictionary* notificationDict = [[NSMutableDictionary alloc] init];
        [notificationDict setObject:[NSMutableSet setWithSet:serverMethodCalls] forKey:DataModelDataRefreshNotificationServerMethodCallsKey];
        [notificationDict setObject:[NSMutableSet setWithSet:deletedDrugs] forKey:DataModelDataRefreshNotificationDeletedDrugIdsKey];
        
        // Post a notification about this, in case anyone cares.
        [[NSNotificationCenter defaultCenter] postNotification:
         [NSNotification notificationWithName:DataModelDataRefreshNotification object:notificationDict]];
    }
    
	DebugLog(@"update after local data model change end: %d drugs exist", (int)[drugList count]);
}

// Returns number of overdue drugs
- (int)numOverdueDrugs
{
	int numOverdue = 0;
	for (int i = 0; i < [drugList count]; i++)
	{
		Drug* d = (Drug*)[drugList objectAtIndex:i];
		if (d.reminder.overdueReminder != nil)
			numOverdue++;
	}
	return numOverdue;
}

// Returns the array of overdue drugs Ids
- (NSArray*)getOverdueDrugIds
{
	NSMutableArray* overdueDrugIds = [[NSMutableArray alloc] init];
	
	// Populate the array of overdue drugs
	int numOverdueDrugs = [self numOverdueDrugs];
	for (int i = 0; i < numOverdueDrugs; i++)
	{
		Drug* overdueDrug = [self findOverdueDrug:i];
		[overdueDrugIds addObject:[NSString stringWithString:overdueDrug.drugId]];
	}
	
	return overdueDrugIds;
}

// Returns the ith 0-based overdue drug
- (Drug*)findOverdueDrug:(int)i
{
	Drug* overdueDrug = nil;
	int overdueDrugNum = 0;
	for (int j = 0; j < [drugList count] && !overdueDrug; j++)
	{
		Drug* d = (Drug*)[drugList objectAtIndex:j];
		if (d.reminder.overdueReminder != nil)
		{
			if (i == overdueDrugNum)
				overdueDrug = d;
			overdueDrugNum++;
		}
	}
	return overdueDrug;
}


// Return the bedtime as dates
- (void)getBedtimeAsDates:(NSDate**)bedtimeStartDate bedtimeEnd:(NSDate**)bedtimeEndDate
{
	[DataModel convertBedtimetoDates:globalSettings.bedtimeStart
							bedtimeEnd:globalSettings.bedtimeEnd
					  bedtimeStartDate:bedtimeStartDate
						bedtimeEndDate:bedtimeEndDate];
}

// Returns the date of the next (upcoming) bedtime end
- (NSDate*) getNextBedtimeEndDate
{
	NSDate* bedtimeStartDate = nil;
	NSDate* bedtimeEndDate = nil;
	[self getBedtimeAsDates:&bedtimeStartDate bedtimeEnd:&bedtimeEndDate];
	
	if (!bedtimeEndDate)
		return nil;
	
	NSDate* now = [NSDate date];
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
						 NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents* todayTimeComponents = [cal components:unitFlags fromDate:now];
	NSDateComponents* bedtimeEndDateComponents = [cal components:unitFlags fromDate:bedtimeEndDate];
	
	[todayTimeComponents setHour:[bedtimeEndDateComponents hour]];
	[todayTimeComponents setMinute:[bedtimeEndDateComponents minute]];
	[todayTimeComponents setSecond:0];
	
	NSDate* nextBedtimeEndDate = [cal dateFromComponents:todayTimeComponents];
	if ([nextBedtimeEndDate timeIntervalSinceDate:now] < 0)
		nextBedtimeEndDate = [DosecastUtil addDaysToDate:nextBedtimeEndDate numDays:1];
	return nextBedtimeEndDate;
}

// Returns the date of the bedtime on the given day
- (NSDate*)getBedtimeEndDateOnDay:(NSDate*)day
{
	NSDate* bedtimeStartDate = nil;
	NSDate* bedtimeEndDate = nil;
	[self getBedtimeAsDates:&bedtimeStartDate bedtimeEnd:&bedtimeEndDate];
	
	if (!bedtimeEndDate)
		return nil;
	
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
						 NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents* dayTimeComponents = [cal components:unitFlags fromDate:day];
	NSDateComponents* bedtimeEndDateComponents = [cal components:unitFlags fromDate:bedtimeEndDate];
	
	[dayTimeComponents setHour:[bedtimeEndDateComponents hour]];
	[dayTimeComponents setMinute:[bedtimeEndDateComponents minute]];
	[dayTimeComponents setSecond:0];
	
	return [cal dateFromComponents:dayTimeComponents];	
}

// Convert the given bedtime to dates
+ (void)convertBedtimetoDates:(int)bedtimeStart
				   bedtimeEnd:(int)bedtimeEnd
			 bedtimeStartDate:(NSDate**)bedtimeStartDate
			   bedtimeEndDate:(NSDate**)bedtimeEndDate
{
	*bedtimeStartDate = nil;
	*bedtimeEndDate = nil;
	if (bedtimeStart != -1)
		*bedtimeStartDate = [DosecastUtil get24hrTimeAsDate:bedtimeStart];
	if (bedtimeEnd != -1)
		*bedtimeEndDate = [DosecastUtil get24hrTimeAsDate:bedtimeEnd];
}

// Convert the given dates to bedtime
+ (void)convertDatestoBedtime:(NSDate*)bedtimeStartDate
			   bedtimeEndDate:(NSDate*)bedtimeEndDate
		     	 bedtimeStart:(int*)bedtimeStart
			       bedtimeEnd:(int*)bedtimeEnd
{
	*bedtimeStart = -1;
	*bedtimeEnd = -1;
	if (bedtimeStartDate)
		*bedtimeStart = [DosecastUtil getDateAs24hrTime:bedtimeStartDate];
	if (bedtimeEndDate)
		*bedtimeEnd = [DosecastUtil getDateAs24hrTime:bedtimeEndDate];
}

// Returns whether the given time occurs during bedtime
- (BOOL)dateOccursDuringBedtime:(NSDate*)date
{
    return [DataModel dateOccursDuringBedtime:date bedtimeStart:globalSettings.bedtimeStart bedtimeEnd:globalSettings.bedtimeEnd];
}

// Returns whether the given date occurs during bedtime
+ (BOOL)dateOccursDuringBedtime:(NSDate*)date bedtimeStart:(int)bedtimeStart bedtimeEnd:(int)bedtimeEnd
{
	if (!date || bedtimeEnd < 0 || bedtimeStart < 0)
		return NO;
			
	int dateInt = [DosecastUtil getDateAs24hrTime:date];
	return ((bedtimeStart > bedtimeEnd && (dateInt >= bedtimeStart || dateInt <= bedtimeEnd)) ||
			(bedtimeStart <= bedtimeEnd && dateInt >= bedtimeStart && dateInt <= bedtimeEnd));
}

// Returns user ID abbreviation
- (NSString*)userIDAbbrev {
	return [NSString stringWithFormat:@"%@-%@", [userID substringWithRange:NSMakeRange(0, 4)], [userID substringWithRange:NSMakeRange(4, 4)]];
}

// Returns whether a timezone change occurred and needs to be resolved
- (BOOL)needsToResolveTimezoneChange
{	
	return (globalSettings.lastTimezoneGMTOffset && globalSettings.lastTimezoneName &&
			[globalSettings.lastTimezoneGMTOffset longValue] != [[DosecastUtil getCurrTimezoneGMTOffset] longValue]);
}

// Return key diagnostics as a string
- (NSString*)getKeyDiagnosticsString
{
	NSMutableString* diagnostics = [NSMutableString stringWithString:@""];
    
	[diagnostics appendString:NSLocalizedStringWithDefaultValue(@"ViewProblemReportDiagnosticsHeader", @"Dosecast", [DosecastUtil getResourceBundle],
																@"Please provide a description of the problem (in English) and send this email with the diagnostics below:\
																\
																\
																\
																\
																\
																----------------------\
																Diagnostics:\
																\
																", @"The header of the diagnostics string sent in a problem report"])];
		
	[diagnostics appendFormat:@"Client version: %@\n", self.clientVersion];
	[diagnostics appendFormat:@"API version: %@\n", self.globalSettings.apiVersion.versionString];
	[diagnostics appendFormat:@"Device name: %@\n", [DosecastUtil getPlatformName]];
    [diagnostics appendFormat:@"Hardware ID: %@\n", self.hardwareID];
    [diagnostics appendFormat:@"OS version: %@\n", [DosecastUtil getOSVersionString]];
	[diagnostics appendFormat:@"Local timezone: %@\n", [DosecastUtil getCurrTimezoneName]];
	[diagnostics appendFormat:@"Local GMT offset: %d seconds\n", [[DosecastUtil getCurrTimezoneGMTOffset] intValue]];
	if ([apiFlags getFlag:DosecastAPIShowAccount])
    {
        NSString* accountTypeStr = nil;
        AccountType type = globalSettings.accountType;
        if (type == AccountTypeDemo)
            accountTypeStr = @"Free";
        else if (type == AccountTypePremium)
            accountTypeStr = @"Premium";
        else
            accountTypeStr = @"Pro with CloudSync";
		[diagnostics appendFormat:@"Edition: %@\n", accountTypeStr];
        if (type == AccountTypeSubscription && globalSettings.subscriptionExpires && [globalSettings.subscriptionExpires timeIntervalSinceNow] > 0)
        {
            NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [diagnostics appendFormat:@"Subscription expires on: %@\n", [dateFormatter stringFromDate:globalSettings.subscriptionExpires]];
        }
        else if (type != AccountTypeSubscription && globalSettings.subscriptionExpires && [globalSettings.subscriptionExpires timeIntervalSinceNow] < 0)
        {
            NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [diagnostics appendFormat:@"Subscription expired on: %@\n", [dateFormatter stringFromDate:globalSettings.subscriptionExpires]];
        }
    }
    if ([apiFlags getFlag:DosecastAPIMultiPersonSupport])
    {
        NSString* sortOrder = nil;
        if (globalSettings.drugSortOrder == DrugSortOrderByNextDoseTime)
            sortOrder = @"Time of next dose";
        else if (globalSettings.drugSortOrder == DrugSortOrderByPerson)
            sortOrder = @"Person";
        else if (globalSettings.drugSortOrder == DrugSortOrderByDrugName)
            sortOrder = @"Drug name";
        else // DrugSortOrderByDrugType
            sortOrder = @"Drug type";

		[diagnostics appendFormat:@"Sort drugs by: %@\n", sortOrder];
    }
    [diagnostics appendFormat:@"Show archived drugs: %@\n", (globalSettings.archivedDrugsDisplayed ? @"On" : @"Off")];
    [diagnostics appendFormat:@"Show drug images: %@\n", (globalSettings.drugImagesDisplayed ? @"On" : @"Off")];
	BOOL bedtimeDefined = (globalSettings.bedtimeStart != -1 || globalSettings.bedtimeEnd != -1);
	[diagnostics appendFormat:@"Interval reminders during bedtime: %@\n", (bedtimeDefined ? @"Off" : @"On")];
	if (bedtimeDefined)
	{
		NSDate* bedtimeStartDate = nil;
		NSDate* bedtimeEndDate = nil;
		[self getBedtimeAsDates:&bedtimeStartDate bedtimeEnd:&bedtimeEndDate];
		NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];	
		[diagnostics appendFormat:@"Bedtime: %@ - %@\n",[dateFormatter stringFromDate:bedtimeStartDate], [dateFormatter stringFromDate:bedtimeEndDate]];				
	}
	[diagnostics appendFormat:@"Prevent early drug doses: %@\n", (globalSettings.preventEarlyDrugDoses ? @"On" : @"Off")];
	NSRange dotRange = [globalSettings.reminderSoundFilename rangeOfString:@"." options:NSBackwardsSearch];
	[diagnostics appendFormat:@"Reminder sound: %@\n", [globalSettings.reminderSoundFilename substringToIndex:dotRange.location]];
    [diagnostics appendFormat:@"Secondary reminder after: %d secs\n", globalSettings.secondaryReminderPeriodSecs];
    [diagnostics appendFormat:@"Privacy mode: %@\n", (globalSettings.drugNamesDisplayedInNotifications ? @"Off" : @"On")];
	[diagnostics appendFormat:@"Dose history stored: %d day(s)\n", globalSettings.doseHistoryDays];
    [diagnostics appendFormat:@"Show postpone events: %@\n", (globalSettings.postponesDisplayed ? @"On" : @"Off")];
    [diagnostics appendFormat:@"Flag doses taken late: %@\n", ((globalSettings.lateDosePeriodSecs > 0) ? @"On" : @"Off")];
    if (globalSettings.lateDosePeriodSecs > 0)
        [diagnostics appendFormat:@"Late after: %d secs\n", globalSettings.lateDosePeriodSecs];
    NSMutableString* groupList = [NSMutableString stringWithString:@""];
    for (Group* g in groups)
    {
        if ([groupList length] > 0)
            [groupList appendString:@", "];
        [groupList appendString:g.displayName];
    }
    if ([groupList length] == 0)
        [groupList appendString:@"None"];
    [diagnostics appendFormat:@"Groups: %@\n", groupList];
    if ([groups count] > 0)
    {
        [diagnostics appendFormat:@"Any group give premium: %@\n", ([self doesAnyGroupGivePremium] ? @"Yes" : @"No")];
        [diagnostics appendFormat:@"Any group give subscription: %@\n", ([self doesAnyGroupGiveSubscription] ? @"Yes" : @"No")];
    }
    
	return diagnostics;
}

// For future times that lie across a daylight savings boundary, unapply the daylight savings period
- (void) unapplyDaylightSavingsToFutureTimesAcrossDaylightSavingsBoundary
{
	int numDrugs = (int)[drugList count];
	for (int i = 0; i < numDrugs; i++)
	{
		Drug* d = [drugList objectAtIndex:i];
        
		[d.reminder unapplyDaylightSavingsToFutureTimesAcrossDaylightSavingsBoundary];
	}	
}

// Return the drug list as a string
- (NSString*)getDrugListHTMLString
{
    NSMutableArray* localDrugList = [[NSMutableArray alloc] init];
    NSMutableArray* archivedDrugList = [[NSMutableArray alloc] init];
    
    // Filter out archived drugs if they are not displayed
    for (Drug* d in drugList)
    {
        if (!d.reminder.invisible && (globalSettings.archivedDrugsDisplayed || !d.reminder.archived))
        {
            if (d.reminder.archived)
                [archivedDrugList addObject:d];
            else
                [localDrugList addObject:d];
        }
    }
    
    // Append archived drugs at the end
    [localDrugList addObjectsFromArray:archivedDrugList];
    
    int numDrugs = (int)[localDrugList count];

	NSMutableString* htmlStr = [NSMutableString stringWithFormat:@""];
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSString* headerMessage = nil;
    if (numDrugs == 0)
		headerMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugListHeaderNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No drugs are currently being taken in %@.", @"The header line in the body of the drug list email when there are no drugs"]), [DosecastUtil getProductAppName]];
	else
		headerMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugListHeaderDrugs", @"Dosecast", [DosecastUtil getResourceBundle], @"Here is the list of drugs being taken in %@:", @"The header line in the body of the drug list email when there are drugs"]), [DosecastUtil getProductAppName]];

    NSString* htmlHeader = NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML header of the drug list email");
    [htmlStr appendString:[htmlHeader stringByReplacingOccurrencesOfString:@"%MESSAGE%" withString:headerMessage]];
    
    if (numDrugs > 0)
    {
        // See if any non-database drug dosages exist
        BOOL nonDatabaseDrugDosagesExist = NO;
        for (int i = 0; i < numDrugs && !nonDatabaseDrugDosagesExist; i++)
        {
            Drug* d = [localDrugList objectAtIndex:i];
            
            if (![d.dosage isKindOfClass:[DatabaseDrugDosage class]])
                nonDatabaseDrugDosagesExist = YES;
        }
        
        if (nonDatabaseDrugDosagesExist)
            [htmlStr appendString:NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLTableHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML table header in the drug list email")];
        else
            [htmlStr appendString:NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLTableHeaderDatabase", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML table header for the drug database in the drug list email")];

        for (int i = 0; i < numDrugs; i++)
        {
            Drug* d = [localDrugList objectAtIndex:i];
            
            NSMutableString* htmlRow = nil;
            if (nonDatabaseDrugDosagesExist)
                htmlRow = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLTableRow", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML table row in the drug list email")];
            else
                htmlRow = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLTableRowDatabase", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML table row for the drug database in the drug list email")];
            
            [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%NAME%" withString:d.name]];
            
            [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%TYPE%" withString:[d.dosage getTypeName]]];
            
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            
            NSString* start = [NSString stringWithFormat:@"%@ %@",
                               [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentStartDate], [dateFormatter stringFromDate:d.reminder.treatmentStartDate]];
            [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%START%" withString:start]];
            
            NSString* end = @"";
            if (d.reminder.treatmentEndDate != nil)
            {
                end = [NSString stringWithFormat:@"%@ %@",
                       [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentEndDate], [dateFormatter stringFromDate:d.reminder.treatmentEndDate]];
            }
            else
                end = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
            [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%END%" withString:end]];
            
            [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%DIRECTIONS%" withString:d.directions]];

            if (nonDatabaseDrugDosagesExist)
            {
                [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%DOSAGE%" withString:[d.dosage getDescriptionForDrugDose:nil]]];
            }
            else
            {
                NSString* route = [d.dosage getValueForDosePicklist:DatabaseRoutePicklistName];
                if (!route)
                    route = @"";
                [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%ROUTE%" withString:route]];

                NSString* amount = @"";
                if ([d.dosage isValidValueForDoseQuantity:DatabaseAmountQuantityName])
                    amount = [d.dosage getDescriptionForDoseQuantity:DatabaseAmountQuantityName maxNumDecimals:2];
                [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%AMOUNT%" withString:amount]];
                
                NSString* strength = @"";
                if ([d.dosage isValidValueForDoseQuantity:DatabaseStrengthQuantityName])
                    strength = [d.dosage getDescriptionForDoseQuantity:DatabaseStrengthQuantityName maxNumDecimals:2];
                [htmlRow setString:[htmlRow stringByReplacingOccurrencesOfString:@"%STRENGTH%" withString:strength]];
            }
            
            [htmlStr appendString:htmlRow];
        }
              
        [htmlStr appendString:NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLTableFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML table footer in the drug list email")];
    }
    
    [htmlStr appendString:
     [NSLocalizedStringWithDefaultValue(@"EmailDrugListHTMLFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The HTML footer in the drug list email") stringByReplacingOccurrencesOfString:@"%APPNAME%" withString:[DosecastUtil getProductAppName]]];
    	
	return htmlStr;
}

// Returns whether the user is registered
- (BOOL) userRegistered
{
    if (delegate && [delegate respondsToSelector:@selector(userRegistered)])
        return [delegate userRegistered];
    else
        return NO;
}

// Return the drug history as a string.
- (NSString*)getDrugHistoryStringForDrug:(NSString*)drugId
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    HistoryManager* historyManager = [HistoryManager getInstance];
	NSMutableString* drugHistoryString = [NSMutableString stringWithFormat:@""];
    NSArray* historyDateEventsList = [historyManager getHistoryDateEventsForDrugIds:[NSArray arrayWithObject:drugId] includePostponeEvents:globalSettings.postponesDisplayed errorMessage:nil];

	int numHistoryEvents = (int)[historyDateEventsList count];
    
	NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
	NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
	NSString* historyDurationUnit = nil;
    
	if ([DosecastUtil shouldUseSingularForInteger:globalSettings.doseHistoryDays])
		historyDurationUnit = daySingular;
	else
		historyDurationUnit = dayPlural;
    
    Drug* d = [self findDrugWithId:drugId];

    NSString* personId = d.personId;
    if (!personId)
        personId = @"";

    NSString* personName = nil;
    if (!personId || [personId length] == 0)
        personName = [NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]) lowercaseString];
    else
        personName = [globalSettings.personNames nameForGuid:personId];
    
    if (numHistoryEvents > 0)
    {
        NSMutableString* headerForEvents = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ dose history for %@ over the last %d %@:", @"The header in the body of the email containing the history for a particular drug when there are some events"])];
        [headerForEvents appendString:@"\n\n"];
        [drugHistoryString appendFormat:headerForEvents, d.name, personName, globalSettings.doseHistoryDays, historyDurationUnit];
    }
    else
    {
        NSString* headerForNoEvents = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No %@ dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for a particular drug when there are no events"])];
        [drugHistoryString appendFormat:headerForNoEvents, d.name, personName, globalSettings.doseHistoryDays, historyDurationUnit];
    }
	
	for (int i = 0; i < numHistoryEvents; i++)
	{
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:i];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];			
		[drugHistoryString appendFormat:@"%@:\n", [dateFormatter stringFromDate:events.creationDate]];
		
		int numEvents = (int)[events.editableHistoryEvents count];
		for (int j = 0; j < numEvents; j++)
		{
			EditableHistoryEvent* event = [events.editableHistoryEvents objectAtIndex:j];
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            
            [drugHistoryString appendFormat:@"    %@", [dateFormatter stringFromDate:event.creationDate]];
            if (event.late && [event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
                [drugHistoryString appendFormat:@" (%@ %@)", [event latePeriodDescription], [NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryLateDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Late", @"The label appearing under a late dose in the Drug History view"]) lowercaseString]];
			[drugHistoryString appendFormat:@"- %@\n", [historyManager getEventDescriptionForHistoryEvent:event.drugId
                                                                                                operation:event.operation
                                                                                            operationData:event.operationData
                                                                                               dosageType:event.dosageType
                                                                                          preferencesDict:[event createHistoryEventPreferencesDict]
                                                                                   legacyEventDescription:event.eventDescription
                                                                                          displayDrugName:YES]];
		}
	}	
    
    return drugHistoryString;
}

// Return the drug history as a string.
- (NSString*)getDrugHistoryStringForPersonId:(NSString*)personId
{
    if (!personId)
        personId = @"";
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    HistoryManager* historyManager = [HistoryManager getInstance];
	NSMutableString* drugHistoryString = [NSMutableString stringWithFormat:@""];
    
    NSArray* drugIds = [self findDrugIdsForPersonId:personId];

    NSArray* historyDateEventsList = [historyManager getHistoryDateEventsForDrugIds:drugIds includePostponeEvents:globalSettings.postponesDisplayed errorMessage:nil];
    
	int numHistoryEvents = (int)[historyDateEventsList count];
    
	NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
	NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
	NSString* historyDurationUnit = nil;
    
	if ([DosecastUtil shouldUseSingularForInteger:globalSettings.doseHistoryDays])
		historyDurationUnit = daySingular;
	else
		historyDurationUnit = dayPlural;
    
    NSString* personName = nil;
    if (!personId || [personId length] == 0)
        personName = [NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]) lowercaseString];
    else
        personName = [globalSettings.personNames nameForGuid:personId];
    
    if (numHistoryEvents > 0)
    {
        NSMutableString* headerForEvents = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose history for %@ over the last %d %@:", @"The header in the body of the email containing the history for all drugs when there are some events"]), personName, globalSettings.doseHistoryDays, historyDurationUnit];
        [headerForEvents appendString:@"\n\n"];
        [drugHistoryString appendString:headerForEvents];
    }
    else
    {
        NSString* headerForNoEvents = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for all drugs when there are no events"]), personName, globalSettings.doseHistoryDays, historyDurationUnit];
        [drugHistoryString appendString:headerForNoEvents];
    }
	
	for (int i = 0; i < numHistoryEvents; i++)
	{
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:i];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[drugHistoryString appendFormat:@"%@:\n", [dateFormatter stringFromDate:events.creationDate]];
		
		int numEvents = (int)[events.editableHistoryEvents count];
		for (int j = 0; j < numEvents; j++)
		{
			EditableHistoryEvent* event = [events.editableHistoryEvents objectAtIndex:j];
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            
            [drugHistoryString appendFormat:@"    %@", [dateFormatter stringFromDate:event.creationDate]];
            if (event.late && [event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
                [drugHistoryString appendFormat:@" (%@ %@)", [event latePeriodDescription], [NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryLateDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Late", @"The label appearing under a late dose in the Drug History view"]) lowercaseString]];
			[drugHistoryString appendFormat:@"- %@\n", [historyManager getEventDescriptionForHistoryEvent:event.drugId
                                                                                                operation:event.operation
                                                                                            operationData:event.operationData
                                                                                               dosageType:event.dosageType
                                                                                          preferencesDict:[event createHistoryEventPreferencesDict]
                                                                                   legacyEventDescription:event.eventDescription
                                                                                          displayDrugName:YES]];
		}
	}
    
    return drugHistoryString;
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message
{
    if (userInteractionsAllowed)
    {
        userInteractionsAllowed = NO;

        // Pause notifications while we are disallowing user interactions
        [self pauseNotifications];

        if (delegate && [delegate respondsToSelector:@selector(disallowDosecastUserInteractionsWithMessage:)])
        {
            [delegate disallowDosecastUserInteractionsWithMessage:message];
        }	
    }
    else // update the message only if we're already disallowing user interactions
        [self updateDosecastMessageWhileUserInteractionsDisallowed:message];
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation
{
    if (!userInteractionsAllowed)
    {
        userInteractionsAllowed = YES;
        
        if (delegate && [delegate respondsToSelector:@selector(allowDosecastUserInteractionsWithMessage:)])
        {
            [delegate allowDosecastUserInteractionsWithMessage:allowAnimation];
        }	
        
        // Resume notifications now
        [self resumeNotifications];
    }
}

// Callback for when user attempts to change the passcode
- (void)handleChangePasscode
{
    if (delegate && [delegate respondsToSelector:@selector(handleChangePasscode)])
    {
        [delegate handleChangePasscode];
    }
}

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService
{
    if (delegate && [delegate respondsToSelector:@selector(getGroupTermsOfService)])
    {
        return [delegate getGroupTermsOfService];
    }
    else
        return nil;
}

// Returns the terms of service addenda from all groups the user joined
- (NSString*)getGroupTermsOfServiceAddenda
{
    NSMutableString* tosAddenda = [NSMutableString stringWithString:@""];
    
    for (Group* group in groups)
    {
        if (group.tosAddendum && [group.tosAddendum length] > 0)
        {
            if ([tosAddenda length] > 0)
                [tosAddenda appendString:@"\n\n"];
            [tosAddenda appendString:group.tosAddendum];
        }
    }
    
    return tosAddenda;
}

- (void)deleteAllLocalData
{
    // Delete the data file
    NSError *error=nil;
    [[NSFileManager defaultManager] removeItemAtURL:dataFile.fileUrl error:&error];
    
    // Delete all relevant data in memory. Persist the debug logging flag, since it will get cleared in the process.
    
    BOOL isDebugLoggingEnabled = globalSettings.debugLoggingEnabled;
    globalSettings = [[GlobalSettings alloc] initWithAPIFlags:[apiFlags getFlagNames]];
    globalSettings.delegate = self;
    if (isDebugLoggingEnabled)
        globalSettings.debugLoggingEnabled = YES;
    
    userID = nil;
    hardwareID = nil;
    wasExceedingMaxLocalNotifications = NO;
    syncNeeded = NO;
    isSyncInProgress = NO;
    requiresFollowOnSync = NO;
    [deletedDrugIDs removeAllObjects];
    [drugList removeAllObjects];
    [groups removeAllObjects];
    accountCreated = nil;
    completedInitialSync = NO;
    
    NSMutableDictionary* notificationDict = [[NSMutableDictionary alloc] init];

    // Notify anyone who cares that we've changed
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:DataModelDataRefreshNotification object:notificationDict]];
    
    // Notify anyone who cares that we've delete all data
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:DataModelDeleteAllDataNotification object:self]];
}

// Callback for when user attempts to delete all data
- (void)performDeleteAllData
{
    [self deleteAllLocalData];
    
    if ([apiFlags getFlag:DosecastAPIShowAccount])
        [[PurchaseManager getInstance] stopProcessingTransactions];
    
    if (delegate && [delegate respondsToSelector:@selector(handleDeleteAllData)])
    {
        [delegate handleDeleteAllData];
    }
}

// Returns whether leaving a particular group the user belongs to will take away the premium edition
- (BOOL)willLeavingGroupTakeAwayPremium:(NSString*)groupId
{
    if (globalSettings.accountType != AccountTypePremium || [globalSettings wasPremiumPurchasedOrGrantedByServer])
        return NO;
    
    // Check whether any other group, except the given one, gives the premium edition and the given group does too
    BOOL otherGroupGivesPremium = NO;
    BOOL thisGroupGivesPremium = NO;
    
    int numGroups = (int)[groups count];
    for (int i = 0; i < numGroups; i++)
    {
        Group* group = (Group*)[groups objectAtIndex:i];
        
        if ([group.groupID isEqualToString:groupId])
            thisGroupGivesPremium = group.givesPremium && !group.givesSubscription;
        else if (group.givesPremium && !group.givesSubscription)
            otherGroupGivesPremium = YES;
    }
    
    return (thisGroupGivesPremium && !otherGroupGivesPremium);
}

// Returns whether leaving a particular group the user belongs to will take away the subscription
- (BOOL)willLeavingGroupTakeAwaySubscription:(NSString*)groupId
{
    if (globalSettings.accountType != AccountTypeSubscription || [globalSettings wasSubscriptionPurchasedOrGrantedByServer])
        return NO;
    
    // Check whether any other group, except the given one, gives the subscription edition and the given group does too
    BOOL otherGroupGivesSubscription = NO;
    BOOL thisGroupGivesSubscription = NO;
    
    int numGroups = (int)[groups count];
    for (int i = 0; i < numGroups; i++)
    {
        Group* group = (Group*)[groups objectAtIndex:i];
        
        if ([group.groupID isEqualToString:groupId])
            thisGroupGivesSubscription = group.givesSubscription;
        else if (group.givesSubscription)
            otherGroupGivesSubscription = YES;
    }
    
    return (thisGroupGivesSubscription && !otherGroupGivesSubscription);
}

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (!userInteractionsAllowed)
    {
        if (delegate && [delegate respondsToSelector:@selector(updateDosecastMessageWhileUserInteractionsDisallowed:)])
        {
            [delegate updateDosecastMessageWhileUserInteractionsDisallowed:message];
        }	
    }
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress // A number between 0 and 1
{
    if (userInteractionsAllowed)
    {
        userInteractionsAllowed = NO;
        
        // Tell pause notifications while we are disallowing user interactions
        [self pauseNotifications];

        if (delegate && [delegate respondsToSelector:@selector(disallowDosecastUserInteractionsWithMessageAndProgress:progress:)])
        {
            [delegate disallowDosecastUserInteractionsWithMessageAndProgress:message progress:progress];
        }	
    }
    else // update the message and progress only if we're already disallowing user interactions
    {
        [self updateDosecastProgressMessageWhileUserInteractionsDisallowed:message];
        [self updateDosecastProgressWhileUserInteractionsDisallowed:progress];
    }
}

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress // A number between 0 and 1
{
    if (!userInteractionsAllowed)
    {
        if (delegate && [delegate respondsToSelector:@selector(updateDosecastProgressWhileUserInteractionsDisallowed:)])
        {
            [delegate updateDosecastProgressWhileUserInteractionsDisallowed:progress];
        }	
    }
}

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (!userInteractionsAllowed)
    {
        if (delegate && [delegate respondsToSelector:@selector(updateDosecastProgressMessageWhileUserInteractionsDisallowed:)])
        {
            [delegate updateDosecastProgressMessageWhileUserInteractionsDisallowed:message];
        }	
    }
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation
{
    if (!userInteractionsAllowed)
    {
        userInteractionsAllowed = YES;
        
        if (delegate && [delegate respondsToSelector:@selector(allowDosecastUserInteractionsWithMessageAndProgress:)])
        {
            [delegate allowDosecastUserInteractionsWithMessageAndProgress:allowAnimation];
        }	
        
        // Resume notifications now
        [self resumeNotifications];
    }
}

// Returns inputs needed for sync request
- (void)createInputsForSyncRequest:(NSMutableArray**)drugListDicts
                 globalPreferences:(NSMutableDictionary**)globalPreferences
{
    DebugLog(@"sync start");

    isSyncInProgress = YES;

    HistoryManager* historyManager = [HistoryManager getInstance];
    
    [historyManager beginBatchUpdates]; // Prepare to flag many history events as being synched
    
    // Populate drugs
    *drugListDicts = [[NSMutableArray alloc] init];
    for (int i = 0; i < [drugList count]; i++)
    {
        Drug* d = (Drug*)[drugList objectAtIndex:i];
        NSMutableDictionary *drugInfo = [[NSMutableDictionary alloc] init];
        [d populateDictionary:drugInfo forSyncRequest:YES];
        
        NSArray* historyEventsToSync = [historyManager getHistoryEventsToSyncForDrugId:d.drugId];
        NSMutableDictionary* drugHistoryDict = [drugInfo objectForKey:DrugHistoryKey];
        if (!drugHistoryDict)
            drugHistoryDict = [[NSMutableDictionary alloc] init];
        
        NSMutableArray* entries = [[NSMutableArray alloc] init];
        
        if (historyEventsToSync)
        {
            for (HistoryEvent* event in historyEventsToSync)
            {
                [entries addObject:
                 [JSONConverter createHistoryEventDictForSyncRequest:event.guid
                                                        creationDate:event.creationDate
                                                           operation:event.operation
                                                       operationData:event.operationData
                                                    eventDescription:event.eventDescription
                                                        scheduleDate:event.scheduleDate
                                                     preferencesDict:[historyManager createHistoryEventPreferencesDict:event]]];
            }
        }
        
        [drugHistoryDict setObject:entries forKey:DrugHistoryEntriesKey];
        
        [drugInfo setObject:drugHistoryDict forKey:DrugHistoryKey];
        
        [*drugListDicts addObject:drugInfo];
    }
    
    [historyManager endBatchUpdates:NO];
    
    *globalPreferences = [[NSMutableDictionary alloc] init];
    
    [globalSettings populateDictionary:*globalPreferences forSyncRequest:YES completedInitialSync:completedInitialSync];
}

- (BOOL)syncNeeded
{
    return syncNeeded;
}

- (void) setSyncNeeded:(BOOL)needed
{
    // If we're being asked to flag sync as being over, but someone requested a follow-on sync, setup the next one
    if (!needed && requiresFollowOnSync)
    {
        needed = YES;
        requiresFollowOnSync = NO;
    }
    // If we're being asked to start a sync, and another sync is in progress, consider this a request for a follow-on sync
    else if (needed && isSyncInProgress)
        requiresFollowOnSync = YES;
    
    if (needed != syncNeeded)
    {
        syncNeeded = needed;
     
        if (needed)
        {
            // Schedule a sync
            [[LogManager sharedManager] uploadLogs];
        }
    }
}

- (NSString*) userID
{
    return userID;
}

- (void) setUserID:(NSString *)uID
{
    if ((!userID && !uID) ||
        (userID && uID && [userID isEqualToString:uID]))
    {
        return;
    }
    
    [self deleteAllLocalData];
    userID = uID;
    syncNeeded = YES;
}

- (NSString*) hardwareID
{
    if (hardwareID && [hardwareID length] > 0)
        return hardwareID;
    else
    {
        hardwareID = [DosecastUtil getHardwareIDInKeychain];
        if (hardwareID && [hardwareID length] > 0)
            return hardwareID;
        else
        {
            DebugLog(@"Creating new hardware GUID");
            hardwareID = [DosecastUtil createGUID];
            [DosecastUtil setHardwareIDInKeychain:hardwareID];
            return hardwareID;
        }
    }
}

@end
