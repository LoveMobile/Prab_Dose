//
//  LocalNotificationManager.m
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "LocalNotificationManager.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "DataModel.h"
#import "Drug.h"
#include <stdlib.h>
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "HistoryManager.h"
#import "DosecastUtil.h"
#import "AddressBookContact.h"
#import "CustomNameIDList.h"
#import "JSONConverter.h"
#import "LogManager.h"
#import "DrugImageManager.h"
#import "HistoryEvent.h"
#import "VersionNumber.h"
#import "GlobalSettings.h"
#import "DosecastLocalNotification.h"
#import "ReachabilityManager.h"
#import "ServerProxy.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"
#import "PillNotificationManager.h"

static const double ASYNC_TIME_DELAY = 0.01;

static NSString *DrugIDListKey = @"pillIDList";
static NSString *GetStateMethodName = @"getState";
static NSString *CreatePillMethodName = @"createPill";
static NSString *EditPillMethodName = @"editPill";
static NSString *RefillPillMethodName = @"refillPill";
static NSString *DeletePillMethodName = @"deletePill";
static NSString *UndoPillMethodName = @"undoPill";
static NSString *TakePillMethodName = @"takePill";
static NSString *SkipPillMethodName = @"skipPill";
static NSString *PostponePillMethodName = @"postponePill";
static NSString *SubscribeMethodName = @"subscribe";
static NSString *StartFreeTrialMethodName = @"startFreeTrial";
static NSString *UpgradeMethodName = @"upgrade";
static NSString *SetBedtimeMethodName = @"setBedtime";
static NSString *SetPreferencesMethodName = @"setPreferences";
static NSString *MoveScheduledRemindersMethodName = @"moveScheduledReminders";
static NSString *SyncMethodName = @"sync";
static NSString *SetInventoryRemainingQuantityKey = @"remainingQuantity";
static NSString *SetInventoryRefillsRemainingKey = @"refillQuantity";
static NSString *AdjustInventoryQuantityKey = @"inventoryAdjustment";
static NSString *AdjustRefillQuantityKey = @"refillAdjustment";

static float epsilon = 0.0001;

static LocalNotificationManager *gInstance = nil;

typedef enum {
	LocalNotificationRepeatFrequencyNone    = 0,
	LocalNotificationRepeatFrequencyDaily   = 1,
	LocalNotificationRepeatFrequencyWeekly	= 7,
	LocalNotificationRepeatFrequencyMonthly	= 30
} LocalNotificationRepeatFrequency;

@implementation LocalNotificationManager

- (id)init
{
    if ((self = [super init]))
    {
        batchUpdatesStack = [[NSMutableArray alloc] init];
        batchServerMethodCalls = [[NSMutableSet alloc] init];
        batchDeletedDrugIds = [[NSMutableSet alloc] init];
        allLocalNotifications = [[NSMutableArray alloc] init];
        batchRefreshAllNotifications = NO;
        batchAdjustAndMergeNotifications = NO;
        getStateDelegate = nil;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalSettingsAPIVersionUpgrade object:nil];
}

- (void)handleAPIVersionUpgrade:(NSNotification*)notification
{
    VersionNumber* lastAPIVersionNumber = notification.object;
    if ([lastAPIVersionNumber compareWithVersionString:@"Version 6.0.9"] == NSOrderedSame) // upgrade from v6.0.9
    {
        [self refreshAllNotifications]; // reschedule all notifications since we changed how they are managed
    }
    else if ([lastAPIVersionNumber compareWithVersionString:@"Version 7.0.4"] == NSOrderedAscending) // upgrade from pre-7.0.4
    {
        [self refreshAllNotifications]; // reschedule all notifications since we changed how they are managed        
    }
}

// Singleton methods

+ (LocalNotificationManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

- (NSMutableArray*)getAllLocalNotifications
{
    if ([allLocalNotifications count] == 0)
        [allLocalNotifications setArray:[DosecastLocalNotification createFromScheduledLocalNotifications]];
    return allLocalNotifications;
}

- (NSString*)getAlertBodyForLocalNotification:(NSArray*)drugIDList
{
	DataModel* dataModel = [DataModel getInstance];
	NSMutableString* alertBody = nil;
	if (drugIDList && [drugIDList count] > 0)
	{
        if (dataModel.globalSettings.drugNamesDisplayedInNotifications)
        {
            alertBody = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Time to take", @"The alert phrase appearing in local notifications"])];
            for (int i = 0; i < [drugIDList count]; i++)
            {
                NSString* drugID = [drugIDList objectAtIndex:i];
                Drug* d = [dataModel findDrugWithId:drugID];
                if (i > 0)
                    [alertBody appendString:@","];
                [alertBody appendFormat:@" %@", d.name];
            }
        }
        else
        {
            if ([drugIDList count]>1)
            {
                alertBody=[NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertNoDrugPhrasePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Time to take your doses", @"The plural alert phrase appearing in local notifications without drug name"])];
            }
            else
            {
                alertBody=[NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertNoDrugPhraseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Time to take your dose", @"The singular alert phrase appearing in local notifications without drug name"])];
            }
        }
	}
    return alertBody;
}

// Returns the earliest a reminder can be scheduled for
- (NSDate*)getReminderLimitForTreatmentStartDate:(NSDate*)treatmentStartDate
{
	NSDate* earliestDate = [NSDate date];
	if (treatmentStartDate && [earliestDate timeIntervalSinceDate:treatmentStartDate] < 0)
	{
		earliestDate = [treatmentStartDate dateByAddingTimeInterval:-1]; // Allow a reminder to be scheduled on the start date for weekly/monthly reminders, so subtract 1 s
	}
	return earliestDate;
}

// Returns the next period in the given frequency from the given time.
- (NSDate*) getAdjacentPeriod:(NSDate*)time frequency:(LocalNotificationRepeatFrequency)frequency
{
    if (frequency == LocalNotificationRepeatFrequencyDaily)
		return [DosecastUtil addDaysToDate:time numDays:1];
	else if (frequency == LocalNotificationRepeatFrequencyWeekly)
		return [DosecastUtil addDaysToDate:time numDays:7];
	else if (frequency == LocalNotificationRepeatFrequencyMonthly)
        return [DosecastUtil addMonthsToDate:time numMonths:1];
	else
		return nil;
}

-(NSCalendarUnit) getRepeatIntervalForFrequency:(LocalNotificationRepeatFrequency)frequency
{
    if (frequency == LocalNotificationRepeatFrequencyDaily)
		return NSDayCalendarUnit;
	else if (frequency == LocalNotificationRepeatFrequencyWeekly)
		return NSWeekCalendarUnit;
	else if (frequency == LocalNotificationRepeatFrequencyMonthly)
		return NSMonthCalendarUnit;
	else
		return 0;	
}

- (LocalNotificationRepeatFrequency) getFrequencyForRepeatInterval:(NSCalendarUnit)repeatInterval
{
    if (repeatInterval == NSDayCalendarUnit)
		return LocalNotificationRepeatFrequencyDaily;
	else if (repeatInterval == NSWeekCalendarUnit)
		return LocalNotificationRepeatFrequencyWeekly;
	else if (repeatInterval == NSMonthCalendarUnit)
		return LocalNotificationRepeatFrequencyMonthly;
	else
		return LocalNotificationRepeatFrequencyNone;
}

- (LocalNotificationRepeatFrequency) getFrequencyForScheduledDrugFrequency:(ScheduledDrugFrequency)scheduledFreq
{
    if (scheduledFreq == ScheduledDrugFrequencyDaily)
        return LocalNotificationRepeatFrequencyDaily;
    else if (scheduledFreq == ScheduledDrugFrequencyWeekly)
        return LocalNotificationRepeatFrequencyWeekly;
    else if (scheduledFreq == ScheduledDrugFrequencyMonthly)
        return LocalNotificationRepeatFrequencyMonthly;
    else
        return LocalNotificationRepeatFrequencyNone;
}


- (DosecastLocalNotification*)createLocalNotificationForDrugIDList:(NSMutableArray*)drugIDList
													fireDate:(NSDate*)date
												   frequency:(LocalNotificationRepeatFrequency)frequency
{
	DataModel* dataModel = [DataModel getInstance];
	
	UILocalNotification* n = [[UILocalNotification alloc] init];
	n.alertAction = nil;
	n.applicationIconBadgeNumber = 1;
	n.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:drugIDList, DrugIDListKey, nil];
	n.hasAction = YES;
	n.repeatCalendar = nil;
	n.soundName = dataModel.globalSettings.reminderSoundFilename;
	n.fireDate = [DosecastUtil removeSecondsFromDate:date];
	n.repeatInterval = [self getRepeatIntervalForFrequency:frequency];
	n.timeZone = [NSTimeZone localTimeZone];
	n.alertLaunchImage = nil;
	n.alertBody = [self getAlertBodyForLocalNotification:drugIDList];
	
	return [[DosecastLocalNotification alloc] init:n isScheduled:NO];
}

NSComparisonResult compareByType(DosecastLocalNotification* n1, DosecastLocalNotification* n2, void* context)
{
    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    int n1Freq = (int)[localNotificationManager getFrequencyForRepeatInterval:n1.repeatInterval];
    int n2Freq = (int)[localNotificationManager getFrequencyForRepeatInterval:n2.repeatInterval];
    if (n1Freq == n2Freq)
        return NSOrderedSame;
    else if (n1Freq < n2Freq)
        return NSOrderedAscending;
    else
        return NSOrderedDescending;
}

// Return an array of notifications in which identical frequencies are merged together. Assumes incoming array
// is sorted by notification (frequency) type.
- (NSMutableArray*) mergeIdenticalLocalNotifications:(NSMutableArray*)mergeNotifications
{
    NSMutableArray* newNotifications = [[NSMutableArray alloc] init];
    DosecastLocalNotification* lastNotification = [mergeNotifications objectAtIndex:0];
    [mergeNotifications removeObjectAtIndex:0];
    LocalNotificationRepeatFrequency lastFrequency = [self getFrequencyForRepeatInterval:lastNotification.repeatInterval];
    
    while ([mergeNotifications count] > 0)
    {
        DosecastLocalNotification* thisNotification = [mergeNotifications objectAtIndex:0];
        [mergeNotifications removeObjectAtIndex:0];
        LocalNotificationRepeatFrequency thisFrequency = [self getFrequencyForRepeatInterval:thisNotification.repeatInterval];
        
        if (thisFrequency == lastFrequency)
        {
            NSMutableSet* thisDrugIDSet = [NSMutableSet setWithArray:[thisNotification.userInfo objectForKey:DrugIDListKey]];
            NSSet* lastDrugIDSet = [NSSet setWithArray:[lastNotification.userInfo objectForKey:DrugIDListKey]];
            [thisDrugIDSet unionSet:lastDrugIDSet];

            DosecastLocalNotification* newNotification = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithArray:[thisDrugIDSet allObjects]]
                                                                                     fireDate:lastNotification.fireDate
                                                                                    frequency:thisFrequency];
            lastNotification = newNotification;
        }
        else
        {
            [newNotifications addObject:lastNotification];
            lastNotification = thisNotification;
            lastFrequency = thisFrequency;
        }
   }
    
    [newNotifications addObject:lastNotification];
    
    return newNotifications;
}

