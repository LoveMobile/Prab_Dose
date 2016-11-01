//
//  DrugReminder.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugReminder.h"
#import "PillNotificationManager.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "Preferences.h"

static NSString *CreatedKey = @"created";
static NSString *TreatmentStartKey = @"start";
static NSString *TreatmentEndKey = @"end";
static NSString *NextReminderKey = @"next";
static NSString *LastTakenKey = @"last";
static NSString *OverdueReminderKey = @"overdue";
static NSString *TakePillAfterKey = @"takePillAfter";
static NSString *SkipPillAfterKey = @"skipPillAfter";
static NSString *MaxPostponeTimeKey = @"maxPostponeTime";
static NSString *ArchivedKey = @"archived";
static NSString *InvisibleKey = @"invisible";
static NSString *RemindersDisabledKey = @"noPush";
static NSString *SecondaryRemindersKey = @"secondaryReminders";
static NSString *RefillAlertDosesKey = @"refillAlertDoses";
static NSString *ExpirationDateKey = @"expirationDate";
static NSString *ExpirationAlertKey = @"expirationAlertDays";

@implementation DrugReminder

@synthesize archived;
@synthesize invisible;
@synthesize refillAlertDoses;
@synthesize delegate;
@synthesize expirationDate;
@synthesize maxPostponeTime;
@synthesize skipPillAfter;
@synthesize takePillAfter;

- (id)init
{
	return [self init:nil
			  endDate:nil
		 nextReminder:nil
			lastTaken:nil
	  overdueReminder:nil
		takePillAfter:nil
		skipPillAfter:nil
	  maxPostponeTime:nil
             archived:NO
            invisible:NO
	 remindersEnabled:YES
secondaryRemindersEnabled:[[DataModel getInstance].apiFlags getFlag:DosecastAPIEnableSecondaryRemindersByDefault]
	 refillAlertDoses:0
       expirationDate:nil
  expirationAlertDays:0];
}

-(id)init:(NSDate*)startDate
        endDate:(NSDate*)endDate
   nextReminder:(NSDate*)next
	  lastTaken:(NSDate*)last
overdueReminder:(NSDate*)overdue
  takePillAfter:(NSDate*)takeAfter
  skipPillAfter:(NSDate*)skipAfter
maxPostponeTime:(NSDate*)maxPostpone
       archived:(BOOL)arch
