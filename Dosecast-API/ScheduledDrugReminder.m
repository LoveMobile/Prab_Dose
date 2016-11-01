//
//  ScheduledDrugReminder.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "ScheduledDrugReminder.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "HistoryManager.h"
#import "GlobalSettings.h"
#import "Preferences.h"

static NSString *ReminderTypeKey = @"type";
static NSString *ScheduledDrugReminderKey = @"schedule";
static NSString *ScheduledDrugFrequencyKey = @"dayperiod";
static NSString *ScheduledReminderTypeName = @"scheduled";
static NSString *ScheduledDrugLogMissedDosesKey = @"logMissedDoses";
static NSString *ScheduledDrugWeekdaysKey = @"weekdays";

static int NUM_PERIODS_CONVERSION_FOR_REPEATING_CUSTOM_LOCAL_NOTIFICATION = 3; // How many periods a repeating, custom local notification will get expanded to

@implementation ScheduledDrugReminder

@synthesize reminderTimes;

// Sets the weekdays array to the treatment start date
- (void) setWeekdaysToTreatmentStartDate
{
    weekdays = nil;
    
    if (self.treatmentStartDate)
    {
        // Find the weekday for the provided date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSWeekdayCalendarUnit;
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:self.treatmentStartDate];
        int weekday = (int)[timeComponents weekday];
        weekdays = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:weekday], nil];
    }
}

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
  expirationAlertDays:0
		reminderTimes:nil
			frequency:ScheduledDrugFrequencyDaily
             weekdays:nil
   customFrequencyNum:-1
customFrequencyPeriod:ScheduledDrugFrequencyCustomPeriodNone
       logMissedDoses:YES];
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
         reminderTimes:(NSArray*)times
	         frequency:(ScheduledDrugFrequency)freq
              weekdays:(NSArray*)wkdays
    customFrequencyNum:(int)customNum
 customFrequencyPeriod:(ScheduledDrugFrequencyCustomPeriod)customPeriod
        logMissedDoses:(BOOL)logMissed
{
    if ((self = [super init:startDate
				  endDate:endDate
			 nextReminder:next
				lastTaken:last
		  overdueReminder:overdue
			takePillAfter:takeAfter
			skipPillAfter:skipAfter
		  maxPostponeTime:maxPostpone
                 archived:arch
                  invisible:inv
		  remindersEnabled:enabled
  secondaryRemindersEnabled:secondaryEnabled
		 refillAlertDoses:alertDoses
                 expirationDate:expiration
        expirationAlertDays:expirationDays]))
    {
		reminderTimes = [[NSMutableArray alloc] initWithArray:times];
		frequency = freq;
        customFrequencyNum = customNum;
        customFrequencyPeriod = customPeriod;
        logMissedDoses = logMissed;
        weekdays = wkdays;
        timeZoneChanged = NO;
        
        // Set a default set of weekdays.
        if (frequency == ScheduledDrugFrequencyWeekly && !weekdays)
            [self setWeekdaysToTreatmentStartDate];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleTimeZoneChange:)
                                                     name:NSSystemTimeZoneDidChangeNotification
                                                   object:nil];
        
	}
	return self;		
}

// Returns the earliest a reminder can be scheduled for
- (NSDate*)getReminderLimitForTreatmentStartDate
{
    NSDate* earliestDate = nil;
    if (delegate && [delegate respondsToSelector:@selector(created)])
        earliestDate = [delegate created];
    if (!earliestDate || (self.treatmentStartDate && [earliestDate timeIntervalSinceDate:self.treatmentStartDate] < 0))
    {
        earliestDate = [self.treatmentStartDate dateByAddingTimeInterval:-1]; // Allow a reminder to be scheduled on the start date for weekly/monthly reminders, so subtract 1 s
    }
    return earliestDate;
}

- (void) updateReminderStateWithLastTaken:(NSDate*)last
                             effLastTaken:(NSDate*)effLastTaken
                              notifyAfter:(NSDate*)notifyAfter
{
    self.lastTaken = last;
    self.overdueReminder = nil;
    self.nextReminder = nil;
    self.skipPillAfter = nil;
    self.maxPostponeTime = nil;
    self.takePillAfter = nil;

    if (effLastTaken)
    {
        if ([effLastTaken timeIntervalSinceNow] < 0)
        {
            NSDate* nextRemind = [self getReminderTimeAfterTime:effLastTaken remindAtLimit:NO];
            if (nextRemind && [nextRemind timeIntervalSinceNow] < 0)
            {
                if (notifyAfter)
                {
                    if ([notifyAfter timeIntervalSinceNow] < 0)
                    {
                        self.overdueReminder = notifyAfter;
                        self.nextReminder = [self getReminderTimeAfterTime:notifyAfter remindAtLimit:NO];
                    }
                    else
                        self.nextReminder = notifyAfter;
                }
                else
                {
                    self.overdueReminder = nextRemind;
                    self.nextReminder = [self getReminderTimeAfterTime:nextRemind remindAtLimit:NO];
                }
                self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
                self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
            }
            else if (nextRemind && [nextRemind timeIntervalSinceNow] > 0)
            {
                if (notifyAfter && [notifyAfter timeIntervalSinceNow] > 0)
                    self.nextReminder = notifyAfter;
                else
                    self.nextReminder = nextRemind;
                self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
                self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
            }
        }
        else
        {
            if (notifyAfter && [notifyAfter timeIntervalSinceNow] > 0)
                self.nextReminder = notifyAfter;
            else
                self.nextReminder = [self getReminderTimeAfterTime:effLastTaken remindAtLimit:NO];
            self.takePillAfter = effLastTaken;
            self.skipPillAfter = effLastTaken;
        }
    }
    else if (notifyAfter)
    {
        if ([notifyAfter timeIntervalSinceNow] < 0)
        {
            self.overdueReminder = notifyAfter;
            self.nextReminder = [self getReminderTimeAfterTime:notifyAfter remindAtLimit:NO];
        }
        else
            self.nextReminder = notifyAfter;
        self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
    }
    else if (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0)
    {
        NSDate* beginDate = [self getReminderLimitForTreatmentStartDate];
        if (beginDate && self.lastTaken && [beginDate timeIntervalSinceDate:self.lastTaken] < 0)
            beginDate = self.lastTaken;

        NSDate* nextRemind = [self getReminderTimeAfterTime:beginDate remindAtLimit:NO];
        if (nextRemind && [nextRemind timeIntervalSinceNow] < 0)
        {
            self.overdueReminder = nextRemind;
            self.nextReminder = [self getReminderTimeAfterTime:nextRemind remindAtLimit:NO];
            self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
            self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        }
        else if (nextRemind && [nextRemind timeIntervalSinceNow] > 0)
        {
            self.nextReminder = nextRemind;
            self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
            self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        }
    }
        
    if (self.nextReminder)
        self.maxPostponeTime = [self getReminderTimeAfterTime:self.nextReminder remindAtLimit:YES];
}