// Return an array of notifications in which recurring and one-time notifications are merged together. Assumes incoming array
// is sorted by notification (frequency) type.
- (NSMutableArray*) mergeRecurringIntoOnetimeLocalNotifications:(NSMutableArray*)mergeNotifications
{
    NSMutableArray* newNotifications = [[NSMutableArray alloc] init];
    DosecastLocalNotification* lastNotification = [mergeNotifications objectAtIndex:0];
    [mergeNotifications removeObjectAtIndex:0];
    LocalNotificationRepeatFrequency lastFrequency = [self getFrequencyForRepeatInterval:lastNotification.repeatInterval];
    
    while ([mergeNotifications count] > 0)
    {
        DosecastLocalNotification* thisNotification = [mergeNotifications objectAtIndex:0];
        [mergeNotifications removeObjectAtIndex:0];
        LocalNotificationRepeatFrequency thisFrequency = [self getFrequencyForRepeatInterval:thisNotification.repeatInterval];
        
        if (lastFrequency == LocalNotificationRepeatFrequencyNone && thisFrequency != LocalNotificationRepeatFrequencyNone)
        {
            NSMutableSet* thisDrugIDSet = [NSMutableSet setWithArray:[thisNotification.userInfo objectForKey:DrugIDListKey]];
            NSSet* lastDrugIDSet = [NSSet setWithArray:[lastNotification.userInfo objectForKey:DrugIDListKey]];
            [thisDrugIDSet unionSet:lastDrugIDSet];

            DosecastLocalNotification* newNotification = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithArray:[thisDrugIDSet allObjects]]
                                                                                     fireDate:lastNotification.fireDate
                                                                                    frequency:LocalNotificationRepeatFrequencyNone];
            lastNotification = newNotification;
            
            DosecastLocalNotification* thisRepeatingNotification = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithArray:[thisNotification.userInfo objectForKey:DrugIDListKey]]
                                                                                               fireDate:[self getAdjacentPeriod:thisNotification.fireDate frequency:thisFrequency]
                                                                                              frequency:thisFrequency];
            [newNotifications addObject:thisRepeatingNotification];
        }
        else
        {
            [newNotifications addObject:lastNotification];
            lastNotification = thisNotification;
            lastFrequency = thisFrequency;
        }
    }
    
    [newNotifications addObject:lastNotification];
    
    return newNotifications;
}

- (NSMutableArray*) mergeOverlappingLocalNotifications:(NSMutableArray*)mergeNotifications
{
     // Sort the notifications so that non-recurring come first, followed by daily, weekly, and then monthly
    [mergeNotifications sortUsingFunction:compareByType context:NULL];

    // Merge all identical frequencies together
    [mergeNotifications setArray:[self mergeIdenticalLocalNotifications:mergeNotifications]];
    
    // Merge all identical frequencies together
    [mergeNotifications setArray:[self mergeRecurringIntoOnetimeLocalNotifications:mergeNotifications]];
	
	return mergeNotifications;
}

NSComparisonResult compareByFireDate(DosecastLocalNotification* n1, DosecastLocalNotification* n2, void* context)
{
	NSTimeInterval interval = [n1.fireDate timeIntervalSinceDate:n2.fireDate];
	if (interval < 0)
		return NSOrderedAscending;
	else if (interval > 0)
		return NSOrderedDescending;
	else
        return NSOrderedSame;
}

- (void) mergeAllOverlappingLocalNotifications
{
    NSMutableArray* localNotifications = [[self getAllLocalNotifications] mutableCopy];
	if ([localNotifications count] == 0)
		return;
	   
	[localNotifications sortUsingFunction:compareByFireDate context:NULL];
	
	NSMutableArray* mergeNotifications = [[NSMutableArray alloc] init];
	[mergeNotifications addObject:[localNotifications objectAtIndex:0]];
	[localNotifications removeObjectAtIndex:0];
	
	while ([localNotifications count] > 0 || [mergeNotifications count] > 1)
	{
		if ([localNotifications count] > 0)
		{
			DosecastLocalNotification* notification = [localNotifications objectAtIndex:0];
			[localNotifications removeObjectAtIndex:0];
			DosecastLocalNotification* lastNotification = [mergeNotifications lastObject];
            NSTimeInterval timeDiff = fabs([lastNotification.fireDate timeIntervalSinceDate:notification.fireDate]);
            
            // See whether this one fire within 60 s of the last one
			if (timeDiff < 60.0-epsilon)
				[mergeNotifications addObject:notification];
			else
			{
				if ([mergeNotifications count] > 1)
				{
					for (DosecastLocalNotification* n in mergeNotifications)
                    {
                        // Cancel this notification and remove from our local list
                        [n requestCancel];
                        [n commit];
                        [[self getAllLocalNotifications] removeObject:n];
                    }
					
					NSMutableArray* newNotifications = [self mergeOverlappingLocalNotifications:mergeNotifications];
										
                    for (DosecastLocalNotification* n in newNotifications)
                    {
                        [n requestSchedule]; // schedule this notification and add to our local list
                        [[self getAllLocalNotifications] addObject:n];
                    }
				}
				
				[mergeNotifications removeAllObjects];
				[mergeNotifications addObject:notification];
			}
		}
		else
		{
            for (DosecastLocalNotification* n in mergeNotifications)
            {
                // Cancel this notification and remove from our local list
                [n requestCancel];
                [n commit];
                [[self getAllLocalNotifications] removeObject:n];
            }
			
			NSMutableArray* newNotifications = [self mergeOverlappingLocalNotifications:mergeNotifications];
						
            for (DosecastLocalNotification* n in newNotifications)
            {
                [n requestSchedule]; // schedule this notification and add to our local list
                [[self getAllLocalNotifications] addObject:n];
            }
			
			[mergeNotifications removeAllObjects];
			if ([localNotifications count] > 0)
			{
				[mergeNotifications addObject:[localNotifications objectAtIndex:0]];
				[localNotifications removeObjectAtIndex:0];
			}
		}
	}	
}

-(NSSet*) cancelLocalNotificationForDrugId:(DosecastLocalNotification*)n
								 drugId:(NSString*)drugId
{
	if (!n || !drugId)
		return [[NSSet alloc] init];
	
    NSMutableSet* drugIDList = [NSMutableSet setWithArray:[n.userInfo objectForKey:DrugIDListKey]];
    [drugIDList minusSet:[NSSet setWithObject:drugId]];

	if ([drugIDList count] > 0)
	{
		LocalNotificationRepeatFrequency frequency = [self getFrequencyForRepeatInterval:n.repeatInterval];
		DosecastLocalNotification* newNotification = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithArray:[drugIDList allObjects]]
																				 fireDate:n.fireDate
																				frequency:frequency];
        
        [newNotification requestSchedule]; // schedule this notification and add to our local list
        [[self getAllLocalNotifications] addObject:newNotification];
	}
    
    // Cancel this notification and remove from our local list
    [n requestCancel];
    [n commit];
    [[self getAllLocalNotifications] removeObject:n];

    return drugIDList;
}

- (NSArray*)getLocalNotificationsForDrugId:(NSString*)drugId
{
	NSMutableArray* results = [[NSMutableArray alloc] init];
    NSArray* allNotifications = [self getAllLocalNotifications];
	for (int i = 0; i < [allNotifications count]; i++)
	{
		DosecastLocalNotification* n = [allNotifications objectAtIndex:i];
		NSMutableArray* drugIDList = [n.userInfo objectForKey:DrugIDListKey];
		for (int j = 0; j < [drugIDList count]; j++)
		{
			NSString* thisDrugID = [drugIDList objectAtIndex:j];
			if ([thisDrugID caseInsensitiveCompare:drugId] == NSOrderedSame)
				[results addObject:n];
		}
	}
	return results;
}

- (NSSet*)cancelLocalNotificationsForDrugId:(NSArray*)notifications
								   drugId:(NSString*)drugId
{
    NSMutableSet* allAffectedDrugs = [[NSMutableSet alloc] init];
	for (int i = 0; i < [notifications count]; i++)
	{
		DosecastLocalNotification* n = [notifications objectAtIndex:i];
		[allAffectedDrugs unionSet:[self cancelLocalNotificationForDrugId:n drugId:drugId]];
	}
    return allAffectedDrugs;
}

- (BOOL)hasRepeatingNotificationInArray:(NSArray*)notifications
{
	for (int i = 0; i < [notifications count]; i++)
	{
		DosecastLocalNotification* n = [notifications objectAtIndex:i];
		if (n.repeatInterval != 0)
			return YES;
	}
	return NO;
}