invisible:(BOOL)inv
remindersEnabled:(BOOL)enabled
secondaryRemindersEnabled:(BOOL)secondaryEnabled
refillAlertDoses:(int)alertDoses
expirationDate:(NSDate*)expiration
expirationAlertDays:(int)expirationDays
{
    if ((self = [super init]))
    {
		if (startDate)
			treatmentStartDate = startDate;
		else
		{			
			// Force the treatment start time to midnight
			treatmentStartDate = [DosecastUtil getMidnightOnDate:[NSDate date]];
		}
		treatmentEndDate = endDate;
		
		if (treatmentEndDate && [treatmentEndDate timeIntervalSinceDate:treatmentStartDate] < 0)
		{
			// Force the treatment start time to midnight
			treatmentStartDate = [DosecastUtil getMidnightOnDate:treatmentEndDate];
		}

		nextReminder = [DosecastUtil removeSecondsFromDate:next];
		lastTaken = [DosecastUtil removeSecondsFromDate:last];
        overdueReminder = [DosecastUtil removeSecondsFromDate:overdue];
		takePillAfter = takeAfter;
		skipPillAfter = skipAfter;
		maxPostponeTime = maxPostpone;
        archived = arch;
        invisible = inv;
		remindersEnabled = enabled;
        secondaryRemindersEnabled = secondaryEnabled;
        if (alertDoses < 0)
            alertDoses = 0;
		refillAlertDoses = alertDoses;
        expirationDate = expiration;
        if (expirationDays < 0)
            expirationDays = 0;
        expirationAlertDays = expirationDays;
        delegate = nil;
	}
	return self;		
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[DrugReminder alloc] init:[treatmentStartDate copyWithZone:zone]
							  endDate:[treatmentEndDate copyWithZone:zone]
						 nextReminder:[nextReminder copyWithZone:zone]
							lastTaken:[self.lastTaken copyWithZone:zone]
					  overdueReminder:[overdueReminder copyWithZone:zone]
						takePillAfter:[takePillAfter copyWithZone:zone]
						skipPillAfter:[skipPillAfter copyWithZone:zone]
					  maxPostponeTime:[maxPostponeTime copyWithZone:zone]
                             archived:archived
                            invisible:invisible
					  remindersEnabled:remindersEnabled
            secondaryRemindersEnabled:secondaryRemindersEnabled
					 refillAlertDoses:refillAlertDoses
                       expirationDate:expirationDate
                  expirationAlertDays:expirationAlertDays];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
	// Calculate the treatmentStart value
	long long treatmentStartVal = -1;
	if (treatmentStartDate != nil)
	{
		treatmentStartVal = (long long)[treatmentStartDate timeIntervalSince1970];
	}
	[dict setObject:[NSNumber numberWithLongLong:treatmentStartVal] forKey:TreatmentStartKey];	
	
	// Calculate the treatmentEnd value
	long long treatmentEndVal = -1;
	if (treatmentEndDate != nil)
	{
		treatmentEndVal = (long long)[treatmentEndDate timeIntervalSince1970];
	}
	[dict setObject:[NSNumber numberWithLongLong:treatmentEndVal] forKey:TreatmentEndKey];	
	
	// Set whether the reminder is enabled
    [Preferences populatePreferenceInDictionary:dict key:ArchivedKey value:[NSString stringWithFormat:@"%d", (archived ? 1 : 0)] modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:InvisibleKey value:[NSString stringWithFormat:@"%d", (invisible ? 1 : 0)] modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:RemindersDisabledKey value:[NSString stringWithFormat:@"%d", (remindersEnabled ? 0 : 1)] modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:SecondaryRemindersKey value:[NSString stringWithFormat:@"%d", (secondaryRemindersEnabled ? 1 : 0)] modifiedDate:nil perDevice:NO];

    [Preferences populatePreferenceInDictionary:dict key:RefillAlertDosesKey value:[NSString stringWithFormat:@"%d", refillAlertDoses] modifiedDate:nil perDevice:NO];
    
    long long expirationDateVal = -1;
    if (expirationDate != nil)
        expirationDateVal = (long long)[expirationDate timeIntervalSince1970];
    
    [Preferences populatePreferenceInDictionary:dict key:ExpirationDateKey value:[NSString stringWithFormat:@"%lld", expirationDateVal] modifiedDate:nil perDevice:NO];

    [Preferences populatePreferenceInDictionary:dict key:ExpirationAlertKey value:[NSString stringWithFormat:@"%d", expirationAlertDays] modifiedDate:nil perDevice:NO];
    
    if (!forSyncRequest)
	{
		// Calculate the nextReminder value
		long long nextReminderVal = -1;
		if (nextReminder != nil)
		{
			nextReminderVal = (long long)[nextReminder timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:nextReminderVal] forKey:NextReminderKey];
		
		// Calculate the lastTaken value
		long long lastTakenVal = -1;
		if (self.lastTaken != nil)
		{
			lastTakenVal = (long long)[self.lastTaken timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:lastTakenVal] forKey:LastTakenKey];
		
		// Calculate the overdueReminder value
		long long overdueReminderVal = -1;
		if (overdueReminder != nil)
		{
			overdueReminderVal = (long long)[overdueReminder timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:overdueReminderVal] forKey:OverdueReminderKey];
		
		// Calculate the takePillAfter value
		long long takePillAfterVal = -1;
		if (takePillAfter != nil)
		{
			takePillAfterVal = (long long)[takePillAfter timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:takePillAfterVal] forKey:TakePillAfterKey];
		
		// Calculate the skipPillAfter value
		long long skipPillAfterVal = -1;
		if (skipPillAfter != nil)
		{
			skipPillAfterVal = (long long)[skipPillAfter timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:skipPillAfterVal] forKey:SkipPillAfterKey];
		
		// Calculate the maxPostponeTime value
		long long maxPostponeTimeVal = -1;
		if (maxPostponeTime != nil)
		{
			maxPostponeTimeVal = (long long)[maxPostponeTime timeIntervalSince1970];
		}
		[dict setObject:[NSNumber numberWithLongLong:maxPostponeTimeVal] forKey:MaxPostponeTimeKey];		
	}
}

