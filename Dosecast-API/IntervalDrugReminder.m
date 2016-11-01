//
//  IntervalDrugReminder.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "IntervalDrugReminder.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "Preferences.h"
#import "GlobalSettings.h"

static NSString *ReminderTypeKey = @"type";
static NSString *IntervalDrugReminderKey = @"interval";
static NSString *IntervalReminderTypeName = @"interval";
static NSString *LimitTypeKey = @"limitType";
static NSString *MaxNumDailyDosesKey = @"maxNumDailyDoses";

static double SEC_PER_DAY = 60*60*24;
int DEFAULT_REMINDER_INTERVAL_MINUTES = 240;

@implementation IntervalDrugReminder

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
			 interval:0
            limitType:IntervalDrugReminderDrugLimitTypeNever
     maxNumDailyDoses:0];
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
       interval:(int)i
      limitType:(IntervalDrugReminderDrugLimitType)limit
maxNumDailyDoses:(int)maxDailyDoses
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
		interval = i;
                
        if (limit == IntervalDrugReminderDrugLimitTypeNever)
        {
            if (maxDailyDoses != 0)
                maxDailyDoses = 0;
            
        }
        else
        {
            if (maxDailyDoses <= 0)
                maxDailyDoses = 1;
        }
        
        limitType = limit;
        maxNumDailyDoses = maxDailyDoses;
	}
	return self;		
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
    self.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
    
    if (notifyAfter || (effLastTaken && self.lastTaken))
    {
        NSDate* nextRemind = nil;
        if (notifyAfter && self.lastTaken)
            nextRemind = notifyAfter;
        else if (effLastTaken && self.lastTaken)
            nextRemind = [self getCurrentScheduledTimeFromEffLastTaken:effLastTaken andLastTaken:last];

        if (nextRemind && [nextRemind timeIntervalSinceNow] < 0)
        {
            self.overdueReminder = nextRemind;
        }
        // make sure nextReminder isn't during bedtime or before treatmentStartDate or after treatmentEnds
        else if (nextRemind &&
                 ![[DataModel getInstance] dateOccursDuringBedtime:nextRemind] &&
                 (!self.treatmentEndDate || [nextRemind timeIntervalSinceDate:self.treatmentEndDate] <= 0) &&
                 ([nextRemind timeIntervalSinceDate:self.treatmentStartDate] >= 0))

        {
            self.nextReminder = nextRemind;
        }
    }
    
    if (self.nextReminder || self.overdueReminder)
    {
        self.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        self.maxPostponeTime = [DosecastUtil addDaysToDate:[NSDate date] numDays:1];
    }
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
	
	int i = -1;
	NSNumber* intervalNum = [dict objectForKey:IntervalDrugReminderKey];
	if (intervalNum)
	{
		i = [intervalNum intValue];
	}
	
    IntervalDrugReminderDrugLimitType limit = IntervalDrugReminderDrugLimitTypeNever;
    int maxDailyDoses = 0;
    NSString* limitTypeStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:LimitTypeKey value:&limitTypeStr modifiedDate:nil perDevice:nil];
    if (limitTypeStr)
        limit = (IntervalDrugReminderDrugLimitType)[limitTypeStr intValue];
    
    NSString* maxNumDailyDosesNumberStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:MaxNumDailyDosesKey value:&maxNumDailyDosesNumberStr modifiedDate:nil perDevice:nil];
    if (maxNumDailyDosesNumberStr)
        maxDailyDoses = [maxNumDailyDosesNumberStr intValue];

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
			 interval:i
            limitType:limit 
     maxNumDailyDoses:maxDailyDoses];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[IntervalDrugReminder alloc] init:[self.treatmentStartDate copyWithZone:zone]
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
									 interval:interval
                                    limitType:limitType
                             maxNumDailyDoses:maxNumDailyDoses];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
	[super populateDictionary:dict forSyncRequest:forSyncRequest];
	
	[dict setObject:[NSString stringWithString:IntervalReminderTypeName] forKey:ReminderTypeKey];
	[dict setObject:[NSNumber numberWithInt:interval] forKey:IntervalDrugReminderKey];
    
    [Preferences populatePreferenceInDictionary:dict key:LimitTypeKey value:[NSString stringWithFormat:@"%d", (int)limitType] modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:MaxNumDailyDosesKey value:[NSString stringWithFormat:@"%d", maxNumDailyDoses] modifiedDate:nil perDevice:NO];
}