- (void)scheduleNotificationsForScheduledReminderDrug:(Drug*)drug
{
    int secondaryReminderPeriodSecs = [DataModel getInstance].globalSettings.secondaryReminderPeriodSecs;

    ScheduledDrugReminder* scheduledReminder = ((ScheduledDrugReminder*)drug.reminder);
    int nextTimeNum;
    BOOL wasPostponed;
    NSDate* currDay;
    int postponeDuration;
    [scheduledReminder getLastReminderTimeIndex:&nextTimeNum wasPostponed:&wasPostponed postponeDuration:&postponeDuration onDay:&currDay];
    
    int numTimes = (int)[scheduledReminder.reminderTimes count];
    
    // Iterate through all times of day once for daily, monthly, and custom frequencies. However, iterate through all weekdays, and then for all times of day for weekly frequencies.
    int numIterations = 1;
    if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly && scheduledReminder.weekdays)
        numIterations = (int)[scheduledReminder.weekdays count];
    
    NSDate* onDay = currDay;
    int scheduledTime = nextTimeNum;
    for (int j = 0; j < numIterations; j++)
    {
        for (int i = 0; i < numTimes; i++)
        {
            NSDate* recurringTime = nil;
            
            // If this is the index of the most recent time of day (in the past), and it is the first iteration, handle postponed reminders.
            // For a postponed reminder, create a one-time reminder for the postponed time and then a recurring reminder starting the following day
            if (j == 0 && scheduledTime == nextTimeNum)
            {
                if (wasPostponed)
                {
                    // Schedule a one-time notification for the postponed reminder
                    DosecastLocalNotification* n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                                     fireDate:drug.reminder.nextReminder
                                                                                    frequency:LocalNotificationRepeatFrequencyNone];
                    
                    [n requestSchedule]; // schedule this notification and add to our local list
                    [[self getAllLocalNotifications] addObject:n];
                    
                    // Schedule secondary reminder (if enabled)
                    if (drug.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                    {
                        n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                              fireDate:[DosecastUtil addTimeIntervalToDate:drug.reminder.nextReminder timeInterval:secondaryReminderPeriodSecs]
                                                             frequency:LocalNotificationRepeatFrequencyNone];
                        
                        [n requestSchedule]; // schedule this notification and add to our local list
                        [[self getAllLocalNotifications] addObject:n];
                    }
                }
                
                // Schedule a recurring notification starting the following day for future reminders
                recurringTime = [scheduledReminder getReminderTimeForDay:scheduledTime day:[scheduledReminder getNextRecurringDay:onDay]];
            }
            else
            {
                // Schedule a recurring notification
                recurringTime = [scheduledReminder getReminderTimeForDay:scheduledTime day:onDay];
            }
            
            // Schedule custom frequencies
            if (scheduledReminder.frequency == ScheduledDrugFrequencyCustom)
            {
                BOOL didHitEndDate = NO;
                int numPeriodsConversion = [ScheduledDrugReminder getNumPeriodsConversionForRepeatingCustomLocalNotifications];
                // For custom frequency, expand the recurring reminder into the future since iOS can't handle this
                for (int j = 0; j < numPeriodsConversion && !didHitEndDate; j++)
                {
                    // Make sure we didn't go past the end date
                    if (drug.reminder.treatmentEndDate && [recurringTime timeIntervalSinceDate:drug.reminder.treatmentEndDate] > 0)
                        didHitEndDate = YES;
                    else
                    {
                        DosecastLocalNotification* n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                                         fireDate:recurringTime
                                                                                        frequency:LocalNotificationRepeatFrequencyNone];
                        
                        [n requestSchedule]; // schedule this notification and add to our local list
                        [[self getAllLocalNotifications] addObject:n];
                        
                        // Schedule secondary reminder (if enabled)
                        if (drug.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                        {
                            n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                  fireDate:[DosecastUtil addTimeIntervalToDate:recurringTime timeInterval:secondaryReminderPeriodSecs]
                                                                 frequency:LocalNotificationRepeatFrequencyNone];
                            
                            [n requestSchedule]; // schedule this notification and add to our local list
                            [[self getAllLocalNotifications] addObject:n];
                        }

                        // Advance to next day
                        recurringTime = [scheduledReminder getNextDay:recurringTime];
                    }
                }
            }
            else // Schedule all other frequencies
            {
                // Schedule 1 recurring reminder through iOS
                DosecastLocalNotification* n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                                 fireDate:recurringTime
                                                                                frequency:[self getFrequencyForScheduledDrugFrequency:scheduledReminder.frequency]];
                
                [n requestSchedule]; // schedule this notification and add to our local list
                [[self getAllLocalNotifications] addObject:n];
                
                // Schedule secondary reminder (if enabled)
                if (drug.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
                {
                    n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                          fireDate:[DosecastUtil addTimeIntervalToDate:recurringTime timeInterval:secondaryReminderPeriodSecs]
                                                         frequency:[self getFrequencyForScheduledDrugFrequency:scheduledReminder.frequency]];
                    
                    [n requestSchedule]; // schedule this notification and add to our local list
                    [[self getAllLocalNotifications] addObject:n];
                }
            }
            
            scheduledTime += 1;
            if (scheduledTime == numTimes)
            {
                scheduledTime = 0;
                onDay = [scheduledReminder getNextDay:onDay];
            }				
        }
    }
}

- (void)scheduleNotificationsForDrug:(Drug*)drug
{
    DataModel* dataModel = [DataModel getInstance];

    if ([drug.reminder isKindOfClass:[AsNeededDrugReminder class]] ||
        !drug.reminder.remindersEnabled)
    {
        return;
    }
    
    NSDate* now = [NSDate date];
    int secondaryReminderPeriodSecs = dataModel.globalSettings.secondaryReminderPeriodSecs;
    
    // If the drug is overdue and the secondary reminder is enabled but the secondary period hasn't passed yet, schedule the second reminder now
    if (drug.reminder.overdueReminder && drug.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0 &&
        [now timeIntervalSinceDate:[DosecastUtil addTimeIntervalToDate:drug.reminder.overdueReminder timeInterval:secondaryReminderPeriodSecs]] < 0)
    {
        DosecastLocalNotification* n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                         fireDate:[DosecastUtil addTimeIntervalToDate:drug.reminder.overdueReminder timeInterval:secondaryReminderPeriodSecs]
                                                                        frequency:LocalNotificationRepeatFrequencyNone];
        
        [n requestSchedule]; // schedule this notification and add to our local list
        [[self getAllLocalNotifications] addObject:n];
    }

    if (!drug.reminder.nextReminder)
        return;
    
    // Just schedule a one-time reminder if this is an interval drug or it is scheduled and postponed past the treatment end date
    if ([drug.reminder isKindOfClass:[IntervalDrugReminder class]] || (drug.reminder.treatmentEndDate && [now timeIntervalSinceDate:drug.reminder.treatmentEndDate] > 0))
    {
        DosecastLocalNotification* n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                                         fireDate:drug.reminder.nextReminder
                                                                        frequency:LocalNotificationRepeatFrequencyNone];
        
        [n requestSchedule]; // schedule this notification and add to our local list
        [[self getAllLocalNotifications] addObject:n];
        
        // Schedule secondary reminder (if enabled)
        if (drug.reminder.secondaryRemindersEnabled && secondaryReminderPeriodSecs > 0)
        {
            n = [self createLocalNotificationForDrugIDList:[NSMutableArray arrayWithObject:drug.drugId]
                                                  fireDate:[DosecastUtil addTimeIntervalToDate:drug.reminder.nextReminder timeInterval:secondaryReminderPeriodSecs]
                                                 frequency:LocalNotificationRepeatFrequencyNone];
            
            [n requestSchedule]; // schedule this notification and add to our local list
            [[self getAllLocalNotifications] addObject:n];
        }
    }
    else // ScheduledDrugReminder and before the treatment end date
        [self scheduleNotificationsForScheduledReminderDrug:drug];
}

- (void) rescheduleRecurringDrugsInDrugIDSet:(NSSet*)drugIDSet
{
    DataModel* dataModel = [DataModel getInstance];
    NSArray* drugIDList = [drugIDSet allObjects];
    
    for (NSString* drugId in drugIDList)
    {
        Drug *d = [dataModel findDrugWithId:drugId];
        
        // Look for non-custom (recurring) scheduled drugs
        if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        {
            ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;
            if (scheduledReminder.frequency != ScheduledDrugFrequencyCustom)
            {
                NSArray* notifications = [self getLocalNotificationsForDrugId:d.drugId];
                [self cancelLocalNotificationsForDrugId:notifications drugId:d.drugId];
                [self scheduleNotificationsForDrug:d];
            }
        }
    }
}

- (void)extendScheduledCustomPeriodNotifications
{
	DataModel* dataModel = [DataModel getInstance];
    NSMutableSet* allAffectedDrugs = [[NSMutableSet alloc] init];
    
	for (Drug* d in dataModel.drugList)
	{
        // Look for scheduled drugs with custom frequency periods...
        if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        {
            ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;
            if (scheduledReminder.frequency == ScheduledDrugFrequencyCustom)
            {
                // See if we have fewer than the expected number of periods in the list of notifications. If we do, extend them into the future.
         		NSArray* notifications = [self getLocalNotificationsForDrugId:d.drugId];
                int numTimes = (int)[scheduledReminder.reminderTimes count];
                if ([notifications count] < ([ScheduledDrugReminder getNumPeriodsConversionForRepeatingCustomLocalNotifications] * numTimes))
                {
                    [allAffectedDrugs unionSet:[self cancelLocalNotificationsForDrugId:notifications drugId:d.drugId]];
                    [self scheduleNotificationsForDrug:d];
                }
            }
        }        
	}
    
    // Since the rescheduled notifications are non-recurring, then rescheduling may have cancelled notifications that had merged with recurring drugs,
    // which can't be unmerged. Reschedule them now.
    [self rescheduleRecurringDrugsInDrugIDSet:allAffectedDrugs];
}

- (void) adjustAndMergeNotifications
{
    // If we are in the middle of a batch operation, postpone this until later
    if ([self batchUpdatesInProgress])
    {
        batchAdjustAndMergeNotifications = YES;
        return;
    }

    [self extendScheduledCustomPeriodNotifications];
	[self mergeAllOverlappingLocalNotifications];
    
    // Commit any pending notification changes
    for (DosecastLocalNotification* n in allLocalNotifications)
    {
        [n commit];
    }
    [[self getAllLocalNotifications] removeAllObjects];
}

// Clears and re-sets all notifications
- (void)refreshAllNotificationsInternal
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [allLocalNotifications removeAllObjects];
    
    DataModel* dataModel = [DataModel getInstance];
    for (Drug* d in dataModel.drugList)
    {
        [self scheduleNotificationsForDrug:d];
    }
}