// Get the time this drug may be postponed from
- (NSDate*)getBasePostponeTime
{
	if (self.overdueReminder != nil)
		return [NSDate date];
	else if (nextReminder != nil)
		return nextReminder;
	else
		return nil;
}

// Update this reminder from the given server state
- (void) updateReminderStateWithLastTaken:(NSDate*)last
                             effLastTaken:(NSDate*)effLastTaken
                              notifyAfter:(NSDate*)notifyAfter
{
}

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date
{
	return NO;
}

// Returns whether this treatment has started
- (BOOL)treatmentStarted
{
	// Let's say the treatment has started if we're within 1 day of the actual start
	NSDate* tomorrow = [DosecastUtil addDaysToDate:[NSDate date] numDays:1];
	return ([treatmentStartDate timeIntervalSinceDate:tomorrow] < 0);
}

// Returns whether this treatment has ended
- (BOOL)treatmentEnded
{
	return (treatmentEndDate && [treatmentEndDate timeIntervalSinceNow] < 0);
}

// Returns whether the treatment has started on the given day
- (BOOL)treatmentStartedOnDay:(NSDate*)day
{
	// Let's say the treatment has started if the schedule day is within 1 day of the actual start
	NSDate* tomorrow = [DosecastUtil addDaysToDate:day numDays:1];
	return ([treatmentStartDate timeIntervalSinceDate:tomorrow] < 0);
}

// Returns whether this treatment has ended on the given day
- (BOOL)treatmentEndedOnDay:(NSDate*)day
{
	return (treatmentEndDate && [treatmentEndDate timeIntervalSinceDate:day] < 0);
}

// Returns an array of NSDates representing the times of future doses due on the given day
- (NSArray*) getFutureDoseTimesDueOnDay:(NSDate*)day
{
    return [[NSArray alloc] init];
}

// Returns an array of NSDates representing the times of past doses due on the given day
- (NSArray*) getPastDoseTimesDueOnDay:(NSDate*)day
{
    return [[NSArray alloc] init];    
}

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed
{
    return 0;
}