- (id)initWithDictionary:(NSMutableDictionary*) dict
{
	NSDate* startDate;
	NSDate* endDate;
	NSDate* next;
	NSDate* last;
	NSDate* overdue;
	NSDate* takeAfter;
	NSDate* skipAfter;
	NSDate* maxPostpone;
    NSDate* expiration;
    BOOL arch;
    BOOL inv;
	BOOL enabled;
    BOOL secondaryEnabled;
	int alertDoses;
    int expirationDays;
	
	[DrugReminder readFromDictionary:dict
				  treatmentStartDate:&startDate
					treatmentEndDate:&endDate
						nextReminder:&next
						   lastTaken:&last
					 overdueReminder:&overdue
					   takePillAfter:&takeAfter
					   skipPillAfter:&skipAfter
					 maxPostponeTime:&maxPostpone
                            archived:&arch
                           invisible:&inv
					 remindersEnabled:&enabled
           secondaryRemindersEnabled:&secondaryEnabled
					refillAlertDoses:&alertDoses
                      expirationDate:&expiration
                 expirationAlertDays:&expirationDays];
	
	NSMutableArray* times = nil;
	
	// Calculate GMT offset
	NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
	NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];
		
	NSMutableArray* scheduleNumbersGMT = [dict objectForKey:ScheduledDrugReminderKey];
	if (scheduleNumbersGMT)
	{
		times = [[NSMutableArray alloc] init];
		for (int i = 0; i < [scheduleNumbersGMT count]; i++)
		{
			NSNumber* timeNumGMT = [scheduleNumbersGMT objectAtIndex:i];
			if (timeNumGMT && [timeNumGMT intValue] >= 0)
			{
				// Convert from GMT
				NSDate* timeLocal = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:[timeNumGMT intValue]] timeInterval:secondsFromGMT];
				int timeNumLocal = [DosecastUtil getDateAs24hrTime:timeLocal];
				[times addObject:[NSNumber numberWithInt:timeNumLocal]];						
			}
		}
		// Sort results
		[times sortUsingSelector:@selector(compare:)];		
	}	
	
    int customFreqNum = -1;
    ScheduledDrugFrequencyCustomPeriod customFreqPeriod = ScheduledDrugFrequencyCustomPeriodNone;
    ScheduledDrugFrequency freq = ScheduledDrugFrequencyDaily;
    BOOL logMissed = YES;
    NSArray* wkdays = nil;
    
    // Get the frequency
    NSNumber* frequencyNum = [dict objectForKey:ScheduledDrugFrequencyKey];
    int localFrequency = [frequencyNum intValue];
    if (localFrequency == (int)ScheduledDrugFrequencyDaily)
        freq = ScheduledDrugFrequencyDaily;
    else if (localFrequency == (int)ScheduledDrugFrequencyWeekly)
        freq = ScheduledDrugFrequencyWeekly;
    else if (localFrequency == (int)ScheduledDrugFrequencyMonthly || localFrequency == 31) // ******** temporary hack in case we get '31' from Android, which means monthly. This needs to be harmonized
        freq = ScheduledDrugFrequencyMonthly;
    else
    {
        freq = ScheduledDrugFrequencyCustom;
        if (localFrequency % 7 == 0)
        {
            customFreqPeriod = ScheduledDrugFrequencyCustomPeriodWeeks;
            customFreqNum = localFrequency / 7;
        }
        else
        {
            customFreqPeriod = ScheduledDrugFrequencyCustomPeriodDays;
            customFreqNum = localFrequency;
        }
    }
        
    NSString* logMissedDosesStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:ScheduledDrugLogMissedDosesKey value:&logMissedDosesStr modifiedDate:nil perDevice:nil];
    if (logMissedDosesStr)
        logMissed = ([logMissedDosesStr intValue] == 1);
    
    NSString* wkdaysStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:ScheduledDrugWeekdaysKey value:&wkdaysStr modifiedDate:nil perDevice:nil];
    if (wkdaysStr && [wkdaysStr length] > 0)
    {
        NSArray* wkdaysStrArray = [wkdaysStr componentsSeparatedByString:@","];
        NSMutableArray* wkdaysNumArray = [[NSMutableArray alloc] init];
        for (NSString* weekdayStr in wkdaysStrArray)
        {
            [wkdaysNumArray addObject:[NSNumber numberWithInt:[weekdayStr intValue]]];
        }
        wkdays = wkdaysNumArray;
    }
    
	 return [self init:startDate
			   endDate:endDate
		  nextReminder:next
			 lastTaken:last
	   overdueReminder:overdue
		 takePillAfter:takeAfter
		 skipPillAfter:skipAfter
	   maxPostponeTime:maxPostpone
             archived:arch
             invisible:inv
      remindersEnabled:enabled
secondaryRemindersEnabled:secondaryEnabled
	  refillAlertDoses:alertDoses
             expirationDate:expiration
        expirationAlertDays:expirationDays
		 reminderTimes:times
	 		 frequency:freq
              weekdays:wkdays
    customFrequencyNum:customFreqNum
 customFrequencyPeriod:customFreqPeriod
        logMissedDoses:logMissed];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[ScheduledDrugReminder alloc] init:[self.treatmentStartDate copyWithZone:zone]
									   endDate:[self.treatmentEndDate copyWithZone:zone]
								  nextReminder:[self.nextReminder copyWithZone:zone]
									 lastTaken:[self.lastTaken copyWithZone:zone]
							   overdueReminder:[self.overdueReminder copyWithZone:zone]
								 takePillAfter:[self.takePillAfter copyWithZone:zone]
								 skipPillAfter:[self.skipPillAfter copyWithZone:zone]
							   maxPostponeTime:[self.maxPostponeTime copyWithZone:zone]
                                      archived:archived
                                     invisible:invisible
							   remindersEnabled:remindersEnabled
                     secondaryRemindersEnabled:secondaryRemindersEnabled
							  refillAlertDoses:refillAlertDoses
                                expirationDate:self.expirationDate
                           expirationAlertDays:expirationAlertDays
								 reminderTimes:[reminderTimes mutableCopyWithZone:zone]
									 frequency:frequency
                                      weekdays:[weekdays mutableCopyWithZone:zone]
                            customFrequencyNum:customFrequencyNum
                         customFrequencyPeriod:customFrequencyPeriod
                                logMissedDoses:logMissedDoses];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
	[super populateDictionary:dict forSyncRequest:forSyncRequest];
	
	[dict setObject:[NSString stringWithString:ScheduledReminderTypeName] forKey:ReminderTypeKey];
	
	// Calculate GMT offset
	NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
	NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];
		
	// Calcuate GMT version of schedule times
	NSMutableArray* scheduleNumbersGMT = [[NSMutableArray alloc] init];	
	for (int i = 0; i < [reminderTimes count]; i++)
	{
		NSNumber* timeNumLocal = [reminderTimes objectAtIndex:i];
		
		// Convert to GMT
		NSDate* timeLocalGMT = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:[timeNumLocal intValue]] timeInterval:-secondsFromGMT];
		int timeNumGMT = [DosecastUtil getDateAs24hrTime:timeLocalGMT];
		
		[scheduleNumbersGMT addObject:[NSNumber numberWithInt:timeNumGMT]];				
	}
	[dict setObject:scheduleNumbersGMT forKey:ScheduledDrugReminderKey];	
	
	// Set the frequency
    int frequencyToWrite = 0;
    if (frequency == ScheduledDrugFrequencyDaily || frequency == ScheduledDrugFrequencyWeekly)
        frequencyToWrite = (int)frequency;
    else if (frequency == ScheduledDrugFrequencyMonthly)
        frequencyToWrite = 31; // ******** temporary hack to send '31' to Android, which means monthly. This needs to be harmonized
    else if (frequency == ScheduledDrugFrequencyCustom)
    {
        frequencyToWrite = customFrequencyNum;
        if (customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodWeeks)
            frequencyToWrite *= 7;
    }
	NSNumber* frequencyNum = [NSNumber numberWithInt:(int)frequencyToWrite];
	[dict setObject:frequencyNum forKey:ScheduledDrugFrequencyKey];
    
    // Set the logMissedDoses flag
    NSString* logMissedDosesStr = [NSString stringWithFormat:@"%d", (logMissedDoses ? 1 : 0)];
    [Preferences populatePreferenceInDictionary:dict key:ScheduledDrugLogMissedDosesKey value:logMissedDosesStr modifiedDate:nil perDevice:NO];
    
    // Set the list of weekdays encoded in string form
    NSMutableString* weekdaysStr = [NSMutableString stringWithString:@""];
    if (weekdays && [weekdays count] > 0)
    {
        int numWeekdays = (int)[weekdays count];
        for (int i = 0; i < numWeekdays; i++)
        {
            NSNumber* weekdayNum = [weekdays objectAtIndex:i];
            if (i != 0)
                [weekdaysStr appendString:@","];
            [weekdaysStr appendString:[NSString stringWithFormat:@"%d", [weekdayNum intValue]]];
        }
    }
    [Preferences populatePreferenceInDictionary:dict key:ScheduledDrugWeekdaysKey value:weekdaysStr modifiedDate:nil perDevice:NO];
}