// Clears and re-sets all notifications
- (void)refreshAllNotifications
{
    // If we are in the middle of a batch operation, postpone this until later
    if ([self batchUpdatesInProgress])
    {
        batchRefreshAllNotifications = YES;
        return;
    }
    
    [self refreshAllNotificationsInternal];
	
    [self adjustAndMergeNotifications];
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];

    // Destroy the singleton so we don't get notified of any more time zone changes
    @synchronized(self)
    {
        gInstance = nil;
    }
}

- (void) adjustRemindersForTimeZoneChange:(NSTimeInterval)timeZoneInterval
{
	DataModel* dataModel = [DataModel getInstance];
    
    NSDate* now = [NSDate date];
    
    // Change the bedtime, if defined, since it is stored in GMT.
    NSDate* bedtimeStartDate = nil;
    NSDate* bedtimeEndDate = nil;
    [dataModel getBedtimeAsDates:&bedtimeStartDate bedtimeEnd:&bedtimeEndDate];
    if (bedtimeStartDate && bedtimeEndDate)
    {
        bedtimeStartDate = [DosecastUtil addTimeIntervalToDate:bedtimeStartDate timeInterval:timeZoneInterval];
        dataModel.globalSettings.bedtimeStart = [DosecastUtil getDateAs24hrTime:bedtimeStartDate];
        bedtimeEndDate = [DosecastUtil addTimeIntervalToDate:bedtimeEndDate timeInterval:timeZoneInterval];
        dataModel.globalSettings.bedtimeEnd = [DosecastUtil getDateAs24hrTime:bedtimeEndDate];
    }
    
    // We need to change the scheduled reminder times because they are stored at GMT for the benefit
    // of the server when push notifications are used.
    for (Drug *d in dataModel.drugList)
    {
        [d.reminder adjustRemindersForTimeZoneChange:timeZoneInterval];
        d.clientEditTime = now;
        d.clientEditGUID = [DosecastUtil createGUID];
    }
    
    [self refreshAllNotificationsInternal];
    
    dataModel.globalSettings.lastTimeZoneChangeTime = [now dateByAddingTimeInterval:-10]; // make sure the change time isn't set exactly to the check time
}

- (BOOL) handleUpdateAfterLocalDataModelChange:(NSString*)serverMethodCall deletedDrugId:(NSString*)deletedDrugId updateServer:(BOOL)updateServer errorMessage:(NSString**)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];
    BOOL result = YES;

    if ([self batchUpdatesInProgress])
    {
        [batchServerMethodCalls addObject:serverMethodCall];
        if (deletedDrugId)
            [batchDeletedDrugIds addObject:deletedDrugId];
    }
    else
    {
        NSMutableSet* deletedDrugIds = [[NSMutableSet alloc] init];
        if (deletedDrugId)
            [deletedDrugIds addObject:deletedDrugId];
            
        if (updateServer)
            dataModel.syncNeeded = YES;
        
        DebugLog(@"writing file");

        if ([dataModel writeToFile:errorMessage])
            [dataModel updateAfterLocalDataModelChange:[NSSet setWithObject:serverMethodCall] deletedDrugIDs:deletedDrugIds];
        else
            result = NO;
    }
    
    return result;
}

- (void) updateLastTimeZoneInfo
{
    DataModel* dataModel = [DataModel getInstance];

    dataModel.globalSettings.lastTimezoneGMTOffset = [DosecastUtil getCurrTimezoneGMTOffset];
    dataModel.globalSettings.lastTimezoneName = [DosecastUtil getCurrTimezoneName];
    dataModel.globalSettings.lastDaylightSavingsTimeOffset = [DosecastUtil getCurrDaylightSavingsTimeOffset];
    dataModel.globalSettings.lastScheduledDaylightSavingsTimeChange = [DosecastUtil getNextDaylightSavingsTimeTransition];
    dataModel.globalSettings.lastTimeZoneChangeCheckTime = [NSDate date];
}

- (void) getStateInternal:(BOOL)allowServerUpdate
  processedTimeZoneChange:(BOOL)processedTimeZoneChange
                respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
{
    DataModel* dataModel = [DataModel getInstance];

    // Check for notifications related to missing drugs (i.e. drugs not existing anymore).
    // These shouldn't exist, but if found, remove them - just to ensure we don't get out of sync.
    NSMutableSet* allDrugIDs = [[NSMutableSet alloc] init];
    for (Drug* d in dataModel.drugList)
    {
        [allDrugIDs addObject:d.drugId];
    }
    
    NSArray* notifications = [self getAllLocalNotifications];
    NSMutableSet* missingDrugIDs = [NSMutableSet set];
    for (int i = 0; i < [notifications count]; i++)
    {
        DosecastLocalNotification* n = [notifications objectAtIndex:i];
        NSMutableSet* drugIDSet = [NSMutableSet setWithArray:[n.userInfo objectForKey:DrugIDListKey]];
        [drugIDSet minusSet:allDrugIDs];
        [missingDrugIDs unionSet:drugIDSet];
    }
    
    // Delete the notifications for missing drugs
    NSArray* missingList = [missingDrugIDs allObjects];
    for (int i = 0; i < [missingList count]; i++)
    {
        NSString* drugID = [missingList objectAtIndex:i];
        NSArray* notifications = [self getLocalNotificationsForDrugId:drugID];
        [self cancelLocalNotificationsForDrugId:notifications drugId:drugID];
    }
    
    // Refresh the drug list
    NSMutableArray* drugList = dataModel.drugList;
    for (int i = 0; i < [drugList count]; i++)
    {
        Drug* d = [drugList objectAtIndex:i];
        [d refreshDrugInternalState];
    }
    
    BOOL isExceedingMaxLocalNotifications = [dataModel isExceedingMaxLocalNotifications];
    
    // If we just reduced the local notification usage below the threshold, we need to refresh all notifications to make sure none were lost.
    // This could happen if treatment end dates are now past
    if (dataModel.wasExceedingMaxLocalNotifications && !isExceedingMaxLocalNotifications)
    {
        [self refreshAllNotificationsInternal];
    }
    dataModel.wasExceedingMaxLocalNotifications = isExceedingMaxLocalNotifications;
    
    [self adjustAndMergeNotifications];
    NSString* errorMessage = nil;
    
    BOOL result = [self handleUpdateAfterLocalDataModelChange:GetStateMethodName deletedDrugId:nil updateServer:(allowServerUpdate && processedTimeZoneChange) errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(getStateLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate getStateLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    // If we processed a time zone change, start a sync right away.
    if (allowServerUpdate && processedTimeZoneChange)
        [[LogManager sharedManager] startUploadLogsImmediately];
    
    DebugLog(@"getState end");
}

// Proxy for GetState call. If successful, updates data model.
- (void)getState:(BOOL)allowServerUpdate
        respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async
{
    if (async)
    {
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(getState:respondTo:async:);
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
        [myInvocation setArgument:&allowServerUpdate atIndex:2];
		[myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"getState start");

	DataModel* dataModel = [DataModel getInstance];
    BOOL processedTimeZoneChange = NO;
    
    // See if we need to resolve a timezone change before proceeding. If so, do it first.
    if (allowServerUpdate && [dataModel needsToResolveTimezoneChange] && dataModel.globalSettings.lastDaylightSavingsTimeOffset)
    {
        __block NSTimeInterval timeZoneInterval = [dataModel.globalSettings.lastTimezoneGMTOffset longValue] - [[DosecastUtil getCurrTimezoneGMTOffset] longValue];
        __block NSTimeInterval dstOffsetInterval = [dataModel.globalSettings.lastDaylightSavingsTimeOffset doubleValue] - [[DosecastUtil getCurrDaylightSavingsTimeOffset] doubleValue];
        
        // If this is a DST transition, and no other device on our account has processed it, then don't do anything.
        BOOL isDSTTransition = (fabs(dstOffsetInterval) > epsilon);
        BOOL shouldRespondToDSTTransition = (isDSTTransition &&
                                             (!dataModel.globalSettings.lastScheduledDaylightSavingsTimeChange ||
                                              !dataModel.globalSettings.lastTimeZoneChangeTime ||
                                              [dataModel.globalSettings.lastTimeZoneChangeTime timeIntervalSinceDate:dataModel.globalSettings.lastScheduledDaylightSavingsTimeChange] < 0));
        BOOL shouldRespondToTZTransition = ((!dataModel.globalSettings.lastTimeZoneChangeCheckTime ||
                                             !dataModel.globalSettings.lastTimeZoneChangeTime ||
                                             [dataModel.globalSettings.lastTimeZoneChangeTime timeIntervalSinceDate:dataModel.globalSettings.lastTimeZoneChangeCheckTime] < 0) &&
                                            (!isDSTTransition || fabs(timeZoneInterval - dstOffsetInterval) > epsilon));

        if (shouldRespondToDSTTransition)
        {
            processedTimeZoneChange = YES;
            
            [self adjustRemindersForTimeZoneChange:dstOffsetInterval];
        }
        
        if (shouldRespondToTZTransition)
        {
            DebugLog(@"getState time zone alert");

            getStateDelegate = delegate;

            NSString* timeZoneChangeMessage = [NSString stringWithFormat:
                                               NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertTimeZoneChangeMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ has detected a change in time zones from %@ to %@. Would you like to move your dose schedule to %@, or keep your dose schedule in %@?", @"The title on the alert appearing when a premium feature is accessed in the demo edition"]),
                                               [DosecastUtil getProductAppName],
                                               dataModel.globalSettings.lastTimezoneName,
                                               [DosecastUtil getCurrTimezoneName],
                                               [DosecastUtil getCurrTimezoneName],
                                               dataModel.globalSettings.lastTimezoneName];
            
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertTimeZoneChangeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time Zone Change Detected", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                       message:timeZoneChangeMessage
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertTimeZoneChangeMove", @"Dosecast", [DosecastUtil getResourceBundle], @"Move", @"The text on the Not Now button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction* action){
                                              DebugLog(@"adjust pill schedules");
                                              
                                              [self adjustRemindersForTimeZoneChange:timeZoneInterval - dstOffsetInterval];
                                              
                                              [self updateLastTimeZoneInfo];
                                              
                                              [self getStateInternal:YES processedTimeZoneChange:YES respondTo:getStateDelegate];
                                              getStateDelegate = nil;

                                          }]];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"LocalNotificationAlertTimeZoneChangeKeep", @"Dosecast", [DosecastUtil getResourceBundle], @"Keep", @"The Upgrade button of the alert appearing when a premium feature is accessed in demo edition"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action){
                                              DebugLog(@"keep pill schedules");
                                              
                                              [self refreshAllNotificationsInternal];
                                              
                                              [DataModel getInstance].globalSettings.lastTimeZoneChangeTime = [[NSDate date] dateByAddingTimeInterval:-10]; // make sure the change time isn't set exactly to the check time
                                              
                                              [self updateLastTimeZoneInfo];
                                              
                                              [self getStateInternal:YES processedTimeZoneChange:YES respondTo:getStateDelegate];
                                              getStateDelegate = nil;

                                          }]];
        
            UINavigationController* mainNavigationController = [[PillNotificationManager getInstance].delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];

            [alert showInViewController:topNavController.topViewController];

            return;
        }
        else
        {
            [self updateLastTimeZoneInfo];
        }
    }
    else
        dataModel.globalSettings.lastTimeZoneChangeCheckTime = [NSDate date];

    [self getStateInternal:allowServerUpdate processedTimeZoneChange:processedTimeZoneChange respondTo:delegate];
}