+ (void)readFromDictionary:(NSMutableDictionary*)dict
		treatmentStartDate:(NSDate**)startDate
		  treatmentEndDate:(NSDate**)endDate
			  nextReminder:(NSDate**)next
				 lastTaken:(NSDate**)last
		   overdueReminder:(NSDate**)overdue
			 takePillAfter:(NSDate**)takeAfter
			 skipPillAfter:(NSDate**)skipAfter
		   maxPostponeTime:(NSDate**)maxPostpone
                  archived:(BOOL*)arch
                 invisible:(BOOL*)inv
		   remindersEnabled:(BOOL*)enabled
 secondaryRemindersEnabled:(BOOL*)secondaryEnabled
		  refillAlertDoses:(int*)alertDoses
            expirationDate:(NSDate**)expiration
       expirationAlertDays:(int*)expirationDays;
{
	// Set the treatmentStartDate value
	*startDate = nil;
	NSNumber* treatmentStartNum = [dict objectForKey:TreatmentStartKey];
	if (treatmentStartNum && [treatmentStartNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*startDate = [NSDate dateWithTimeIntervalSince1970:[treatmentStartNum longLongValue]];
	}
	else
	{
		NSNumber* createdNum = [dict objectForKey:CreatedKey];
		if (createdNum && [createdNum longLongValue] > 0)
		{
			// Convert to NSDate from UNIX time
			NSDate* created = [NSDate dateWithTimeIntervalSince1970:[createdNum longLongValue]];
						
			// Force the time to midnight
			*startDate = [DosecastUtil getMidnightOnDate:created];
		}
	}
	
	// Set the treatmentEndDate value
	*endDate = nil;
	NSNumber* treatmentEndNum = [dict objectForKey:TreatmentEndKey];
	if (treatmentEndNum && [treatmentEndNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*endDate = [NSDate dateWithTimeIntervalSince1970:[treatmentEndNum longLongValue]];
	}
	
	// Set the nextReminder value
	*next = nil;
	NSNumber* nextReminderNum = [dict objectForKey:NextReminderKey];
	if (nextReminderNum && [nextReminderNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*next = [NSDate dateWithTimeIntervalSince1970:[nextReminderNum longLongValue]];
	}
	
	// Set the lastTaken value
	*last = nil;
	NSNumber* lastTakenNum = [dict objectForKey:LastTakenKey];
	if (lastTakenNum && [lastTakenNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*last = [NSDate dateWithTimeIntervalSince1970:[lastTakenNum longLongValue]];
	}
	
	// Set the overdueReminder value
	*overdue = nil;
	NSNumber* overdueReminderNum = [dict objectForKey:OverdueReminderKey];
	if (overdueReminderNum && [overdueReminderNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*overdue = [NSDate dateWithTimeIntervalSince1970:[overdueReminderNum longLongValue]];
	}
	
	// Set the takePillAfter value
	*takeAfter = nil;
	NSNumber* takePillAfterNum = [dict objectForKey:TakePillAfterKey];
	if (takePillAfterNum && [takePillAfterNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*takeAfter = [NSDate dateWithTimeIntervalSince1970:[takePillAfterNum longLongValue]];
	}
	
	// Set the skipPillAfter value
	*skipAfter = nil;
	NSNumber* skipPillAfterNum = [dict objectForKey:SkipPillAfterKey];
	if (skipPillAfterNum && [skipPillAfterNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*skipAfter = [NSDate dateWithTimeIntervalSince1970:[skipPillAfterNum longLongValue]];
	}
	
	// Set the maxPostponeTime value
	*maxPostpone = nil;
	NSNumber* maxPostponeTimeNum = [dict objectForKey:MaxPostponeTimeKey];
	if (maxPostponeTimeNum && [maxPostponeTimeNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		*maxPostpone = [NSDate dateWithTimeIntervalSince1970:[maxPostponeTimeNum longLongValue]];
	}
	    
	// Set the remindersEnabled, secondaryRemindersEnabled, and refillAlertDoses values
	*enabled = YES;
    *secondaryEnabled = [[DataModel getInstance].apiFlags getFlag:DosecastAPIEnableSecondaryRemindersByDefault];
	*alertDoses = 0;
    *arch = NO;
    *inv = NO;
    *expirationDays = 0;
    *expiration = nil;

    NSString* archivedStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:ArchivedKey value:&archivedStr modifiedDate:nil perDevice:nil];
    if (archivedStr)
    {
        int archivedInt = [archivedStr intValue];
        *arch = (archivedInt == 1 ? YES : NO);
    }
    NSString* invisibleStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:InvisibleKey value:&invisibleStr modifiedDate:nil perDevice:nil];
    if (invisibleStr)
    {
        int invisibleInt = [invisibleStr intValue];
        *inv = (invisibleInt == 1 ? YES : NO);
    }
    NSString* noPushStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:RemindersDisabledKey value:&noPushStr modifiedDate:nil perDevice:nil];
    if (noPushStr)
    {
        int noPushInt = [noPushStr intValue];
        *enabled = (noPushInt == 0 ? YES : NO);
    }
    NSString* secondaryRemindersStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:SecondaryRemindersKey value:&secondaryRemindersStr modifiedDate:nil perDevice:nil];
    if (secondaryRemindersStr)
    {
        int secondaryRemindersInt = [secondaryRemindersStr intValue];
        *secondaryEnabled = (secondaryRemindersInt == 1 ? YES : NO);
    }
    NSString* refillAlertDosesStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:RefillAlertDosesKey value:&refillAlertDosesStr modifiedDate:nil perDevice:nil];
    if (refillAlertDosesStr && [refillAlertDosesStr length] > 0)
        *alertDoses = [refillAlertDosesStr intValue];
    
    NSString* expirationDateStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:ExpirationDateKey value:&expirationDateStr modifiedDate:nil perDevice:nil];
    if (expirationDateStr && [expirationDateStr longLongValue] > 0)
    {
        *expiration = [NSDate dateWithTimeIntervalSince1970:[expirationDateStr longLongValue]];
    }

    NSString* expirationDaysStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:ExpirationAlertKey value:&expirationDaysStr modifiedDate:nil perDevice:nil];
    if (expirationDaysStr && [expirationDaysStr length] > 0)
        *expirationDays = [expirationDaysStr intValue];
}

- (BOOL)canTakeDose
{
	return (!archived && !invisible && [self treatmentStarted] && ![self treatmentEnded] &&
            (!delegate || [delegate allowUserActions]) &&
			(!takePillAfter || [takePillAfter timeIntervalSinceNow] <= 0));
}

- (BOOL)canSkipDose
{
	return (!archived && !invisible && [self treatmentStarted] && ![self treatmentEnded] &&
            (!delegate || [delegate allowUserActions]) &&
			(!skipPillAfter || [skipPillAfter timeIntervalSinceNow] <= 0));
}

- (BOOL)wasTakenEarly
{
	return (takePillAfter && [takePillAfter timeIntervalSinceNow] > 0); 
}

- (BOOL)wasSkippedEarly
{
	return (skipPillAfter && [skipPillAfter timeIntervalSinceNow] > 0); 
}

- (BOOL)canPostponeDose
{
	NSDate* basePostponeTime = [self getBasePostponeTime];
	
	// Find allowable postpone duration, rounded to nearest postpone increment
	BOOL canPostpone = YES;
	int minimumPostponePeriod = [[PillNotificationManager getInstance] minimumPostponePeriodMin];
	if (maxPostponeTime && basePostponeTime)
	{
		int allowablePostponeDurationMin = [maxPostponeTime timeIntervalSinceDate:basePostponeTime]/60;
		allowablePostponeDurationMin = (allowablePostponeDurationMin / minimumPostponePeriod) * minimumPostponePeriod;
		canPostpone = (allowablePostponeDurationMin > minimumPostponePeriod);		
	}	

	return (!archived && !invisible && [self treatmentStarted] && ![self treatmentEnded] && canPostpone &&
            (!delegate || [delegate allowUserActions]));
}

- (NSDate*)treatmentStartDate {
	return treatmentStartDate;
}

- (NSDate*)treatmentEndDate {
	return treatmentEndDate;
}

- (NSDate*)overdueReminder {
	// Don't return the overdueReminder value if reminders are disabled. This will avoid treating
	// the drug as if reminders are being sent
	if (self.remindersEnabled)
		return overdueReminder;
	else
		return nil;
}

- (void)setTreatmentStartDate:(NSDate*)d
{
	treatmentStartDate = d;
	
	if (!treatmentStartDate)
	{
		// Force the time to midnight
		treatmentStartDate = [DosecastUtil getMidnightOnDate:[NSDate date]];
	}
	
	if (treatmentEndDate && [treatmentEndDate timeIntervalSinceDate:treatmentStartDate] < 0)
	{
		// Force the time to midnight
		treatmentStartDate = [DosecastUtil getMidnightOnDate:treatmentEndDate];
	}
	
}

- (void)setTreatmentEndDate:(NSDate*)d
{	
	treatmentEndDate = d;
	
	if (treatmentEndDate && [treatmentEndDate timeIntervalSinceDate:treatmentStartDate] < 0)
	{
		// Get the components for the treatment start date and force the time to the last second
		treatmentEndDate = [DosecastUtil getLastSecondOnDate:treatmentStartDate];			
	}
	
}

- (BOOL) remindersEnabled
{
    if (archived || invisible || (delegate && ![delegate allowUserActions]))
        return NO;
    else
        return remindersEnabled;
}

- (void) setRemindersEnabled:(BOOL)enabled
{
    remindersEnabled = enabled;
}

- (BOOL) secondaryRemindersEnabled
{
    if (archived || invisible || (delegate && ![delegate allowUserActions]))
        return NO;
    else
        return secondaryRemindersEnabled;
}

- (void) setSecondaryRemindersEnabled:(BOOL)enabled
{
    secondaryRemindersEnabled = enabled;
}

- (void)setOverdueReminder:(NSDate *)d
{
    overdueReminder = [DosecastUtil removeSecondsFromDate:d];
}

- (void)setNextReminder:(NSDate *)next
{
    nextReminder = [DosecastUtil removeSecondsFromDate:next];
}

- (NSDate*)nextReminder
{
    return nextReminder;
}

-(void) setLastTaken:(NSDate *)last
{
    lastTaken = [DosecastUtil removeSecondsFromDate:last];
}

- (NSDate*)lastTaken
{
    return lastTaken;
}

// For future times that lie across a daylight savings boundary, unapply the daylight savings period 
- (void) unapplyDaylightSavingsToFutureTimesAcrossDaylightSavingsBoundary
{    
	NSTimeZone* timeZone = [NSTimeZone localTimeZone];
	NSDate* now = [NSDate date];

	if (self.nextReminder)
	{
		if ([timeZone isDaylightSavingTime] && ![timeZone isDaylightSavingTimeForDate:self.nextReminder])
			self.nextReminder = [DosecastUtil addTimeIntervalToDate:self.nextReminder timeInterval:[timeZone daylightSavingTimeOffset]];
		else if (![timeZone isDaylightSavingTime] && [timeZone isDaylightSavingTimeForDate:self.nextReminder])
			self.nextReminder = [DosecastUtil addTimeIntervalToDate:self.nextReminder timeInterval:-[timeZone daylightSavingTimeOffsetForDate:self.nextReminder]];
	}
	
	if (self.maxPostponeTime)
	{
		if ([timeZone isDaylightSavingTime] && ![timeZone isDaylightSavingTimeForDate:self.maxPostponeTime])
			self.maxPostponeTime = [DosecastUtil addTimeIntervalToDate:self.maxPostponeTime timeInterval:[timeZone daylightSavingTimeOffset]];
		else if (![timeZone isDaylightSavingTime] && [timeZone isDaylightSavingTimeForDate:self.maxPostponeTime])
			self.maxPostponeTime = [DosecastUtil addTimeIntervalToDate:self.maxPostponeTime timeInterval:-[timeZone daylightSavingTimeOffsetForDate:self.maxPostponeTime]];
	}
	
	if (self.skipPillAfter && [self.skipPillAfter timeIntervalSince1970] > 1 && [now timeIntervalSinceDate:self.skipPillAfter] >= 0)
	{
		if ([timeZone isDaylightSavingTime] && ![timeZone isDaylightSavingTimeForDate:self.skipPillAfter])
			self.skipPillAfter = [DosecastUtil addTimeIntervalToDate:self.skipPillAfter timeInterval:[timeZone daylightSavingTimeOffset]];
		else if (![timeZone isDaylightSavingTime] && [timeZone isDaylightSavingTimeForDate:self.skipPillAfter])
			self.skipPillAfter = [DosecastUtil addTimeIntervalToDate:self.skipPillAfter timeInterval:-[timeZone daylightSavingTimeOffsetForDate:self.skipPillAfter]];				
	}
	
	if (self.takePillAfter && [self.takePillAfter timeIntervalSince1970] > 1 && [now timeIntervalSinceDate:self.takePillAfter] >= 0)
	{
		if ([timeZone isDaylightSavingTime] && ![timeZone isDaylightSavingTimeForDate:self.takePillAfter])
			self.takePillAfter = [DosecastUtil addTimeIntervalToDate:self.takePillAfter timeInterval:[timeZone daylightSavingTimeOffset]];
		else if (![timeZone isDaylightSavingTime] && [timeZone isDaylightSavingTimeForDate:self.takePillAfter])
			self.takePillAfter = [DosecastUtil addTimeIntervalToDate:self.takePillAfter timeInterval:-[timeZone daylightSavingTimeOffsetForDate:self.takePillAfter]];				
	}				
}

// Returns an array of strings that describe the refill alert options
- (NSArray*) getRefillAlertOptions
{
	return nil;
}

- (BOOL)wasPostponed:(int*)postponeDuration
{
    if (postponeDuration)
        *postponeDuration = 0;
    return NO;
}

// If overdue, returns the last scheduled dose time (prior to any postpones).
// If not overdue, returns the next scheduled dose time (prior to any postpones).
- (NSDate*) getCurrentScheduledTime
{
    return nil;
}

- (NSDate*) getCurrentScheduledTimeFromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)thisLastTaken
{
    return nil;
}