- (void)handleTimeZoneChange:(NSNotification *)notification
{
    // Flag that the time zone changed while the app was still running
    timeZoneChanged = YES;
}

// Returns the index of the last scheduled reminder time and whether it was postponed
- (void)getLastReminderTimeIndex:(int*)reminderTimeIndex wasPostponed:(BOOL*)wasPostponed postponeDuration:(int*)postponeDuration onDay:(NSDate**)onDay
{
	*reminderTimeIndex = -1;
	*wasPostponed = NO;
	*onDay = nil;
	*postponeDuration = 0;
	int numTimes = (int)[reminderTimes count];
    NSDate* baseTime = self.nextReminder;
    if (!baseTime && self.overdueReminder)
        baseTime = self.overdueReminder;
	if (!baseTime || numTimes == 0)
		return;
	
	*onDay = baseTime;
	for (int i = 0; i < numTimes && *reminderTimeIndex < 0; i++)
	{
		NSDate* time = [self getReminderTimeForDay:i day:*onDay];
		NSTimeInterval timeInterval = [time timeIntervalSinceDate:baseTime];
		if (timeInterval >= 0)
		{
            if (self.nextReminder) // if our reference time is the next reminder, back-up by one reminder time index. Otherwise, we're using the overdue time as the reference time (no need to back up)
            {
                if (i == 0)
                {
                    *reminderTimeIndex = numTimes-1;
                    *onDay = [self getPrevDay:*onDay];
                }
                else
                    *reminderTimeIndex = i-1;
            }
			if (timeInterval > 0)
			{
				time = [self getReminderTimeForDay:*reminderTimeIndex day:*onDay];
				*postponeDuration = [baseTime timeIntervalSinceDate:time];			
                *wasPostponed = (*postponeDuration > 0);
			}
		}
	}
	if (*reminderTimeIndex < 0)
	{
		*reminderTimeIndex = numTimes-1;
		NSDate* time = [self getReminderTimeForDay:*reminderTimeIndex day:*onDay];
		*postponeDuration = [baseTime timeIntervalSinceDate:time];
        *wasPostponed = (*postponeDuration > 0);
	}	
}

// Returns an array of NSDates representing the times of future doses due on the given day
- (NSArray*) getFutureDoseTimesDueOnDay:(NSDate*)day
{
    NSMutableArray* doseTimes = [[NSMutableArray alloc] init];
    
    // Look at each dose, one at a time, starting with the next reminder
    NSDate* doseTime = self.nextReminder;

    if (doseTime)
    {
        // See if the dose time is on the desired day. If so, continue to build times after it on the same day.
        // Otherwise, try at the start of day, building times after it on the same day.
        if (![DosecastUtil areDatesOnSameDay:doseTime date2:day])
        {
            // If the dose time is not on the desired day, see if it is on an earlier day.
            // In that case, find the first scheduled time after the beginning of the desired day.
            if ([doseTime timeIntervalSinceDate:day] < 0)
                doseTime = [self getReminderTimeAfterTime:[DosecastUtil getMidnightOnDate:day] remindAtLimit:NO];
            else
                doseTime = nil; // The dose time is on a future day. Don't return any times
        }
    
        // Continue adding dose times to our array as long as we remain on the desired day
        if (doseTime && [DosecastUtil areDatesOnSameDay:doseTime date2:day])
        {
            do
            {
                [doseTimes addObject:doseTime];
                doseTime = [self getReminderTimeAfterTime:doseTime remindAtLimit:NO];                    
            }
            while (doseTime && [DosecastUtil areDatesOnSameDay:doseTime date2:day]);
        }
    }    
    
    return doseTimes;
}

// Returns an array of NSDates representing the times of past doses due on the given day
- (NSArray*) getPastDoseTimesDueOnDay:(NSDate*)day
{
    NSMutableArray* doseTimes = [[NSMutableArray alloc] init];
    
    // Look at each dose, one at a time, starting with the most recent reminder
    NSDate* doseTime = self.overdueReminder;
    if (!doseTime && self.nextReminder)
    {
        NSDate* now = [NSDate date];
        doseTime = self.nextReminder;
        while ([now timeIntervalSinceDate:doseTime] < 0) // The drug could be postponed, so go back in time
            doseTime = [self getReminderTimeBeforeTime:doseTime remindAtLimit:NO];
    }
    
    if (doseTime)
    {
        // See if the dose time is on the desired day. If so, continue to build times before it on the same day.
        // Otherwise, try at the end of day, building times before it on the same day.
        if (![DosecastUtil areDatesOnSameDay:doseTime date2:day])
        {
            // If the dose time is not on the desired day, see if it is on a later day.
            // In that case, find the last scheduled time before the end of the desired day.
            if ([doseTime timeIntervalSinceDate:day] > 0)
                doseTime = [self getReminderTimeBeforeTime:[DosecastUtil getLastSecondOnDate:day] remindAtLimit:NO];
            else
                doseTime = nil; // The dose time is on a past day. Don't return any times
        }
        
        // Continue adding dose times to our array as long as we remain on the desired day
        if (doseTime && [DosecastUtil areDatesOnSameDay:doseTime date2:day])
        {
            do
            {
                [doseTimes addObject:doseTime];
                doseTime = [self getReminderTimeBeforeTime:doseTime remindAtLimit:NO];
            }
            while (doseTime && [DosecastUtil areDatesOnSameDay:doseTime date2:day]);
        }
    }
    
    return doseTimes;
}