// Proxy for CreatePill call. If successful, updates data model.
- (void)createPill:(NSString*)drugID
          drugName:(NSString*)drugName
         imageGUID:(NSString *)GUID
          personId:(NSString*)personId
		directions:(NSString*)directions
     doctorContact:(AddressBookContact*)doctor
   pharmacyContact:(AddressBookContact*)pharmacy
   prescriptionNum:(NSString*)prescripNum
	  drugReminder:(DrugReminder*)reminder
		drugDosage:(DrugDosage*)dosage
             notes:(NSString*)notes
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained DrugDosage* dos = dosage;
        __unsafe_unretained DrugReminder* rem = reminder;
        __unsafe_unretained AddressBookContact* doc = doctor;
        __unsafe_unretained AddressBookContact* pharm = pharmacy;
        __unsafe_unretained NSString* direc = directions;
        __unsafe_unretained NSString* pID = personId;
        __unsafe_unretained NSString* guid = GUID;
        __unsafe_unretained NSString* dId = drugID;
        __unsafe_unretained NSString* dName = drugName;
        __unsafe_unretained NSString* prescrip = prescripNum;
        __unsafe_unretained NSString* not = notes;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(createPill:drugName:imageGUID:personId:directions:doctorContact:pharmacyContact:prescriptionNum:drugReminder:drugDosage:notes:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dId atIndex:2];
		[myInvocation setArgument:&dName atIndex:3];
        [myInvocation setArgument:&guid atIndex:4];
        [myInvocation setArgument:&pID atIndex:5];
        [myInvocation setArgument:&direc atIndex:6];
        [myInvocation setArgument:&doc atIndex:7];
        [myInvocation setArgument:&pharm atIndex:8];
        [myInvocation setArgument:&prescrip atIndex:9];
        [myInvocation setArgument:&rem atIndex:10];
        [myInvocation setArgument:&dos atIndex:11];
        [myInvocation setArgument:&not atIndex:12];
        [myInvocation setArgument:&del atIndex:13];
        [myInvocation setArgument:&asyncAgain atIndex:14];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"createPill start");

    DataModel* dataModel = [DataModel getInstance];
    
    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    NSString* newDrugID = drugID;
    if (!newDrugID)
        newDrugID = [DosecastUtil createGUID];
    NSDate* now = [NSDate date];
    Drug* d = [[Drug alloc] init:newDrugID
                            name:drugName
                   drugImageGUID:GUID
                         created:now
                        personId:personId
                      directions:directions
                   doctorContact:doctor
                 pharmacyContact:pharmacy
                 prescriptionNum:prescripNum
                        reminder:reminder
                          dosage:dosage
                           notes:notes
                  clientEditGUID:[DosecastUtil createGUID]
                  clientEditTime:now
                  serverEditGUID:nil
                lastHistoryToken:0
             deletedHistoryGUIDs:[[NSMutableSet alloc] init]
            undoHistoryEventGUID:nil
            otherDrugPreferences:nil];
    
    [dataModel.drugList addObject:d];
    
    [historyManager updateRemainingRefillQuantityFromCompleteHistoryForDrug:newDrugID];

    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:d.dosage
             notes:d.notes
undoHistoryEventGUID:nil
      updateServer:NO
         respondTo:nil
             async:NO];
    
    [d refreshDrugInternalState];
    
    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(createPillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate createPillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"createPill end");
}

// Proxy for EditPill call. If successful, updates data model.
- (void)editPill:(NSString*)drugID
        drugName:(NSString*)drugName
       imageGUID:(NSString *)GUID
        personId:(NSString*)personId
      directions:(NSString*)directions
   doctorContact:(AddressBookContact*)doctor
 pharmacyContact:(AddressBookContact*)pharmacy
 prescriptionNum:(NSString*)prescripNum
    drugReminder:(DrugReminder*)reminder
      drugDosage:(DrugDosage*)dosage
           notes:(NSString*)notes
undoHistoryEventGUID:(NSString*)undoHistoryEventGUID
    updateServer:(BOOL)updateServer
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained DrugDosage* dos = dosage;
        __unsafe_unretained DrugReminder* rem = reminder;
        __unsafe_unretained AddressBookContact* doc = doctor;
        __unsafe_unretained AddressBookContact* pharm = pharmacy;
        __unsafe_unretained NSString* direc = directions;
        __unsafe_unretained NSString* pID = personId;
        __unsafe_unretained NSString* guid = GUID;
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSString* dName = drugName;
        __unsafe_unretained NSString* prescrip = prescripNum;
        __unsafe_unretained NSString* not = notes;
        __unsafe_unretained NSString* eventGUID = undoHistoryEventGUID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(editPill:drugName:imageGUID:personId:directions:doctorContact:pharmacyContact:prescriptionNum:drugReminder:drugDosage:notes:undoHistoryEventGUID:updateServer:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
        [myInvocation setArgument:&dName atIndex:3];
        [myInvocation setArgument:&guid atIndex:4];
        [myInvocation setArgument:&pID atIndex:5];
        [myInvocation setArgument:&direc atIndex:6];
        [myInvocation setArgument:&doc atIndex:7];
        [myInvocation setArgument:&pharm atIndex:8];
        [myInvocation setArgument:&prescrip atIndex:9];
        [myInvocation setArgument:&rem atIndex:10];
        [myInvocation setArgument:&dos atIndex:11];
        [myInvocation setArgument:&not atIndex:12];
        [myInvocation setArgument:&eventGUID atIndex:13];
        [myInvocation setArgument:&updateServer atIndex:14];
        [myInvocation setArgument:&del atIndex:15];
        [myInvocation setArgument:&asyncAgain atIndex:16];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"editPill start");

	DataModel* dataModel = [DataModel getInstance];
    NSDate* now = [NSDate date];
    
	Drug* d = [dataModel findDrugWithId:drugID];
	if (d)
	{
        d.reminder = reminder;

        HistoryManager* historyManager = [HistoryManager getInstance];
        NSDate* lastTaken = [historyManager getLastTakenTimeForDrugId:drugID];
        NSDate* effLastTaken = [historyManager getEffectiveLastTakenTimeForDrugId:drugID];
        NSDate* notifyAfter = [historyManager getNotifyAfterTimeForDrugId:drugID fromEffLastTaken:effLastTaken andLastTaken:lastTaken];

        [d.reminder updateReminderStateWithLastTaken:lastTaken effLastTaken:effLastTaken notifyAfter:notifyAfter];
                
        float oldRemainingQuantity = 0.0f;
        [d.dosage getValueForRemainingQuantity:&oldRemainingQuantity];
        int oldRefillsRemaining = [d.dosage getRefillsRemaining];
        
		d.name = drugName;
        d.drugImageGUID = GUID;
        d.personId = personId;
		d.directions = directions;
        d.doctorContact = doctor;
        d.pharmacyContact = pharmacy;
        d.prescriptionNum = prescripNum;
        d.notes = notes;
		d.dosage = dosage;
        [d createUndoState:undoHistoryEventGUID];
        
        if (updateServer)
        {
            d.clientEditTime = now;
            d.clientEditGUID = [DosecastUtil createGUID];
        }
        
        [historyManager beginBatchUpdates];
        
        // If the remaining quantity has changed, add a set inventory event
        float newRemainingQuantity = 0.0f;
        [d.dosage getValueForRemainingQuantity:&newRemainingQuantity];
        int newRefillsRemaining = [d.dosage getRefillsRemaining];

        if (updateServer && oldRefillsRemaining != newRefillsRemaining)
        {
            NSDictionary* preferenceDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSString stringWithFormat:@"%d", newRefillsRemaining-oldRefillsRemaining], AdjustRefillQuantityKey,
                                            nil];
            
            [historyManager addHistoryEvent:drugID
                                                     guid:nil
                                             creationDate:[NSDate date]
                                         eventDescription:nil
                                                operation:HistoryManagerAdjustRefillOperationName
                                            operationData:nil
                                             scheduleDate:nil
                                          preferencesDict:preferenceDict
                                        isManuallyCreated:NO
                                             notifyServer:YES
                                             errorMessage:nil];
        }
        
        if (updateServer && fabsf(newRemainingQuantity-oldRemainingQuantity) > epsilon)
        {
            int sigDigits = 0;
            int numDecimals = 0;
            BOOL displayNone = YES;
            BOOL allowZero = YES;
            [d.dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero];

            NSDictionary* preferenceDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [DrugDosage getStringFromQuantity:(newRemainingQuantity-oldRemainingQuantity) unit:nil numDecimals:numDecimals], AdjustInventoryQuantityKey,
                                            nil];
            
            [historyManager addHistoryEvent:drugID
                                                     guid:nil
                                             creationDate:[NSDate date]
                                         eventDescription:nil
                                                operation:HistoryManagerAdjustInventoryOperationName
                                            operationData:nil
                                             scheduleDate:nil
                                          preferencesDict:preferenceDict
                                        isManuallyCreated:NO
                                             notifyServer:YES
                                             errorMessage:nil];
        }
        
        [historyManager endBatchUpdates:NO];
        
        // Don't allow the edited drug to exceed a dose limit, if one is set.
        // This is only needed when switching from interval to interval types, or scheduled to interval types
        if ([d wouldExceedDoseLimitIfTakenAtDate:now nextAvailableDoseTime:nil])
        {
            d.reminder.nextReminder = nil;
            d.reminder.skipPillAfter = nil;
            d.reminder.maxPostponeTime = nil;
        }
        
        BOOL isExceedingMaxLocalNotifications = [dataModel isExceedingMaxLocalNotifications];
        
        // If we just reduced the local notification usage below the threshold, we need to refresh all notifications to make sure none were lost.
        if (dataModel.wasExceedingMaxLocalNotifications && !isExceedingMaxLocalNotifications)
        {
            [self refreshAllNotificationsInternal];
        }
        else
        {
            NSArray* notifications = [self getLocalNotificationsForDrugId:d.drugId];
            NSSet* allAffectedDrugs = [self cancelLocalNotificationsForDrugId:notifications drugId:d.drugId];
            [self scheduleNotificationsForDrug:d];
            
            // If this drug's notifications are non-recurring, then editing this drug may have cancelled notifications that had merged with recurring drugs,
            // which can't be unmerged. Reschedule them now.
            if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] ||
                ([d.reminder isKindOfClass:[ScheduledDrugReminder class]] && ((ScheduledDrugReminder*)d.reminder).frequency == ScheduledDrugFrequencyCustom))
            {
                [self rescheduleRecurringDrugsInDrugIDSet:allAffectedDrugs];
            }
        }
        dataModel.wasExceedingMaxLocalNotifications = isExceedingMaxLocalNotifications;
	}
	else
	{
        DebugLog(@"editPill end: error (drug not found)");

		NSString* errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditNotFound", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not edit drug. Drug not found.", @"The error message appearing when a drug can't be edited because no drug with the given ID could be found"]);
        if (delegate && [delegate respondsToSelector:@selector(editPillLocalNotificationManagerResponse:errorMessage:)])
        {
            [delegate editPillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
        }
        return;
	}
    
    [self adjustAndMergeNotifications];
    
    NSString* errorMessage = nil;
    BOOL result = [self handleUpdateAfterLocalDataModelChange:EditPillMethodName deletedDrugId:nil updateServer:updateServer errorMessage:&errorMessage];

    if (delegate && [delegate respondsToSelector:@selector(editPillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate editPillLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"editPill end");
}

// Proxy for RefillPill call. If successful, updates data model.
- (void)refillPill:(NSString*)drugID
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(refillPill:respondTo:async:);
        NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
        NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
        [myInvocation setTarget:self];
        [myInvocation setSelector:asyncMethod];
        [myInvocation setArgument:&dID atIndex:2];
        [myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"refillPill start");

    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    DataModel* dataModel = [DataModel getInstance];
    Drug* d = [dataModel findDrugWithId:drugID];
    NSString* errorMessage = nil;
    
    // Log this event with the history manager
    HistoryEvent* event = [[HistoryManager getInstance] addHistoryEvent:drugID
                                             guid:nil
                                     creationDate:[NSDate date]
                                 eventDescription:nil
                                        operation:HistoryManagerRefillOperationName
                                    operationData:nil
                                     scheduleDate:nil
                                  preferencesDict:nil
                                isManuallyCreated:NO
                                     notifyServer:YES
                                     errorMessage:&errorMessage];
    
    
    // Calculate impact to remaining/refill quantity of deleting this record
    float remainingQuantityOffset = 0.0f;
    int refillQuantityOffset = 0;
    [historyManager getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&remainingQuantityOffset refillQuantityOffset:&refillQuantityOffset];
    
    DrugDosage* dosage = [d.dosage mutableCopy];
    
    // Update remaining quantity and refills remaining, if they were changed by the history
    if (fabsf(remainingQuantityOffset) > epsilon)
    {
        float remainingQuantity = 0.0f;
        [dosage getValueForRemainingQuantity:&remainingQuantity];
        [dosage setValueForRemainingQuantity:remainingQuantity + remainingQuantityOffset];
    }
    
    if (abs(refillQuantityOffset) > 0)
    {
        int refillQuantity = [dosage getRefillsRemaining];
        [dosage setRefillsRemaining:refillQuantity + refillQuantityOffset];
    }

    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:dosage
             notes:d.notes
     undoHistoryEventGUID:d.undoHistoryEventGUID
      updateServer:NO // other devices will recalculate the quantity from the history
         respondTo:nil
             async:NO];
    
    [d refreshDrugInternalState];
    
    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(refillPillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate refillPillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"refillPill end");
}