// Return a description for the dose limit settings
- (NSString*) getDoseLimitDescription
{
    if (limitType == IntervalDrugReminderDrugLimitTypeNever)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTypeNone", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The Dose Limit Never type label in the Dose Limit view"]);
    }
    else if (limitType == IntervalDrugReminderDrugLimitTypePerDay)
    {
        if ([DosecastUtil shouldUseSingularForInteger:maxNumDailyDoses])
            return [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePerDaySingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Max 1 dose per day", @"The singular dose limit phrase for per day types in the Drug Edit view"])];
        else
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePerDayPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Max %d doses per day", @"The plural dose limit phrase for per day types in the Drug Edit view"]), maxNumDailyDoses];            
    }
    else // IntervalDrugReminderDrugLimitTypePer24Hours
    {
        if ([DosecastUtil shouldUseSingularForInteger:maxNumDailyDoses])
            return [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePer24HoursSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Max 1 dose per 24 hrs", @"The singular dose limit phrase for per 24 hour types in the Drug Edit view"])];
        else
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePer24HoursPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Max %d doses per 24 hrs", @"The plural dose limit phrase for per 24 hour types in the Drug Edit view"]), maxNumDailyDoses];            
    }
}

// Returns an array of NSDates representing the times of future doses due on the given day
- (NSArray*) getFutureDoseTimesDueOnDay:(NSDate*)day
{
    NSMutableArray* doseTimes = [[NSMutableArray alloc] init];
    
    // See if the next reminder is set and falls on the given day
    if (self.nextReminder && [DosecastUtil areDatesOnSameDay:self.nextReminder date2:day])
        [doseTimes addObject:self.nextReminder];
    
    return doseTimes;
}

// Returns an array of NSDates representing the times of past doses due on the given day
- (NSArray*) getPastDoseTimesDueOnDay:(NSDate*)day
{
    NSMutableArray* doseTimes = [[NSMutableArray alloc] init];
    
    if (self.overdueReminder &&
        [DosecastUtil areDatesOnSameDay:self.overdueReminder date2:day])
    {
        [doseTimes addObject:self.overdueReminder];
    }
    
    if (self.lastTaken &&
        [DosecastUtil areDatesOnSameDay:self.lastTaken date2:day])
    {
        [doseTimes addObject:self.lastTaken];
    }
    
    return doseTimes;
}

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date
{
	if (!self.nextReminder && [self treatmentStarted] && ![self treatmentEnded] && date)
	{		
		NSDate* subsequentDoseDate = [DosecastUtil addTimeIntervalToDate:[NSDate date] timeInterval:interval];
		return [subsequentDoseDate timeIntervalSinceDate:date] > 0;
	}
	else
		return NO;		
}

// Returns whether a subsequent dose would fall in bedtime (only if nextReminder is nil)
- (BOOL)wouldSubsequentDoseFallInBedtime
{
    NSDate* subsequentDoseDate = [DosecastUtil addTimeIntervalToDate:[NSDate date] timeInterval:interval];
    DataModel* dataModel = [DataModel getInstance];
	
	if (!self.nextReminder && [self treatmentStarted] && ![self treatmentEnded])
        return [dataModel dateOccursDuringBedtime:subsequentDoseDate];
	else
		return NO;	
}

- (BOOL)canTakeDose
{
	BOOL superCanTakeDose = [super canTakeDose];
	return (superCanTakeDose &&
            ![self wouldSubsequentDoseFallAfterDate:self.treatmentEndDate]);
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

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed
{
    int total = 0;
    
    if (self.remindersEnabled &&
        (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0))
    {
        total = 1;
        if (self.secondaryRemindersEnabled && [DataModel getInstance].globalSettings.secondaryReminderPeriodSecs > 0)
            total *= 2;
    }
    
    return total;    
}

// Returns a string that describes the interval for a drug
+ (NSString*)intervalDescription:(int)minutes
{
	int numMinutesLeft = minutes % 60;
	int numHours = minutes / 60;
	int numHoursLeft = numHours % 24;
	int numDays = numHours / 24;
		
	BOOL displayDays = YES;
	BOOL displayHours = YES;
	BOOL displayMinutes = YES;
	if (numDays == 0)
		displayDays = NO;
	if (numHoursLeft == 0)
		displayHours = NO;
	if (numMinutesLeft == 0 && (numHoursLeft > 0 || numDays > 0))
		displayMinutes = NO;
	
	NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
	NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
	NSString* hourSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"hour", @"The singular name for hour in interval drug descriptions"]);
	NSString* hourPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"hours", @"The plural name for hour in interval drug descriptions"]);
	NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
	NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);
	
	NSMutableString* labelText = [NSMutableString stringWithString:@""];
	if (displayDays)
	{
		if (![DosecastUtil shouldUseSingularForInteger:numDays])
			[labelText appendFormat:@"%d %@", numDays, dayPlural];
		else
			[labelText appendFormat:@"%d %@", numDays, daySingular];
	}
	if (displayHours)
	{
		if (displayDays)
			[labelText appendString:@", "];
		if (![DosecastUtil shouldUseSingularForInteger:numHoursLeft])
			[labelText appendFormat:@"%d %@", numHoursLeft, hourPlural];
		else
			[labelText appendFormat:@"%d %@", numHoursLeft, hourSingular];
	}
	if (displayMinutes)
	{
		if (displayDays || displayHours)
			[labelText appendString:@", "];
		if (![DosecastUtil shouldUseSingularForInteger:numMinutesLeft])
			[labelText appendFormat:@"%d %@", numMinutesLeft, minPlural];
		else
			[labelText appendFormat:@"%d %@", numMinutesLeft, minSingular];
	}
	[labelText appendFormat:@" %@", NSLocalizedStringWithDefaultValue(@"IntervalDrugPhraseAfterDose", @"Dosecast", [DosecastUtil getResourceBundle], @"after dose", @"The phrase for 'after dose' in interval drug descriptions"])];
	return labelText;
}