// Returns the reminder time after the given time
- (NSDate*)getReminderTimeAfterTimeWithoutBounds:(NSDate*)time
{
	int numTimes = (int)[reminderTimes count];
	if (!time || numTimes == 0)
		return nil;
	
	// Ensure we don't return a time prior to the start date
	if (self.treatmentStartDate && [time timeIntervalSinceDate:self.treatmentStartDate] < 0)
		time = [DosecastUtil addTimeIntervalToDate:self.treatmentStartDate timeInterval:-1]; // Allow us to schedule right on the start date (for weekly/monthly/custom period reminders), so substract 1 s
	
	// For weekly reminders, make sure the given time falls on one of our weekdays (if not, adjust it forward in time)
	if (frequency == ScheduledDrugFrequencyWeekly)
	{
        // Find the weekday for the provided date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSWeekdayCalendarUnit;
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:time];
        int weekday = (int)[timeComponents weekday];
        
        // Find the current or next weekday and whether it is wrapped into a different week
        BOOL wrappedWeek;
        int adjustedWeekday = [self getCurrentOrNextWeekdayForWeekday:weekday wrappedWeek:&wrappedWeek];
        int weekdayDiff = adjustedWeekday - weekday;
        
        if (weekdayDiff != 0 || wrappedWeek) // Adjust the given day/time
        {
            // Adjust the given day within the same week
            time = [DosecastUtil addDaysToDate:time numDays:weekdayDiff];
            
            // Wrap to the next/last week
            if (wrappedWeek)
                time = [DosecastUtil addDaysToDate:time numDays:7];

            // Offset the time value and set it to first thing in the morning (so we pickup the scheduled time)
            time = [DosecastUtil getMidnightOnDate:time];
        }
	}
	else if (frequency == ScheduledDrugFrequencyMonthly)
	{
        // Find the day-of-the-month of the start date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
        NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
        NSDateComponents* startDateComponents = [cal components:unitFlags fromDate:self.treatmentStartDate];
        NSInteger startDayOfMonth = [startDateComponents day];
        
        // Find the day-of-the-month of the given time
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:time];
        NSInteger timeDayOfMonth = [timeComponents day];
        
        // Calculate the offset to adjust the given time to the same day (moving forward)
        if (timeDayOfMonth != startDayOfMonth)
        {
            // Offset the time value and set it to first thing in the morning (so we pickup the scheduled time)
            timeComponents = [cal components:unitFlags fromDate:time];
            [timeComponents setDay:startDayOfMonth];
            [timeComponents setHour:0];
            [timeComponents setMinute:0];
            [timeComponents setSecond:0];			
            time = [cal dateFromComponents:timeComponents];
            
            if (timeDayOfMonth > startDayOfMonth)
                time = [DosecastUtil addMonthsToDate:time numMonths:1];
        }
	}
    // For custom reminders, make sure the given time falls on a multiple of the custom period from the start date (if not, adjust it forward in time)
    else if (frequency == ScheduledDrugFrequencyCustom)
    {
        int numPeriodDays = customFrequencyNum;
        if (customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodWeeks)
            numPeriodDays *= 7;
        
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        
        NSDate* timeStartOfDay = [DosecastUtil getMidnightOnDate:time];
        
        NSDate* treatmentStartDateStartOfDay = [DosecastUtil getMidnightOnDate:self.treatmentStartDate];
        
        // Calculate the number of days from the start date to the given time
        NSDateComponents *componentsFromStartToTime = [cal components:NSDayCalendarUnit fromDate:treatmentStartDateStartOfDay toDate:timeStartOfDay options:0];
        int daysFromStartToTime = (int)[componentsFromStartToTime day];
        if (daysFromStartToTime < 0)
            time = treatmentStartDateStartOfDay;
        else if (daysFromStartToTime > 0)
        {
            // See if we need to adjust the given time so it lands on a multiple of the custom period from the start date
            int daysLeftover = daysFromStartToTime % numPeriodDays;
            if (daysLeftover > 0)
            {
                int adjustDays = numPeriodDays - daysLeftover;
                if (adjustDays > 0)
                {
                    time = [DosecastUtil addDaysToDate:time numDays:adjustDays];
                
                    // Offset the time value and set it to first thing in the morning (so we pickup the scheduled time)
                    time = [DosecastUtil getMidnightOnDate:time];
                }
            }
        }        
    }
	
    // Find the reminder time after the given time
	NSDate* afterReminder = nil;
	for (int i = 0; i < numTimes && !afterReminder; i++)
	{
		NSDate* scheduleTime = [self getReminderTimeForDay:i day:time];
		if ([scheduleTime timeIntervalSinceDate:time] > 0)
			afterReminder = scheduleTime;
	}
	if (!afterReminder)
		afterReminder = [self getReminderTimeForDay:0 day:[self getNextDay:time]];
	
	return afterReminder;
}

// Returns the reminder time before the given time
- (NSDate*)getReminderTimeBeforeTimeWithoutBounds:(NSDate*)time
{
	int numTimes = (int)[reminderTimes count];
	if (!time || numTimes == 0)
		return nil;
	
	// Ensure we don't return a time after the end date
	if (self.treatmentEndDate && [time timeIntervalSinceDate:self.treatmentEndDate] > 0)
		time = [DosecastUtil addTimeIntervalToDate:self.treatmentEndDate timeInterval:1]; // Allow us to schedule right on the end date (for weekly/monthly/custom period reminders), so add 1 s
	
	// For weekly reminders, make sure the given time falls on one of our weekdays (if not, adjust it backward in time)
	if (frequency == ScheduledDrugFrequencyWeekly)
	{
        // Find the weekday for the provided date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSWeekdayCalendarUnit;
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:time];
        int weekday = (int)[timeComponents weekday];
        
        // Find the current or prev weekday and whether it is wrapped into a different week
        BOOL wrappedWeek;
        int adjustedWeekday = [self getCurrentOrPrevWeekdayForWeekday:weekday wrappedWeek:&wrappedWeek];
        int weekdayDiff = weekday - adjustedWeekday;
        
        if (weekdayDiff != 0 || wrappedWeek) // Adjust the given day/time
        {
            // Adjust the given day within the same week
            time = [DosecastUtil addDaysToDate:time numDays:-weekdayDiff];
            
            // Wrap to the next/last week
            if (wrappedWeek)
                time = [DosecastUtil addDaysToDate:time numDays:-7];
            
            // Offset the time value and set it to last thing in the day (so we pickup the scheduled time)
            time = [DosecastUtil getLastSecondOnDate:time];
        }
	}
	else if (frequency == ScheduledDrugFrequencyMonthly)
	{
        // Find the day-of-the-month of the start date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
        NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
        NSDateComponents* startDateComponents = [cal components:unitFlags fromDate:self.treatmentStartDate];
        NSInteger startDayOfMonth = [startDateComponents day];
        
        // Find the day-of-the-month of the given time
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:time];
        NSInteger timeDayOfMonth = [timeComponents day];
        
        // Calculate the offset to adjust the given time to the same day (moving back)
        if (timeDayOfMonth != startDayOfMonth)
        {
            // Offset the time value and set it to last thing in the day (so we pickup the scheduled time)
            timeComponents = [cal components:unitFlags fromDate:time];
            [timeComponents setDay:startDayOfMonth];
            [timeComponents setHour:23];
            [timeComponents setMinute:59];
            [timeComponents setSecond:59];
            time = [cal dateFromComponents:timeComponents];
            
            if (timeDayOfMonth < startDayOfMonth)
                time = [DosecastUtil addMonthsToDate:time numMonths:-1];
        }
	}
    // For custom reminders, make sure the given time falls on a multiple of the custom period from the start date (if not, adjust it back in time)
    else if (frequency == ScheduledDrugFrequencyCustom)
    {
        int numPeriodDays = customFrequencyNum;
        if (customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodWeeks)
            numPeriodDays *= 7;
        
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        
        NSDate* timeStartOfDay = [DosecastUtil getMidnightOnDate:time];
        
        NSDate* treatmentStartDateStartOfDay = [DosecastUtil getMidnightOnDate:self.treatmentStartDate];
        
        // Calculate the number of days from the start date to the given time
        NSDateComponents *componentsFromStartToTime = [cal components:NSDayCalendarUnit fromDate:treatmentStartDateStartOfDay toDate:timeStartOfDay options:0];
        int daysFromStartToTime = (int)[componentsFromStartToTime day];
        if (daysFromStartToTime < 0)
            return nil;
        else if (daysFromStartToTime > 0)
        {
            // See if we need to adjust the given time so it lands on a multiple of the custom period from the start date
            int daysLeftover = daysFromStartToTime % numPeriodDays;
            if (daysLeftover > 0)
            {
                time = [DosecastUtil addDaysToDate:time numDays:-daysLeftover];
                
                // Offset the time value and set it to last thing in the day (so we pickup the scheduled time)
                time = [DosecastUtil getLastSecondOnDate:time];
            }
        }
    }
	
    // Find the reminder time before the given time
	NSDate* beforeReminder = nil;
	for (int i = numTimes-1; i >= 0 && !beforeReminder; i--)
	{
		NSDate* scheduleTime = [self getReminderTimeForDay:i day:time];
		if ([scheduleTime timeIntervalSinceDate:time] < 0)
			beforeReminder = scheduleTime;
	}
	if (!beforeReminder)
		beforeReminder = [self getReminderTimeForDay:(numTimes-1) day:[self getPrevDay:time]];
	
	return beforeReminder;
}

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date
{
	if (!self.nextReminder && [self treatmentStarted] && ![self treatmentEnded] && date && [reminderTimes count] > 0)
	{				
		NSDate* subsequentDoseDate = [self getReminderTimeAfterTimeWithoutBounds:date];
		return [subsequentDoseDate timeIntervalSinceDate:date] > 0;
	}
	else
		return NO;			
}