// Proxy for DeletePill call. If successful, updates data model.
- (void)deletePill:(NSString*)drugID
      updateServer:(BOOL)updateServer
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(deletePill:updateServer:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
		[myInvocation setArgument:&updateServer atIndex:3];
        [myInvocation setArgument:&del atIndex:4];
        [myInvocation setArgument:&asyncAgain atIndex:5];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"deletePill start");

	NSString* errorMessage = nil;
	DataModel* dataModel = [DataModel getInstance];

	int numDrugs = (int)[dataModel.drugList count];
	int drugIndex = -1;
	for (int i = 0; i < numDrugs && drugIndex < 0; i++)
	{
		Drug* d = (Drug*)[dataModel.drugList objectAtIndex:i];
		if ([drugID caseInsensitiveCompare:d.drugId] == NSOrderedSame)
        {
			drugIndex = i;
        }
	}
	if (drugIndex >= 0)
	{
        // Delete the associated drug image.
        
        DrugImageManager *manager = [DrugImageManager sharedManager];
        
        Drug* d = (Drug*)[dataModel.drugList objectAtIndex:drugIndex];
        NSString *imageGUIDToDelete = d.drugImageGUID;
        
        if ( imageGUIDToDelete.length > 0 )
        {
            [manager removeImageForImageGUID:imageGUIDToDelete shouldRemoveServerImage:YES];
        }

        [dataModel.deletedDrugIDs addObject:drugID];
		[dataModel.drugList removeObjectAtIndex:drugIndex];
        
        BOOL wasExceedingMaxLocalNotifications = dataModel.wasExceedingMaxLocalNotifications;
        BOOL isExceedingMaxLocalNotifications = [dataModel isExceedingMaxLocalNotifications];
        
        // If we just reduced the local notification usage below the threshold, we need to refresh all notifications to make sure none were lost.
        if (wasExceedingMaxLocalNotifications && !isExceedingMaxLocalNotifications)
        {
            [self refreshAllNotificationsInternal];
        }
        else
        {
            NSArray* notifications = [self getLocalNotificationsForDrugId:drugID];
            NSSet* allAffectedDrugs = [self cancelLocalNotificationsForDrugId:notifications drugId:drugID];
            
            // If this drug's notifications are non-recurring, then editing this drug may have cancelled notifications that had merged with recurring drugs,
            // which can't be unmerged. Reschedule them now.
            if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] ||
                ([d.reminder isKindOfClass:[ScheduledDrugReminder class]] && ((ScheduledDrugReminder*)d.reminder).frequency == ScheduledDrugFrequencyCustom))
            {
                [self rescheduleRecurringDrugsInDrugIDSet:allAffectedDrugs];
            }
        }
	}
	else
	{
        [dataModel.deletedDrugIDs addObject:drugID];  // just in case this pill was added and deleted before a sync, add the drug ID to our deleted list

        DebugLog(@"deletePill end: error (drug not found but added to deleted list)");

		errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugDeleteNotFound", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not delete drug. Drug not found.", @"The error message appearing when a drug can't be deleted because no drug with the given ID could be found"]);
        if (delegate && [delegate respondsToSelector:@selector(deletePillLocalNotificationManagerResponse:errorMessage:)])
        {
            [delegate deletePillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
        }
        return;
	}

	// Delete events with the history manager
    [[HistoryManager getInstance] deleteAllEventsForDrugId:drugID notifyServer:updateServer errorMessage:&errorMessage];
	   
    [self adjustAndMergeNotifications];

    BOOL result = [self handleUpdateAfterLocalDataModelChange:DeletePillMethodName deletedDrugId:drugID updateServer:updateServer errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(deletePillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate deletePillLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"deletePill end");
}

// Proxy for UndoPill call. If successful, updates data model.
- (void)undoPill:(NSString*)drugID
	respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(undoPill:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
        [myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"undoPill start");

	DataModel* dataModel = [DataModel getInstance];
    HistoryManager* historyManager = [HistoryManager getInstance];

    Drug* d = [dataModel findDrugWithId:drugID];

    [self beginBatchUpdates];
    
    [historyManager beginBatchUpdates];
    
    [d performUndo];
    
    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:d.dosage
             notes:d.notes
undoHistoryEventGUID:nil
      updateServer:YES // because the undoHistoryEventGUID was cleared
         respondTo:nil
             async:NO];
    
    [d refreshDrugInternalState];
    
    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(undoPillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate undoPillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"undoPill end");
}

