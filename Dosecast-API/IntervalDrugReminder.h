//
//  IntervalDrugReminder.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugReminder.h"

typedef enum {
	IntervalDrugReminderDrugLimitTypeNever     	= 0,
	IntervalDrugReminderDrugLimitTypePerDay   	= 1,
	IntervalDrugReminderDrugLimitTypePer24Hours = 2
} IntervalDrugReminderDrugLimitType;

extern int DEFAULT_REMINDER_INTERVAL_MINUTES;

@interface IntervalDrugReminder : DrugReminder {
@private
	int interval; // in seconds
    IntervalDrugReminderDrugLimitType limitType;
    int maxNumDailyDoses;
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
maxNumDailyDoses:(int)maxDailyDoses;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Whether the current dose can be taken, skipped, or postponed
- (BOOL)canTakeDose;
- (BOOL)canSkipDose;
- (BOOL)canPostponeDose;

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date;

// Returns whether a subsequent dose would fall in bedtime (only if nextReminder is nil)
- (BOOL)wouldSubsequentDoseFallInBedtime;

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed;

// Return a description for the dose limit settings
- (NSString*) getDoseLimitDescription;

// Returns a string that describes the interval for a drug
+ (NSString*)intervalDescription:(int)minutes;

// Returns a string that describes this type
+ (NSString*)getReminderTypeName;

@property (nonatomic, assign) int interval;
@property (nonatomic, assign) IntervalDrugReminderDrugLimitType limitType;
@property (nonatomic, assign) int maxNumDailyDoses;

@end