// Returns the index of the current refill alert option
- (int) getRefillAlertOptionNum
{
	return -1;
}

// Sets the index of the current refill alert option
- (BOOL) setRefillAlertOptionNum:(int)optionNum
{
	return NO;
}

// Returns an array of strings that describe the expiration alert options
- (NSArray*) getExpirationAlertOptions
{
    return [NSArray arrayWithObjects:
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert1Day", @"Dosecast", [DosecastUtil getResourceBundle], @"1 day before expiration", @"The expiration alert option for 1 day before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert3Days", @"Dosecast", [DosecastUtil getResourceBundle], @"3 days before expiration", @"The expiration alert option for 3 days before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert1Week", @"Dosecast", [DosecastUtil getResourceBundle], @"1 week before expiration", @"The expiration alert option for 1 week before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert2Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"2 weeks before expiration", @"The expiration alert option for 2 weeks before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert3Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"3 weeks before expiration", @"The expiration alert option for 3 weeks before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert4Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"4 weeks before expiration", @"The expiration alert option for 4 weeks before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert8Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"8 weeks before expiration", @"The expiration alert option for 8 weeks before empty"])],
            nil];
}

// Returns the index of the current expiration alert option
- (int) getExpirationAlertOptionNum
{
    if (expirationAlertDays == 1)
		return 0;
	else if (expirationAlertDays == 3)
		return 1;
	else if (expirationAlertDays == 7)
		return 2;
	else if (expirationAlertDays == 14)
		return 3;
	else if (expirationAlertDays == 21)
		return 4;
	else if (expirationAlertDays == 28)
		return 5;
	else if (expirationAlertDays == 56)
		return 6;
	else
		return -1;
}