// Returns the reminder time after the given time
- (NSDate*)getReminderTimeAfterTime:(NSDate*)time
					  remindAtLimit:(BOOL)remindAtLimit
{
	NSDate* afterReminder = [self getReminderTimeAfterTimeWithoutBounds:time];
	
	// Make sure the next reminder doesn't fall after the treatment end date
	if (self.treatmentEndDate && afterReminder && [afterReminder timeIntervalSinceDate:self.treatmentEndDate] > 0)
	{
		if (remindAtLimit)
			return self.treatmentEndDate;
		else
			return nil;
	}
	else
		return afterReminder;
}

// Returns the reminder time before the given time
- (NSDate*)getReminderTimeBeforeTime:(NSDate*)time
					  remindAtLimit:(BOOL)remindAtLimit
{
	NSDate* beforeReminder = [self getReminderTimeBeforeTimeWithoutBounds:time];
	
	// Make sure the next reminder doesn't fall before the treatment start date
	if (self.treatmentStartDate && [beforeReminder timeIntervalSinceDate:self.treatmentStartDate] < 0)
	{
		if (remindAtLimit)
			return self.treatmentStartDate;
		else
			return nil;
	}
	else
		return beforeReminder;
}

// Return the ith reminder time
- (NSDate*)getReminderTime:(int)i
{
	if (i < 0 || i >= [reminderTimes count])
		return nil;
	
	NSNumber* timeNum = [reminderTimes objectAtIndex:i];
	if (timeNum == nil)
		return nil;
	return [DosecastUtil get24hrTimeAsDate:[timeNum intValue]];
}

// Return the ith reminder time on the given day
- (NSDate*)getReminderTimeForDay:(int)i day:(NSDate*)day
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
	NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents* dayTimeComponents = [cal components:unitFlags fromDate:day];
	NSDate* scheduledReminderTime = [self getReminderTime:i];
	if (!scheduledReminderTime)
		return nil;
	NSDateComponents* timeComponents = [cal components:unitFlags fromDate:scheduledReminderTime];
	[dayTimeComponents setHour:[timeComponents hour]];
	[dayTimeComponents setMinute:[timeComponents minute]];
	[dayTimeComponents setSecond:0];
	return [cal dateFromComponents:dayTimeComponents];
}

// Returns the maximum number of local notifications that will be used by the current reminder for postpone
- (int)getMaxNumLocalNotificationsUsedForPostpone
{
    int total = 0;
    
    // Take into account a postponed reminder - but only if reminders are enabled and we have more then 1 time,
    // and either there's no end date or it's in the past
    if (self.remindersEnabled && [reminderTimes count] > 0 &&
        (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0))
    {
        total = 1; // Each scheduled drug can have at most 1 postponed reminder. Add this.
        if (self.secondaryRemindersEnabled && [DataModel getInstance].globalSettings.secondaryReminderPeriodSecs > 0)
            total += 1;
    }
    
    return total;
}

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed
{
    return ((int)[reminderTimes count] * [self getMaxNumLocalNotificationsUsedPerReminderTime]) + [self getMaxNumLocalNotificationsUsedForPostpone];
}

// Returns the maximum number of local notifications that will be used by the current reminder for each time
- (int)getMaxNumLocalNotificationsUsedPerReminderTime
{
    int total = 0;
    
    if (self.remindersEnabled &&
        (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0))
    {
        if (frequency == ScheduledDrugFrequencyCustom)
        {
            // Custom frequency drugs will always use a fixed number of local notifications as it will always get expanded into the future
            total = NUM_PERIODS_CONVERSION_FOR_REPEATING_CUSTOM_LOCAL_NOTIFICATION;
        }
        else if (frequency == ScheduledDrugFrequencyWeekly) // Take into account the number of weekdays
        {
            int numWeekdays = 1;
            if (weekdays)
                numWeekdays = (int)[weekdays count];
            total = numWeekdays;
        }
        else
        {
            total = 1;
        }
        
        if (self.secondaryRemindersEnabled && [DataModel getInstance].globalSettings.secondaryReminderPeriodSecs > 0)
            total *= 2;
    }
    
    return total;
}

- (void) shiftInternalReminderStateBy:(NSTimeInterval)timeInterval
{
    NSDate* beginningOfTime = [NSDate dateWithTimeIntervalSince1970:2];
    
    if (self.nextReminder)
        self.nextReminder = [DosecastUtil addTimeIntervalToDate:self.nextReminder timeInterval:timeInterval];
    if (self.takePillAfter && [self.takePillAfter timeIntervalSinceDate:beginningOfTime] > 0)
        self.takePillAfter = [DosecastUtil addTimeIntervalToDate:self.takePillAfter timeInterval:timeInterval];
    if (self.skipPillAfter && [self.skipPillAfter timeIntervalSinceDate:beginningOfTime] > 0)
        self.skipPillAfter = [DosecastUtil addTimeIntervalToDate:self.skipPillAfter timeInterval:timeInterval];
    if (self.maxPostponeTime)
        self.maxPostponeTime = [DosecastUtil addTimeIntervalToDate:self.maxPostponeTime timeInterval:timeInterval];
}

- (void) shiftScheduledRemindersBy:(NSTimeInterval) timeInterval
{
    NSDate* today = [NSDate date];
    int numTimes = (int)[reminderTimes count];
    for (int i = 0; i < numTimes; i++)
    {
        NSDate* scheduleTime = [self getReminderTimeForDay:i day:today];
        NSDate* adjustedScheduleTime = [DosecastUtil addTimeIntervalToDate:scheduleTime timeInterval:timeInterval];
        int adjustedScheduleTimeNum = [DosecastUtil getDateAs24hrTime:adjustedScheduleTime];
        [reminderTimes replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:adjustedScheduleTimeNum]];
    }
    
    // Sort times
    [reminderTimes sortUsingSelector:@selector(compare:)];
}