// Proxy for TakePill call. If successful, updates data model.
- (void)takePill:(NSString*)drugID
        doseTime:(NSDate*)doseTime
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSDate* time = doseTime;
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(takePill:doseTime:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
        [myInvocation setArgument:&time atIndex:3];
        [myInvocation setArgument:&del atIndex:4];
        [myInvocation setArgument:&asyncAgain atIndex:5];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"takePill start");

    DataModel* dataModel = [DataModel getInstance];
    Drug* d = [dataModel findDrugWithId:drugID];
    NSString* errorMessage = nil;
    
    if (d.reminder.takePillAfter && [[NSDate date] timeIntervalSinceDate:d.reminder.takePillAfter] < 0)
    {
        DebugLog(@"takePill end: error (too soon)");

        errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugTakeTooSoon", @"Dosecast", [DosecastUtil getResourceBundle], @"It is too soon to take this dose. Please try again later.", @"The error message appearing when a drug can't be taken because it is too soon"]);
        if (delegate && [delegate respondsToSelector:@selector(takePillLocalNotificationManagerResponse:errorMessage:)])
        {
            [delegate takePillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
        }
        return;
    }

    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    // Check for missed doses (for scheduled pills only if overdue)
    [historyManager checkForMissedDosesForDrugId:drugID errorMessage:nil];

    NSString* undoHistoryEventGUID = [DosecastUtil createGUID];
    
    // Log this event with the history manager
    HistoryEvent* event = [[HistoryManager getInstance] addHistoryEvent:drugID
                                             guid:undoHistoryEventGUID
                                     creationDate:doseTime
                                 eventDescription:nil
                                        operation:HistoryManagerTakePillOperationName
                                    operationData:nil
                                     scheduleDate:[d.reminder getCurrentScheduledTime]
                                  preferencesDict:nil
                                isManuallyCreated:NO
                                     notifyServer:YES
                                     errorMessage:&errorMessage];
    
    // Calculate impact to remaining/refill quantity of deleting this record
    float remainingQuantityOffset = 0.0f;
    int refillQuantityOffset = 0;
    [historyManager getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&remainingQuantityOffset refillQuantityOffset:&refillQuantityOffset];
    
    // Update remaining quantity and refills remaining, if they were changed by the history
    if (fabsf(remainingQuantityOffset) > epsilon)
    {
        float remainingQuantity = 0.0f;
        [d.dosage getValueForRemainingQuantity:&remainingQuantity];
        [d.dosage setValueForRemainingQuantity:remainingQuantity + remainingQuantityOffset];
    }
    
    if (abs(refillQuantityOffset) > 0)
    {
        int refillQuantity = [d.dosage getRefillsRemaining];
        [d.dosage setRefillsRemaining:refillQuantity + refillQuantityOffset];
    }
    
    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:d.dosage
             notes:d.notes
     undoHistoryEventGUID:undoHistoryEventGUID
      updateServer:YES // to register the undoHistoryEventGUID change
         respondTo:nil
             async:NO];
    
    [d refreshDrugInternalState];

    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];

    if (delegate && [delegate respondsToSelector:@selector(takePillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate takePillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"takePill end");
}

// Proxy for SkipPill call. If successful, updates data model.
- (void)skipPill:(NSString*)drugID
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(skipPill:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
        [myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"skipPill start");

    DataModel* dataModel = [DataModel getInstance];
    Drug* d = [dataModel findDrugWithId:drugID];
    NSDate* now = [NSDate date];
    NSString* errorMessage = nil;
    
    if (d.reminder.skipPillAfter && [now timeIntervalSinceDate:d.reminder.skipPillAfter] < 0)
    {
        DebugLog(@"skipPill end: error (too soon)");

        errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugSkipTooSoon", @"Dosecast", [DosecastUtil getResourceBundle], @"It is too soon to skip this dose. Please try again later.", @"The error message appearing when a drug can't be skipped because it is too soon"]);
        if (delegate && [delegate respondsToSelector:@selector(skipPillLocalNotificationManagerResponse:errorMessage:)])
        {
            [delegate skipPillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
        }
        return;
    }
    
    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    // Check for missed doses (for scheduled pills only if overdue)
    [historyManager checkForMissedDosesForDrugId:drugID errorMessage:nil];

    NSString* undoHistoryEventGUID = [DosecastUtil createGUID];
    
    // Log this event with the history manager
    [[HistoryManager getInstance] addHistoryEvent:drugID
                                             guid:undoHistoryEventGUID
                                     creationDate:now
                                 eventDescription:nil
                                        operation:HistoryManagerSkipPillOperationName
                                    operationData:nil
                                     scheduleDate:[d.reminder getCurrentScheduledTime]
                                  preferencesDict:nil
                                isManuallyCreated:NO
                                     notifyServer:YES
                                     errorMessage:&errorMessage];
    
    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:d.dosage
             notes:d.notes
undoHistoryEventGUID:undoHistoryEventGUID
      updateServer:YES // to register the undoHistoryEventGUID change
         respondTo:nil
             async:NO];
    
    [d refreshDrugInternalState];
    
    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(skipPillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate skipPillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"skipPill end");
}

// Proxy for PostponePill call. If successful, updates data model.
- (void)postponePill:(NSString*)drugID
			 seconds:(int)seconds // How long to postpone for
           respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
               async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* dID = drugID;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(postponePill:seconds:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&dID atIndex:2];
		[myInvocation setArgument:&seconds atIndex:3];
        [myInvocation setArgument:&del atIndex:4];
        [myInvocation setArgument:&asyncAgain atIndex:5];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"postponePill start");

    DataModel* dataModel = [DataModel getInstance];
    Drug* d = [dataModel findDrugWithId:drugID];
    NSDate* now = [NSDate date];
    NSString* errorMessage = nil;
    NSDate* postponeTime = nil;

    if (d.reminder.overdueReminder)
    {
        NSDate* baseTime = now;
        
        postponeTime = [baseTime dateByAddingTimeInterval:seconds];
        if (d.reminder.maxPostponeTime && [d.reminder.maxPostponeTime timeIntervalSinceDate:postponeTime] < 0)
        {
            DebugLog(@"postponePill end: error (collides with next dose when overdue)");

            errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugPostponeTooLong", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not postpone dose. Please select a shorter duration.", @"The error message appearing when a drug can't be postponed because the duration is too long"]);
            if (delegate && [delegate respondsToSelector:@selector(postponePillLocalNotificationManagerResponse:errorMessage:)])
            {
                [delegate postponePillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
            }
            return;
        }
    }
    else if (d.reminder.nextReminder && [now timeIntervalSinceDate:d.reminder.nextReminder] <= 0)
    {
        postponeTime = [d.reminder.nextReminder dateByAddingTimeInterval:seconds];
        if (d.reminder.maxPostponeTime && [d.reminder.maxPostponeTime timeIntervalSinceDate:postponeTime] < 0)
        {
            DebugLog(@"postponePill end: error (collides with next dose when not overdue)");

            errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugPostponeTooLong", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not postpone dose. Please select a shorter duration.", @"The error message appearing when a drug can't be postponed because the duration is too long"]);
            if (delegate && [delegate respondsToSelector:@selector(postponePillLocalNotificationManagerResponse:errorMessage:)])
            {
                [delegate postponePillLocalNotificationManagerResponse:NO errorMessage:errorMessage];
            }
            return;
        }
    }
    
    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    // Check for missed doses (for scheduled pills only if overdue)
    [historyManager checkForMissedDosesForDrugId:drugID errorMessage:nil];

    NSString* undoHistoryEventGUID = [DosecastUtil createGUID];
    
    // Log this event with the history manager
    [[HistoryManager getInstance] addHistoryEvent:drugID
                                             guid:undoHistoryEventGUID
                                     creationDate:now
                                 eventDescription:nil
                                        operation:HistoryManagerPostponePillOperationName
                                    operationData:[NSString stringWithFormat:@"%d", seconds]
                                     scheduleDate:[d.reminder getCurrentScheduledTime]
                                  preferencesDict:nil
                                isManuallyCreated:NO
                                     notifyServer:YES
                                     errorMessage:&errorMessage];
    
    [self editPill:d.drugId
          drugName:d.name
         imageGUID:d.drugImageGUID
          personId:d.personId
        directions:d.directions
     doctorContact:d.doctorContact
   pharmacyContact:d.pharmacyContact
   prescriptionNum:d.prescriptionNum
      drugReminder:d.reminder
        drugDosage:d.dosage
             notes:d.notes
undoHistoryEventGUID:undoHistoryEventGUID
      updateServer:YES // to register the undoHistoryEventGUID change
         respondTo:nil
             async:NO];

    [d refreshDrugInternalState];
    
    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(postponePillLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate postponePillLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"postponePill end");
}

// Proxy for Subscribe call. If successful, updates data model.
  - (void)subscribe:(NSString*)receipt
  newExpirationDate:(NSDate*)newExpirationDate
          respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
              async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* rec = receipt;
        __unsafe_unretained NSDate* exp = newExpirationDate;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(subscribe:newExpirationDate:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&rec atIndex:2];
        [myInvocation setArgument:&exp atIndex:3];
		[myInvocation setArgument:&del atIndex:4];
        [myInvocation setArgument:&asyncAgain atIndex:5];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"subscribe start");

	NSString* errorMessage = nil;
	
	DataModel* dataModel = [DataModel getInstance];
    [dataModel.globalSettings addSubscriptionReceipt:receipt];
    dataModel.globalSettings.subscriptionExpires = newExpirationDate;
    
    BOOL result = [self handleUpdateAfterLocalDataModelChange:SubscribeMethodName deletedDrugId:nil updateServer:YES errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(subscribeLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate subscribeLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"subscribe end");
}

// Proxy for Upgrade call. If successful, updates data model.
- (void)upgrade:(NSString*)receipt
      respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
          async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSString* rec = receipt;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(upgrade:respondTo:async:);
        NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
        NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
        [myInvocation setTarget:self];
        [myInvocation setSelector:asyncMethod];
        [myInvocation setArgument:&rec atIndex:2];
        [myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"upgrade start");

    NSString* errorMessage = nil;
    
    DataModel* dataModel = [DataModel getInstance];
    dataModel.globalSettings.premiumReceipt = receipt;
    dataModel.globalSettings.purchasedPremium = YES;
    
    BOOL result = [self handleUpdateAfterLocalDataModelChange:UpgradeMethodName deletedDrugId:nil updateServer:YES errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(upgradeLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate upgradeLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"upgrade start");
}

// Proxy for StartFreeTrial call. If successful, updates data model.
- (void)startFreeTrial:(NSObject<LocalNotificationManagerDelegate>*)delegate
                 async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(startFreeTrial:async:);
        NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
        NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
        [myInvocation setTarget:self];
        [myInvocation setSelector:asyncMethod];
        [myInvocation setArgument:&del atIndex:2];
        [myInvocation setArgument:&asyncAgain atIndex:3];
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"startFreeTrial start");

    NSString* errorMessage = nil;
    
    DataModel* dataModel = [DataModel getInstance];
    BOOL allowTrial = !dataModel.globalSettings.issued7daySubscriptionTrial && !dataModel.globalSettings.subscriptionExpires;
    if (allowTrial)
    {
        dataModel.globalSettings.subscriptionExpires = [DosecastUtil getLastSecondOnDate:[DosecastUtil addDaysToDate:[NSDate date] numDays:7]];
        dataModel.globalSettings.issued7daySubscriptionTrial = YES;
    }
    
    BOOL result = [self handleUpdateAfterLocalDataModelChange:StartFreeTrialMethodName deletedDrugId:nil updateServer:YES errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(startFreeTrialLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate startFreeTrialLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"startFreeTrial end");
}