// Returns a string that describes this type
+ (NSString*)getReminderTypeName
{
	return [NSString stringWithString:IntervalReminderTypeName];
}

// Returns an array of strings that describe the refill alert options
- (NSArray*) getRefillAlertOptions
{
	return [NSArray arrayWithObjects:
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert1Dose", @"Dosecast", [DosecastUtil getResourceBundle], @"1 dose before empty", @"The refill alert option for 1 dose before empty"])],
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert3Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"3 doses before empty", @"The refill alert option for 3 doses before empty"])],
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert7Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"7 doses before empty", @"The refill alert option for 7 doses before empty"])],
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert14Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"14 doses before empty", @"The refill alert option for 14 doses before empty"])],
            [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert21Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"21 doses before empty", @"The refill alert option for 21 doses before empty"])],
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert28Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"28 doses before empty", @"The refill alert option for 28 doses before empty"])],
			[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert56Doses", @"Dosecast", [DosecastUtil getResourceBundle], @"56 doses before empty", @"The refill alert option for 56 doses before empty"])],
			nil];
}

- (NSDate*) getNextScheduledReminderTime
{
    if (!self.lastTaken)
        return nil;
    
    return [DosecastUtil addTimeIntervalToDate:self.lastTaken timeInterval:interval];
}