// Adjusts the reminders for a time zone change
- (void)adjustRemindersForTimeZoneChange:(NSTimeInterval)timeZoneInterval
{
    [super adjustRemindersForTimeZoneChange:timeZoneInterval];

    DataModel* dataModel = [DataModel getInstance];
    
    [self shiftInternalReminderStateBy:timeZoneInterval];
    
    // If the time zone didn't change while the app was running, we need to shift the reminder times. This is because they are
    // stored on disk in GMT but loaded into the new (local) time zone. We need to shift them back to where they were originally.
    // This isn't necessary if the time zone changed or a daylight savings transition occurred while the app was active because the times are still in the local time zone
    // and will get written to disk back to GMT from the new time zone.
    NSDate* daylightSavingsTransitionAfterAppOpened = [[NSTimeZone localTimeZone] nextDaylightSavingTimeTransitionAfterDate:dataModel.appLastOpened];
    BOOL daylightSavingsTransitionOccurred = ([daylightSavingsTransitionAfterAppOpened timeIntervalSinceNow] < 0);
    if (!timeZoneChanged && !daylightSavingsTransitionOccurred)
    {
        [self shiftScheduledRemindersBy:timeZoneInterval];
    }
}

// Adjusts the reminder times by the given time interval
- (void)adjustReminderTimesByTimeInterval:(NSTimeInterval)timeInterval
{
    [self shiftInternalReminderStateBy:timeInterval];
    [self shiftScheduledRemindersBy:timeInterval];
}

// Returns a string that describes this type
+ (NSString*)getReminderTypeName
{
	return [NSString stringWithString:ScheduledReminderTypeName];
}

- (BOOL)canTakeDose
{
	BOOL superCanTakeDose = [super canTakeDose];
	return superCanTakeDose && self.nextReminder;
}

- (BOOL)canSkipDose
{
	BOOL superCanSkipDose = [super canSkipDose];
	return superCanSkipDose && self.nextReminder;
}

- (BOOL)canPostponeDose
{
	BOOL superCanPostponeDose = [super canPostponeDose];
	return superCanPostponeDose && self.nextReminder;
}

// Returns the current weekday in the schedule from the given weekday day. If the given weekday isn't in our weekday list, returns the next one.
// Weekdays are in the range 1..7 where 1 = Sunday.
- (int) getCurrentOrNextWeekdayForWeekday:(int)weekday wrappedWeek:(BOOL*)wrappedWeek
{
    *wrappedWeek = NO;
    
    if (!weekdays || [weekdays count] == 0)
    {
        return weekday;
    }
    
    int numWeekdays = (int)[weekdays count];
    
    // Look through all weekdays we have, looking for the weekday provided or next highest one.
    for (int i = 0; i < numWeekdays; i++)
    {
        int thisWeekday = [[weekdays objectAtIndex:i] intValue];
        if (thisWeekday >= weekday)
        {
            return thisWeekday;
        }
    }
    
    // We didn't find the weekday provided or the next highest one.
    *wrappedWeek = YES;
    return [[weekdays objectAtIndex:0] intValue];
}

// Returns the current weekday in the schedule from the given weekday day. If the given weekday isn't in our weekday list, returns the prev one.
// Weekdays are in the range 1..7 where 1 = Sunday.
- (int) getCurrentOrPrevWeekdayForWeekday:(int)weekday wrappedWeek:(BOOL*)wrappedWeek
{
    *wrappedWeek = NO;
    
    if (!weekdays || [weekdays count] == 0)
    {
        return weekday;
    }
    
    int numWeekdays = (int)[weekdays count];
    
    // Look through all weekdays we have, looking for the weekday provided or prev one.
    for (int i = numWeekdays-1; i >= 0; i--)
    {
        int thisWeekday = [[weekdays objectAtIndex:i] intValue];
        if (thisWeekday <= weekday)
        {
            return thisWeekday;
        }
    }
    
    // We didn't find the weekday provided or the prev one.
    *wrappedWeek = YES;
    return [[weekdays objectAtIndex:numWeekdays-1] intValue];
}

// Returns the adjacent weekday in the schedule from the given weekday day. Weekdays are in the range 1..7 where 1 = Sunday.
// directionIsForward indicates which direction.
- (int) getAdjacentWeekdayForWeekday:(int)weekday directionIsForward:(BOOL)forward wrappedWeek:(BOOL*)wrappedWeek
{
    *wrappedWeek = NO;
    
    if (!weekdays || [weekdays count] == 0)
    {
        *wrappedWeek = YES; // Assume 1 weekday
        return weekday;
    }
    
    int numWeekdays = (int)[weekdays count];
        
    // Look through all weekdays we have, looking for the weekday provided or next highest one.
    for (int i = 0; i < numWeekdays; i++)
    {
        int thisWeekday = [[weekdays objectAtIndex:i] intValue];
        if (thisWeekday == weekday) // If this is the current weekday provided...
        {
            if (forward && i == numWeekdays-1) // Return the first one, wrapped around the week
            {
                *wrappedWeek = YES;
                return [[weekdays objectAtIndex:0] intValue];
            }
            else if (forward && i < numWeekdays-1) // Return the next one within the same week
                return [[weekdays objectAtIndex:i+1] intValue];
            else if (!forward && i == 0) // Return the last one, wrapped around the week
            {
                *wrappedWeek = YES;
                return [[weekdays objectAtIndex:numWeekdays-1] intValue];
            }
            else if (!forward && i > 0) // Return the last one within the same week
                return [[weekdays objectAtIndex:i-1] intValue];
        }
        else if (thisWeekday > weekday) // If the weekday provided isn't in our weekday list, but we found the next highest one...
        {
            if (forward)
                return thisWeekday;
            else if (!forward && i > 0) // Return the last one within the same week
                return [[weekdays objectAtIndex:i-1] intValue];
            else if (!forward && i == 0) // Return the last one, wrapped around the week
            {
                *wrappedWeek = YES;
                return [[weekdays objectAtIndex:numWeekdays-1] intValue];
            }
        }
    }
    
    // We didn't find the weekday provided or the next highest one.
    if (forward) // Return the first one, wrapped around the week
    {
        *wrappedWeek = YES;
        return [[weekdays objectAtIndex:0] intValue];
    }
    else // Return the last one within the same week
        return [[weekdays objectAtIndex:numWeekdays-1] intValue];
}

// Returns the next or prev recurring day from the given day. directionIsForward indicates which direction.
- (NSDate*) getAdjacentRecurringDay:(NSDate*)day directionIsForward:(BOOL)forward
{
    if (frequency == ScheduledDrugFrequencyDaily)
        return [DosecastUtil addDaysToDate:day numDays:(forward ? 1 : -1)];
    else if (frequency == ScheduledDrugFrequencyWeekly)
        return [DosecastUtil addDaysToDate:day numDays:(forward ? 7 : -7)];
    else if (frequency == ScheduledDrugFrequencyMonthly)
        return [DosecastUtil addMonthsToDate:day numMonths:(forward ? 1 : -1)];
    else if (frequency == ScheduledDrugFrequencyCustom)
    {
        int numPeriodDays = customFrequencyNum;
        if (customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodWeeks)
            numPeriodDays *= 7;
        
        return [DosecastUtil addDaysToDate:day numDays:(forward ? numPeriodDays : -numPeriodDays)];
    }
    else
        return nil;
}