// Proxy for SetBedtime call. If successful, updates data model.
- (void)setBedtime:(int)bedtimeStart
		bedtimeEnd:(int)bedtimeEnd
	  respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(setBedtime:bedtimeEnd:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&bedtimeStart atIndex:2];
		[myInvocation setArgument:&bedtimeEnd atIndex:3];
		[myInvocation setArgument:&del atIndex:4];
        [myInvocation setArgument:&asyncAgain atIndex:5];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"setBedtime start");

	NSString* errorMessage = nil;

	if ((bedtimeStart < 0 && bedtimeEnd >= 0) ||
		(bedtimeStart >= 0 && bedtimeEnd < 0))
	{
        DebugLog(@"setBedtime end: error (invalid bedtimes)");

		errorMessage = NSLocalizedStringWithDefaultValue(@"ErrorBedtimeInvalid", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not set bedtime. Bedtime start and end times must both be either set or unset.", @"The error message appearing when an invalid bedtime was provided (i.e. either the start or end time was missing)"]);
        if (delegate && [delegate respondsToSelector:@selector(setBedtimeLocalNotificationManagerResponse:errorMessage:)])
        {
            [delegate setBedtimeLocalNotificationManagerResponse:NO errorMessage:errorMessage];
        }
		return;
	}

	DataModel* dataModel = [DataModel getInstance];
	NSDate* now = [NSDate date];
    NSMutableSet* allAffectedDrugs = [[NSMutableSet alloc] init];
	if (bedtimeStart >= 0 && bedtimeEnd >= 0)
	{
		NSMutableArray* drugList = dataModel.drugList;
		for (int i = 0; i < [drugList count]; i++)
		{
			Drug*d = [drugList objectAtIndex:i];
			// Turn off any interval reminders that will go off during bedtime
			if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] &&
                !d.reminder.overdueReminder && [DataModel dateOccursDuringBedtime:d.reminder.nextReminder bedtimeStart:bedtimeStart bedtimeEnd:bedtimeEnd])
			{
				d.reminder.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
				d.reminder.maxPostponeTime = nil;
				d.reminder.overdueReminder = nil;
				d.reminder.skipPillAfter = nil;
				d.reminder.nextReminder = nil;
				
				NSArray* notifications = [self getLocalNotificationsForDrugId:d.drugId];
				[allAffectedDrugs unionSet:[self cancelLocalNotificationsForDrugId:notifications drugId:d.drugId]];
			}
		}
	}
	else if (dataModel.globalSettings.bedtimeStart >= 0 && dataModel.globalSettings.bedtimeEnd >= 0)
	{
		for (Drug* d in dataModel.drugList)
		{
			// If we are switching bedtime off, see if any interval reminders would have gone off during bedtime, and if so,
			// turn them back on
			if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] &&
                d.reminder.lastTaken && !d.reminder.overdueReminder && !d.reminder.nextReminder)
			{
				NSDate* nextReminder = [d.reminder.lastTaken dateByAddingTimeInterval:((IntervalDrugReminder*)d.reminder).interval];
				
				if ([now timeIntervalSinceDate:nextReminder] < 0 &&
					[dataModel dateOccursDuringBedtime:nextReminder] &&
					(!d.reminder.treatmentEndDate || [nextReminder timeIntervalSinceDate:d.reminder.treatmentEndDate] <= 0) &&
					([nextReminder timeIntervalSinceDate:d.reminder.treatmentStartDate] >= 0))
				{
					d.reminder.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
					d.reminder.maxPostponeTime = [DosecastUtil addDaysToDate:now numDays:1];
					d.reminder.overdueReminder = nil;
					d.reminder.nextReminder = nextReminder;
					d.reminder.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
					
					NSArray* notifications = [self getLocalNotificationsForDrugId:d.drugId];
					[allAffectedDrugs unionSet:[self cancelLocalNotificationsForDrugId:notifications drugId:d.drugId]];
					[self scheduleNotificationsForDrug:d];
				}
			}
		}		
	}
	
    // If this drug's notifications are non-recurring, then editing these drugs may have cancelled notifications that had merged with recurring drugs,
    // which can't be unmerged. Reschedule them now.
    [self rescheduleRecurringDrugsInDrugIDSet:allAffectedDrugs];

	dataModel.globalSettings.bedtimeStart = bedtimeStart;
	dataModel.globalSettings.bedtimeEnd = bedtimeEnd;
	
    [self adjustAndMergeNotifications];

    BOOL result = [self handleUpdateAfterLocalDataModelChange:SetBedtimeMethodName deletedDrugId:nil updateServer:YES errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(setBedtimeLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate setBedtimeLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"setBedtime end");
}

// Proxy for SetPreferences call. If successful, updates data model.
- (void)setPreferences:(NSMutableDictionary*)dict
		  respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
                 async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSMutableDictionary* d = dict;
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
		SEL asyncMethod = @selector(setPreferences:respondTo:async:);
		NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
		NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvocation setTarget:self];
		[myInvocation setSelector:asyncMethod];
		[myInvocation setArgument:&d atIndex:2];
		[myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
		[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }

    DebugLog(@"setPreferences start");

	NSString *errorMessage = nil;
	DataModel* dataModel = [DataModel getInstance];
    
	if ([dataModel.globalSettings updateFromServerDictionary:dict isInteractive:YES currentServerTime:nil limitToProductStatusOnly:NO])
		[self refreshAllNotifications];
	else
        [self adjustAndMergeNotifications];
   
    BOOL result = [self handleUpdateAfterLocalDataModelChange:SetPreferencesMethodName deletedDrugId:nil updateServer:YES errorMessage:&errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(setPreferencesLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate setPreferencesLocalNotificationManagerResponse:result errorMessage:errorMessage];
    }
    
    DebugLog(@"setPreferences end");
}

// Proxy for MoveScheduledReminders call. If successful, updates data model.
- (void)moveScheduledReminders:(NSTimeInterval)timePeriodSecs
                     respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
                         async:(BOOL)async
{
    if (async)
    {
        __unsafe_unretained NSObject<LocalNotificationManagerDelegate>* del = delegate;
        BOOL asyncAgain = NO;
        SEL asyncMethod = @selector(moveScheduledReminders:respondTo:async:);
        NSMethodSignature * mySignature = [LocalNotificationManager instanceMethodSignatureForSelector:asyncMethod];
        NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
        [myInvocation setTarget:self];
        [myInvocation setSelector:asyncMethod];
        [myInvocation setArgument:&timePeriodSecs atIndex:2];
        [myInvocation setArgument:&del atIndex:3];
        [myInvocation setArgument:&asyncAgain atIndex:4];
        [NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY invocation:myInvocation repeats:NO];
        return;
    }
    
    DebugLog(@"moveScheduledReminders start");

    DataModel* dataModel = [DataModel getInstance];
    
    [self beginBatchUpdates];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    for (Drug* d in dataModel.drugList)
    {
        if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        {
            ScheduledDrugReminder* newReminder = [(ScheduledDrugReminder*)d.reminder mutableCopy];
            [newReminder adjustReminderTimesByTimeInterval:timePeriodSecs];
            
            [self editPill:d.drugId
                  drugName:d.name
                 imageGUID:d.drugImageGUID
                  personId:d.personId
                directions:d.directions
             doctorContact:d.doctorContact
           pharmacyContact:d.pharmacyContact
           prescriptionNum:d.prescriptionNum
              drugReminder:newReminder
                drugDosage:d.dosage
                     notes:d.notes
      undoHistoryEventGUID:d.undoHistoryEventGUID
              updateServer:YES
                 respondTo:nil
                     async:NO];
            
            [d refreshDrugInternalState];
        }
    }

    [historyManager endBatchUpdates:YES];
    
    [self getState:NO respondTo:nil async:NO]; // This is necessary because changes to the history could change a pill's effLastTaken, which could affect scheduling
    
    [self endBatchUpdates:NO];
    
    if (delegate && [delegate respondsToSelector:@selector(moveScheduledRemindersLocalNotificationManagerResponse:errorMessage:)])
    {
        [delegate moveScheduledRemindersLocalNotificationManagerResponse:YES errorMessage:nil];
    }
    
    DebugLog(@"moveScheduledReminders end");
}

// Called prior to beginning a batch of LocalNotificationManager calls - for performance purposes
- (void) beginBatchUpdates
{
    // Reset flags
    if (![self batchUpdatesInProgress])
    {
        batchRefreshAllNotifications = NO;
        batchAdjustAndMergeNotifications = NO;
        [batchServerMethodCalls removeAllObjects];
        [batchDeletedDrugIds removeAllObjects];
    }
    
    [batchUpdatesStack addObject:[NSNumber numberWithBool:YES]];
}

// Whether batch updates are in progress
- (BOOL) batchUpdatesInProgress
{
    return ([batchUpdatesStack count] > 0);
}

// Called after ending a batch of LocalNotificationManager calls - for performance purposes
- (void) endBatchUpdates:(BOOL)completedSync
{
    if (completedSync)
        [batchServerMethodCalls addObject:SyncMethodName];

    if ([self batchUpdatesInProgress])
        [batchUpdatesStack removeLastObject];
    
    if (![self batchUpdatesInProgress])
    {
        if (batchRefreshAllNotifications)
            [self refreshAllNotifications];
        else if (batchAdjustAndMergeNotifications)
            [self adjustAndMergeNotifications];
        
        if ([batchServerMethodCalls count] > 0)
        {
            DataModel* dataModel = [DataModel getInstance];
            dataModel.syncNeeded = !completedSync;
            
            DebugLog(@"writing file");

            if ([dataModel writeToFile:nil])
                [dataModel updateAfterLocalDataModelChange:batchServerMethodCalls deletedDrugIDs:batchDeletedDrugIds];
        }
        
        batchRefreshAllNotifications = NO;
        batchAdjustAndMergeNotifications = NO;
        [batchServerMethodCalls removeAllObjects];
        [batchDeletedDrugIds removeAllObjects];
    }
}

@end