// Sets the index of the current expiration alert option
- (BOOL) setExpirationAlertOptionNum:(int)optionNum
{
   	if (optionNum == 0)
	{
		expirationAlertDays = 1;
		return YES;
	}
	else if (optionNum == 1)
	{
		expirationAlertDays = 3;
		return YES;
	}
	else if (optionNum == 2)
	{
		expirationAlertDays = 7;
		return YES;
	}
	else if (optionNum == 3)
	{
		expirationAlertDays = 14;
		return YES;
	}
	else if (optionNum == 4)
	{
		expirationAlertDays = 21;
		return YES;
	}
	else if (optionNum == 5)
	{
		expirationAlertDays = 28;
		return YES;
	}
	else if (optionNum == 6)
	{
		expirationAlertDays = 56;
		return YES;
	}
	else if (optionNum == -1)
	{
		expirationAlertDays = 0;
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL) isExpiringSoon // is the expiration date approaching (and an alert should be displayed)
{
    if (!expirationDate || expirationAlertDays == 0)
        return NO;

    NSDate* morningToday = [DosecastUtil getMidnightOnDate:[NSDate date]];
    NSDate* morningOnExpirationDate = [DosecastUtil getMidnightOnDate:expirationDate];
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

    NSDateComponents *componentsFromTodayToExpiration = [cal components:NSDayCalendarUnit fromDate:morningToday toDate:morningOnExpirationDate options:0];
    int daysFromTodayToExpiration = (int)[componentsFromTodayToExpiration day];
    return (daysFromTodayToExpiration <= expirationAlertDays);
}

- (BOOL) isExpired // has the expiration date already passed
{
    if (!expirationDate)
        return NO;
    const float epsilon = 0.0001;
    
    NSDate* morningToday = [DosecastUtil getMidnightOnDate:[NSDate date]];
    NSDate* morningOnExpirationDate = [DosecastUtil getMidnightOnDate:expirationDate];
    return ([morningToday timeIntervalSinceDate:morningOnExpirationDate] > -epsilon);
}


// Adjusts the reminders for a time zone change
- (void)adjustRemindersForTimeZoneChange:(NSTimeInterval)timeZoneInterval
{
    if (self.treatmentStartDate && [self.treatmentStartDate timeIntervalSinceNow] > 0)
        self.treatmentStartDate = [DosecastUtil addTimeIntervalToDate:self.treatmentStartDate timeInterval:timeZoneInterval];
    if (self.treatmentEndDate && [self.treatmentEndDate timeIntervalSinceNow] > 0)
        self.treatmentEndDate = [DosecastUtil addTimeIntervalToDate:self.treatmentEndDate timeInterval:timeZoneInterval];
}


@end