- (BOOL) wasPostponed:(int*)postponeDuration
{
    if (postponeDuration)
        *postponeDuration = 0;
    if (!self.nextReminder || !self.lastTaken)
        return NO;
    
    NSDate* nonPostponeNextReminder = [self getNextScheduledReminderTime];
    int duration = [self.nextReminder timeIntervalSinceDate:nonPostponeNextReminder];
    if (postponeDuration)
        *postponeDuration = duration;
    return (duration != 0);
}

- (NSDate*) getCurrentScheduledTime
{
    if ((self.overdueReminder || self.nextReminder) && self.lastTaken)
    {
        return [self getNextScheduledReminderTime];
    }
    else
        return nil;
}

// If overdue, returns the last scheduled dose time (prior to any postpones).
// If not overdue, returns the next scheduled dose time (prior to any postpones).
- (NSDate*) getCurrentScheduledTimeFromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)thisLastTaken
{
    if (!effLastTaken)
        return nil;
    
    if (!self.treatmentEndDate || [self.treatmentEndDate timeIntervalSinceNow] > 0)
        return [DosecastUtil addTimeIntervalToDate:effLastTaken timeInterval:interval];
    else
        return nil;
}

// Returns the index of the current refill alert option
- (int) getRefillAlertOptionNum
{
	if (refillAlertDoses == 1)
		return 0;
	else if (refillAlertDoses == 3)
		return 1;
	else if (refillAlertDoses == 7)
		return 2;
	else if (refillAlertDoses == 14)
		return 3;
	else if (refillAlertDoses == 21)
		return 4;
	else if (refillAlertDoses == 28)
		return 5;
	else if (refillAlertDoses == 56)
		return 6;
	else
		return -1;
}

// Sets the index of the current refill alert option
- (BOOL) setRefillAlertOptionNum:(int)optionNum
{
	if (optionNum == 0)
	{
		refillAlertDoses = 1;
		return YES;
	}
	else if (optionNum == 1)
	{
		refillAlertDoses = 3;
		return YES;
	}
	else if (optionNum == 2)
	{
		refillAlertDoses = 7;
		return YES;
	}
	else if (optionNum == 3)
	{
		refillAlertDoses = 14;
		return YES;
	}
	else if (optionNum == 4)
	{
		refillAlertDoses = 21;
		return YES;
	}
	else if (optionNum == 5)
	{
		refillAlertDoses = 28;
		return YES;
	}
	else if (optionNum == 6)
	{
		refillAlertDoses = 56;
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

- (int) interval
{
    return interval;
}

- (void) setInterval:(int)i
{
    if (interval == i)
        return;
    
    interval = i;
    
    if (interval >= SEC_PER_DAY)
    {
        limitType = IntervalDrugReminderDrugLimitTypeNever;
        maxNumDailyDoses = 0;
    }    
}

- (IntervalDrugReminderDrugLimitType) limitType
{
    return limitType;
}

- (void) setLimitType:(IntervalDrugReminderDrugLimitType)newLimitType
{    
    if (interval >= SEC_PER_DAY)
        newLimitType = IntervalDrugReminderDrugLimitTypeNever;
    
    if (limitType == newLimitType)
        return;
    
    limitType = newLimitType;
    if (newLimitType == IntervalDrugReminderDrugLimitTypeNever)
        maxNumDailyDoses = 0;
    else if (maxNumDailyDoses <= 0)
        maxNumDailyDoses = 1;
}

- (int) maxNumDailyDoses
{
    return maxNumDailyDoses;
}

- (void) setMaxNumDailyDoses:(int)max
{
    if (interval >= SEC_PER_DAY)
        max = 0;

    if (maxNumDailyDoses == max)
        return;
    
    if (limitType == IntervalDrugReminderDrugLimitTypeNever && max != 0)
        max = 0;
    else if (limitType != IntervalDrugReminderDrugLimitTypeNever && max <= 0)
        max = 1;
    
    maxNumDailyDoses = max;
}


@end