// Returns the next or prev day in the schedule from the given day. directionIsForward indicates which direction.
- (NSDate*) getAdjacentDay:(NSDate*)day directionIsForward:(BOOL)forward
{
	if (frequency == ScheduledDrugFrequencyWeekly)
    {
        // Find the weekday for the provided date
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        unsigned unitFlags = NSWeekdayCalendarUnit;
        NSDateComponents* timeComponents = [cal components:unitFlags fromDate:day];
        int weekday = (int)[timeComponents weekday];

        // Find the adjacent weekday and whether it is wrapped into a different week
        BOOL wrappedWeek;
        int adjacentWeekday = [self getAdjacentWeekdayForWeekday:weekday directionIsForward:forward wrappedWeek:&wrappedWeek];
        
        // Adjust the given day within the same week
        NSDate* result = [DosecastUtil addDaysToDate:day numDays:(adjacentWeekday - weekday)];
        
        // Wrap to the next/last week
        if (wrappedWeek)
            result = [self getAdjacentRecurringDay:result directionIsForward:forward];
        return result;
    }
    else
    {
        return [self getAdjacentRecurringDay:day directionIsForward:forward];
    }
}

- (NSArray*) weekdays
{
    return weekdays;
}

- (void) setWeekdays:(NSArray *)wkdays
{
    if (frequency == ScheduledDrugFrequencyWeekly)
    {
        weekdays = wkdays;
    }
}

- (ScheduledDrugFrequency) frequency
{
    return frequency;
}

- (void) setFrequency:(ScheduledDrugFrequency)newFreq
{
    if (frequency == newFreq)
        return;
    
    if (frequency == ScheduledDrugFrequencyWeekly && newFreq != ScheduledDrugFrequencyWeekly)
    {
        weekdays = nil;
    }
    else if (frequency != ScheduledDrugFrequencyWeekly && newFreq == ScheduledDrugFrequencyWeekly)
    {
        [self setWeekdaysToTreatmentStartDate];
    }

    if (frequency == ScheduledDrugFrequencyCustom && newFreq != ScheduledDrugFrequencyCustom)
    {
        customFrequencyNum = -1;
        customFrequencyPeriod = ScheduledDrugFrequencyCustomPeriodNone;
    }
    
    frequency = newFreq;
}

- (void)setTreatmentStartDate:(NSDate*)d
{
    [super setTreatmentStartDate:d];    
}

- (int) customFrequencyNum
{
    return customFrequencyNum;
}

- (void) setCustomFrequencyNum:(int)frequencyNum
{
    if (frequency == ScheduledDrugFrequencyCustom)
        customFrequencyNum = frequencyNum;
}

- (ScheduledDrugFrequencyCustomPeriod) customFrequencyPeriod
{
    return customFrequencyPeriod;
}

- (void) setCustomFrequencyPeriod:(ScheduledDrugFrequencyCustomPeriod)freqPeriod
{
    if (frequency == ScheduledDrugFrequencyCustom)
        customFrequencyPeriod = freqPeriod;
}

// Returns the next/prev day in the schedule from the given day
- (NSDate*) getNextDay:(NSDate*)day
{
	return [self getAdjacentDay:day directionIsForward:YES];
}

- (NSDate*) getPrevDay:(NSDate*)day
{
	return [self getAdjacentDay:day directionIsForward:NO];
}

// Returns the next/prev recurring day in the schedule from the given day
- (NSDate*) getNextRecurringDay:(NSDate*)day
{
	return [self getAdjacentRecurringDay:day directionIsForward:YES];
}

- (NSDate*) getPrevRecurringDay:(NSDate*)day
{
	return [self getAdjacentRecurringDay:day directionIsForward:NO];
}

- (BOOL)wasPostponed:(int*)postponeDuration
{
    int reminderTimeIndex;
    BOOL postponed;
    NSDate* onDay;
    int duration;
    [self getLastReminderTimeIndex:&reminderTimeIndex wasPostponed:&postponed postponeDuration:&duration onDay:&onDay];
    if (postponeDuration)
        *postponeDuration = duration;
    return postponed;
}

// If overdue, returns the last scheduled dose time (prior to any postpones).
// If not overdue, returns the next scheduled dose time (prior to any postpones).
- (NSDate*) getCurrentScheduledTime
{
    int reminderTimeIndex;
    BOOL postponed;
    int postponeDuration;
    NSDate* onDay;
    [self getLastReminderTimeIndex:&reminderTimeIndex wasPostponed:&postponed postponeDuration:&postponeDuration onDay:&onDay];
    
    if (reminderTimeIndex < 0 || !onDay)
        return nil;
    
    // If overdue, returns the last scheduled dose time (prior to any postpones).
    
    // If not overdue, returns the next scheduled dose time (prior to any postpones).
    if (!self.overdueReminder && self.nextReminder && !postponed)
    {
        int numTimes = (int)[reminderTimes count];
        reminderTimeIndex += 1;
        if (reminderTimeIndex == numTimes)
        {
            reminderTimeIndex = 0;
            onDay = [self getNextDay:onDay];
        }
    }
    
    return [self getReminderTimeForDay:reminderTimeIndex day:onDay];
}

// If overdue, returns the last scheduled dose time (prior to any postpones).
// If not overdue, returns the next scheduled dose time (prior to any postpones).
- (NSDate*) getCurrentScheduledTimeFromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)thisLastTaken
{
    NSDate* currentScheduledTime = nil;
    
    if (effLastTaken)
        currentScheduledTime = [self getReminderTimeAfterTime:effLastTaken remindAtLimit:NO];
    else if (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0)
    {
        NSDate* beginDate = [self getReminderLimitForTreatmentStartDate];
        if (beginDate && thisLastTaken && [beginDate timeIntervalSinceDate:thisLastTaken] < 0)
            beginDate = thisLastTaken;
        
        currentScheduledTime = [self getReminderTimeAfterTime:beginDate remindAtLimit:NO];
    }
    
    return currentScheduledTime;
}

- (BOOL) logMissedDoses
{
    if (archived || invisible)
        return NO;
    else
        return logMissedDoses;
}

- (void) setLogMissedDoses:(BOOL)log
{
    logMissedDoses = log;
}

