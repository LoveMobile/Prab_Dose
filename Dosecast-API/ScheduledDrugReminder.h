//
//  ScheduledDrugReminder.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugReminder.h"

typedef enum {
    ScheduledDrugFrequencyCustom		= 0,    
	ScheduledDrugFrequencyDaily			= 1,
	ScheduledDrugFrequencyWeekly		= 7,
	ScheduledDrugFrequencyMonthly		= 30
} ScheduledDrugFrequency;

typedef enum {
    ScheduledDrugFrequencyCustomPeriodNone  = -1,
    ScheduledDrugFrequencyCustomPeriodDays  = 0,    
	ScheduledDrugFrequencyCustomPeriodWeeks = 1
} ScheduledDrugFrequencyCustomPeriod;

@interface ScheduledDrugReminder : DrugReminder {
@private
	NSMutableArray* reminderTimes;
	ScheduledDrugFrequency frequency;
    int customFrequencyNum;
    ScheduledDrugFrequencyCustomPeriod customFrequencyPeriod;
    BOOL logMissedDoses;
    BOOL timeZoneChanged;
    NSArray* weekdays; // Array of NSNumber instances in the range 1..7 representing days of the week for weekly reminders. 1 = Sunday.
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
        logMissedDoses:(BOOL)logMissed;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Whether the current dose can be taken, skipped, or postponed
- (BOOL)canTakeDose;
- (BOOL)canSkipDose;
- (BOOL)canPostponeDose;

// Returns the index of the last reminder time and whether it was postponed
- (void)getLastReminderTimeIndex:(int*)reminderTimeIndex wasPostponed:(BOOL*)wasPostponed postponeDuration:(int*)postponeDuration onDay:(NSDate**)onDay;

// Returns the reminder time after the given time
- (NSDate*)getReminderTimeAfterTime:(NSDate*)time
					  remindAtLimit:(BOOL)remindAtLimit;

// Returns the reminder time before the given time
- (NSDate*)getReminderTimeBeforeTime:(NSDate*)time
					  remindAtLimit:(BOOL)remindAtLimit;

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date;

// Return the ith reminder time
- (NSDate*)getReminderTime:(int)i;

// Return the ith reminder time on the given day
- (NSDate*)getReminderTimeForDay:(int)i day:(NSDate*)day;

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed;

// Adjusts the reminders for a time zone change
- (void)adjustRemindersForTimeZoneChange:(NSTimeInterval)timeZoneInterval;

// Adjusts the reminder times by the given time interval
- (void)adjustReminderTimesByTimeInterval:(NSTimeInterval)timeInterval;

// Returns the next/prev day in the schedule from the given day
- (NSDate*) getNextDay:(NSDate*)day;
- (NSDate*) getPrevDay:(NSDate*)day;

// Returns the next/prev recurring day in the schedule from the given day
- (NSDate*) getNextRecurringDay:(NSDate*)day;
- (NSDate*) getPrevRecurringDay:(NSDate*)day;

// Returns a string that describes this type
+ (NSString*)getReminderTypeName;

// The number of custom periods we expand local notifications to when using custom frequency periods
+ (int) getNumPeriodsConversionForRepeatingCustomLocalNotifications;

@property (nonatomic, readonly) NSMutableArray* reminderTimes;
@property (nonatomic, assign) ScheduledDrugFrequency frequency;
@property (nonatomic, assign) int customFrequencyNum;
@property (nonatomic, assign) ScheduledDrugFrequencyCustomPeriod customFrequencyPeriod;
@property (nonatomic, assign) BOOL logMissedDoses;
@property (nonatomic, strong) NSArray* weekdays; // Array of NSNumber instances in the range 1..7 representing days of the week for weekly reminders. 1 = Sunday.

@end
