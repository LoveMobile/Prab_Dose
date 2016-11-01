//
//  AsNeededDrugReminder.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugReminder.h"

typedef enum {
	AsNeededDrugReminderDrugLimitTypeNever     	= 0,
	AsNeededDrugReminderDrugLimitTypePerDay   	= 1,
	AsNeededDrugReminderDrugLimitTypePer24Hours = 2
} AsNeededDrugReminderDrugLimitType;

@interface AsNeededDrugReminder : DrugReminder
{
@private
    AsNeededDrugReminderDrugLimitType limitType;
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
      limitType:(AsNeededDrugReminderDrugLimitType)limit
maxNumDailyDoses:(int)maxDailyDoses;

- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Whether the current dose can be taken, skipped or postponed
- (BOOL)canTakeDose;
- (BOOL)canSkipDose;
- (BOOL)canPostponeDose;

// Return a description for the dose limit settings
- (NSString*) getDoseLimitDescription;

// Returns a string that describes this type
+ (NSString*)getReminderTypeName;

@property (nonatomic, assign) AsNeededDrugReminderDrugLimitType limitType;
@property (nonatomic, assign) int maxNumDailyDoses;

@end