// Returns an array of strings that describe the refill alert options
- (NSArray*) getRefillAlertOptions
{
	if (frequency == ScheduledDrugFrequencyDaily)
	{
		return [NSArray arrayWithObjects:
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Day", @"Dosecast", [DosecastUtil getResourceBundle], @"1 day before empty", @"The refill alert option for 1 day before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert3Days", @"Dosecast", [DosecastUtil getResourceBundle], @"3 days before empty", @"The refill alert option for 3 days before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Week", @"Dosecast", [DosecastUtil getResourceBundle], @"1 week before empty", @"The refill alert option for 1 week before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert2Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"2 weeks before empty", @"The refill alert option for 2 weeks before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert3Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"3 weeks before empty", @"The refill alert option for 3 weeks before empty"])],                
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert4Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"4 weeks before empty", @"The refill alert option for 4 weeks before empty"])],
				nil];
	}
	else if (frequency == ScheduledDrugFrequencyWeekly)
	{
		return [NSArray arrayWithObjects:
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Week", @"Dosecast", [DosecastUtil getResourceBundle], @"1 week before empty", @"The refill alert option for 1 week before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert2Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"2 weeks before empty", @"The refill alert option for 2 weeks before empty"])],
                [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert3Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"3 weeks before empty", @"The refill alert option for 3 weeks before empty"])],
				[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert4Weeks", @"Dosecast", [DosecastUtil getResourceBundle], @"4 weeks before empty", @"The refill alert option for 4 weeks before empty"])],
				nil];		
	}
	else if (frequency == ScheduledDrugFrequencyMonthly)
	{
        return [NSArray arrayWithObjects:
                [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Month", @"Dosecast", [DosecastUtil getResourceBundle], @"1 month before empty", @"The refill alert option for 1 month before empty"])],
                [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert2Months", @"Dosecast", [DosecastUtil getResourceBundle], @"2 months before empty", @"The refill alert option for 2 months before empty"])],
                [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert3Months", @"Dosecast", [DosecastUtil getResourceBundle], @"3 months before empty", @"The refill alert option for 3 months before empty"])],
                nil];					
	}
    else // ScheduledDrugFrequencyCustom
    {
        if (customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodDays)
        {
            NSString* refillAlertDay = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Day", @"Dosecast", [DosecastUtil getResourceBundle], @"1 day before empty", @"The refill alert option for 1 day before empty"]);
            NSString* refillAlertCustomDays = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlertCustomDays", @"Dosecast", [DosecastUtil getResourceBundle], @"%d days before empty", @"The refill alert option for a custom number of days before empty"]);
            NSMutableArray* refillAlertOptions = [[NSMutableArray alloc] init];
            for (int i = 1; i <= 3; i++)
            {
                int numDays = customFrequencyNum * i;
                if (numDays == 1)
                    [refillAlertOptions addObject:refillAlertDay];
                else
                    [refillAlertOptions addObject:[NSString stringWithFormat:refillAlertCustomDays, numDays]];
            }
            return refillAlertOptions;		
        }
        else // ScheduledDrugFrequencyCustomPeriodWeeks
        {
            NSString* refillAlertWeek = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Week", @"Dosecast", [DosecastUtil getResourceBundle], @"1 week before empty", @"The refill alert option for 1 week before empty"]);
            NSString* refillAlertCustomWeeks = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlertCustomWeeks", @"Dosecast", [DosecastUtil getResourceBundle], @"%d weeks before empty", @"The refill alert option for a custom number of weeks before empty"]);
            NSMutableArray* refillAlertOptions = [[NSMutableArray alloc] init];
            for (int i = 1; i <= 3; i++)
            {
                int numWeeks = customFrequencyNum * i;
                if (numWeeks == 1)
                    [refillAlertOptions addObject:refillAlertWeek];
                else
                    [refillAlertOptions addObject:[NSString stringWithFormat:refillAlertCustomWeeks, numWeeks]];
            }
            return refillAlertOptions;		
        }
    }
}

// Returns the index of the current refill alert option
- (int) getRefillAlertOptionNum
{
	int numTimes = (int)[reminderTimes count];
	if (numTimes == 0) // Allow the user to set the refill alert options before any scheduled times
		numTimes = 1;

	if (frequency == ScheduledDrugFrequencyDaily)
	{
		if (refillAlertDoses == numTimes)
			return 0;
		else if (refillAlertDoses == 3*numTimes)
			return 1;
		else if (refillAlertDoses == 7*numTimes)
			return 2;
		else if (refillAlertDoses == 14*numTimes)
			return 3;
		else if (refillAlertDoses == 21*numTimes)
			return 4;
		else if (refillAlertDoses == 28*numTimes)
			return 5;
		else
			return -1;		
	}
	else if (frequency == ScheduledDrugFrequencyWeekly)
	{
        int numWeekdays = 1;
        if (weekdays)
            numWeekdays = (int)[weekdays count];
		if (refillAlertDoses == numTimes*numWeekdays)
			return 0;
		else if (refillAlertDoses == 2*numTimes*numWeekdays)
			return 1;
		else if (refillAlertDoses == 3*numTimes*numWeekdays)
			return 2;
		else if (refillAlertDoses == 4*numTimes*numWeekdays)
			return 3;
		else
			return -1;				
	}
	else // for all other cases (both ScheduledDrugFrequencyMonthly & ScheduledDrugFrequencyCustom)
	{
		// Same logic whether local or push notifications are used (the meaning of each option may be different for monthly, though)
		if (refillAlertDoses == numTimes)
			return 0;
		else if (refillAlertDoses == 2*numTimes)
			return 1;
		else if (refillAlertDoses == 3*numTimes)
			return 2;
		else
			return -1;							
	}
}

// Sets the index of the current refill alert option
- (BOOL) setRefillAlertOptionNum:(int)optionNum
{
	int numTimes = (int)[reminderTimes count];
	if (numTimes == 0) // Allow the user to set the refill alert options before any scheduled times
		numTimes = 1;

	if (frequency == ScheduledDrugFrequencyDaily)
	{
		if (optionNum == 0)
		{
			refillAlertDoses = numTimes;
			return YES;
		}
		else if (optionNum == 1)
		{
			refillAlertDoses = 3*numTimes;
			return YES;
		}
		else if (optionNum == 2)
		{
			refillAlertDoses = 7*numTimes;
			return YES;
		}
		else if (optionNum == 3)
		{
			refillAlertDoses = 14*numTimes;
			return YES;
		}
		else if (optionNum == 4)
		{
			refillAlertDoses = 21*numTimes;
			return YES;
		}
		else if (optionNum == 5)
		{
			refillAlertDoses = 28*numTimes;
			return YES;
		}
		else if (optionNum == -1)
		{
			refillAlertDoses = 0;
			return YES;
		}
		else
		{
			return NO;
		}
	}
	else if (frequency == ScheduledDrugFrequencyWeekly)
	{
        int numWeekdays = 1;
        if (weekdays)
            numWeekdays = (int)[weekdays count];

		if (optionNum == 0)
		{
			refillAlertDoses = numTimes*numWeekdays;
			return YES;
		}
		else if (optionNum == 1)
		{
			refillAlertDoses = 2*numTimes*numWeekdays;
			return YES;
		}
		else if (optionNum == 2)
		{
			refillAlertDoses = 3*numTimes*numWeekdays;
			return YES;
		}
		else if (optionNum == 3)
		{
			refillAlertDoses = 4*numTimes*numWeekdays;
			return YES;
		}
		else if (optionNum == -1)
		{
			refillAlertDoses = 0;
			return YES;
		}
		else
		{
			return NO;
		}
	}
	else // for all other cases (both ScheduledDrugFrequencyMonthly & ScheduledDrugFrequencyCustom)
	{
		if (optionNum == 0)
		{
			refillAlertDoses = numTimes;
			return YES;
		}
		else if (optionNum == 1)
		{
			refillAlertDoses = 2*numTimes;
			return YES;
		}
		else if (optionNum == 2)
		{
			refillAlertDoses = 3*numTimes;
			return YES;
		}
		else if (optionNum == -1)
		{
			refillAlertDoses = 0;
			return YES;
		}
		else
		{
			return NO;
		}		
	}
}

// The number of custom periods we expand local notifications to when using custom frequency periods
+ (int) getNumPeriodsConversionForRepeatingCustomLocalNotifications
{
    return NUM_PERIODS_CONVERSION_FOR_REPEATING_CUSTOM_LOCAL_NOTIFICATION;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSSystemTimeZoneDidChangeNotification object:nil];

}

@end