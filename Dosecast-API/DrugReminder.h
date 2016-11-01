//
//  DrugReminder.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"
#import "DrugReminderDelegate.h"

@interface DrugReminder : NSObject<NSMutableCopying> {
@private
    NSDate* treatmentStartDate;
    NSDate* treatmentEndDate;
    NSDate* nextReminder;
    NSDate* lastTaken;
    NSDate* overdueReminder;
    NSDate* takePillAfter; // A future time after which this drug may be taken
    NSDate* skipPillAfter; // A future time after which this drug may be skipped
    NSDate* maxPostponeTime; // The furthest time this drug may be postponed
    NSDate* expirationDate; // The expiration date

@protected
    BOOL archived;
    BOOL invisible;
	BOOL remindersEnabled;
    BOOL secondaryRemindersEnabled;
	int refillAlertDoses; // The number of doses left after which a refill alert will appear
    int expirationAlertDays; // The number of days prior to expiration to alert
    NSObject<DrugReminderDelegate>* __weak delegate;
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
expirationAlertDays:(int)expirationDays;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Get the time this drug may be postponed from
- (NSDate*)getBasePostponeTime;

// Update this reminder from the given server state
- (void) updateReminderStateWithLastTaken:(NSDate*)last
                    effLastTaken:(NSDate*)effLastTaken
                     notifyAfter:(NSDate*)notifyAfter;

// Returns whether this treatment has started
- (BOOL)treatmentStarted;

// Returns whether this treatment has ended
- (BOOL)treatmentEnded;

// Returns whether the treatment has started on the given day
- (BOOL)treatmentStartedOnDay:(NSDate*)day;

// Returns whether this treatment has ended on the given day
- (BOOL)treatmentEndedOnDay:(NSDate*)day;

// Returns whether a subsequent dose would fall after the given date
- (BOOL)wouldSubsequentDoseFallAfterDate:(NSDate*)date;

// Whether the current dose can be taken, skipped, or postponed
- (BOOL)canTakeDose;
- (BOOL)canSkipDose;
- (BOOL)canPostponeDose;

- (BOOL)wasTakenEarly;
- (BOOL)wasSkippedEarly;
- (BOOL)wasPostponed:(int*)postponeDuration;

// Returns the maximum number of local notifications that will be used by the current reminder
- (int)getMaxNumLocalNotificationsUsed;

// For future times that lie across a daylight savings boundary, unapply the daylight savings period 
- (void) unapplyDaylightSavingsToFutureTimesAcrossDaylightSavingsBoundary;

// Returns an array of NSDates representing the times of future doses due on the given day
- (NSArray*) getFutureDoseTimesDueOnDay:(NSDate*)day;

// Returns an array of NSDates representing the times of past doses due on the given day
- (NSArray*) getPastDoseTimesDueOnDay:(NSDate*)day;

// If overdue, returns the last scheduled dose time (prior to any postpones).
// If not overdue, returns the next scheduled dose time (prior to any postpones).
- (NSDate*) getCurrentScheduledTime;
- (NSDate*) getCurrentScheduledTimeFromEffLastTaken:(NSDate*)effLastTaken andLastTaken:(NSDate*)thisLastTaken;

// Returns an array of strings that describe the refill alert options
- (NSArray*) getRefillAlertOptions;

// Returns the index of the current refill alert option
- (int) getRefillAlertOptionNum;

// Sets the index of the current refill alert option
- (BOOL) setRefillAlertOptionNum:(int)optionNum;

// Returns an array of strings that describe the expiration alert options
- (NSArray*) getExpirationAlertOptions;

// Returns the index of the current expiration alert option
- (int) getExpirationAlertOptionNum;

// Sets the index of the current expiration alert option
- (BOOL) setExpirationAlertOptionNum:(int)optionNum;

- (BOOL) isExpiringSoon; // is the expiration date approaching (and an alert should be displayed)
- (BOOL) isExpired; // has the expiration date already passed

// Adjusts the reminders for a time zone change
- (void)adjustRemindersForTimeZoneChange:(NSTimeInterval)timeZoneInterval;

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

@property (nonatomic, strong) NSDate* treatmentStartDate;
@property (nonatomic, strong) NSDate* treatmentEndDate;
@property (nonatomic, strong) NSDate* nextReminder;
@property (nonatomic, strong) NSDate* lastTaken;
@property (nonatomic, strong) NSDate* overdueReminder;
@property (nonatomic, strong) NSDate* takePillAfter;
@property (nonatomic, strong) NSDate* skipPillAfter;
@property (nonatomic, strong) NSDate* maxPostponeTime;
@property (nonatomic, assign) BOOL archived;
@property (nonatomic, assign) BOOL invisible;
@property (nonatomic, assign) BOOL remindersEnabled;
@property (nonatomic, assign) BOOL secondaryRemindersEnabled;
@property (nonatomic, readonly) int refillAlertDoses;
@property (nonatomic, strong) NSDate* expirationDate;
@property (nonatomic, weak) NSObject<DrugReminderDelegate>* delegate;

@end