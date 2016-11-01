//
//  AsNeededDrugReminder.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/8/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "AsNeededDrugReminder.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "Preferences.h"

static NSString *ReminderTypeKey = @"type";
static NSString *IntervalReminderTypeName = @"interval";
static NSString *IntervalDrugReminderKey = @"interval";
static NSString *LimitTypeKey = @"limitType";
static NSString *MaxNumDailyDosesKey = @"maxNumDailyDoses";

@implementation AsNeededDrugReminder

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
            limitType:AsNeededDrugReminderDrugLimitTypeNever
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
       limitType:(AsNeededDrugReminderDrugLimitType)limit
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
        
        if (limit == AsNeededDrugReminderDrugLimitTypeNever)
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
		
    AsNeededDrugReminderDrugLimitType limit = AsNeededDrugReminderDrugLimitTypeNever;
    int maxDailyDoses = 0;
    NSString* limitTypeStr = nil;
    [Preferences readPreferenceFromDictionary:dict key:LimitTypeKey value:&limitTypeStr modifiedDate:nil perDevice:nil];
    if (limitTypeStr)
        limit = (AsNeededDrugReminderDrugLimitType)[limitTypeStr intValue];

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
            limitType:limit 
     maxNumDailyDoses:maxDailyDoses];    
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[AsNeededDrugReminder alloc] init:[self.treatmentStartDate copyWithZone:zone]
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
                                    limitType:limitType
                             maxNumDailyDoses:maxNumDailyDoses];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
	[super populateDictionary:dict forSyncRequest:forSyncRequest];
	
	[dict setObject:[NSString stringWithString:IntervalReminderTypeName] forKey:ReminderTypeKey];
	// populate the dictionary as if this is an interval drug reminder with an interval of 0
	[dict setObject:[NSNumber numberWithInt:0] forKey:IntervalDrugReminderKey];
    
    [Preferences populatePreferenceInDictionary:dict key:LimitTypeKey value:[NSString stringWithFormat:@"%d", (int)limitType] modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:MaxNumDailyDosesKey value:[NSString stringWithFormat:@"%d", maxNumDailyDoses] modifiedDate:nil perDevice:NO];
}

// Return a description for the dose limit settings
- (NSString*) getDoseLimitDescription
{
    if (limitType == AsNeededDrugReminderDrugLimitTypeNever)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTypeNone", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The Dose Limit Never type label in the Dose Limit view"]);
    }
    else if (limitType == AsNeededDrugReminderDrugLimitTypePerDay)
    {
        if ([DosecastUtil shouldUseSingularForInteger:maxNumDailyDoses])
            return [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePerDaySingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Max 1 dose per day", @"The singular dose limit phrase for per day types in the Drug Edit view"])];
        else
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditDoseLimitPhrasePerDayPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Max %d doses per day", @"The plural dose limit phrase for per day types in the Drug Edit view"]), maxNumDailyDoses];            
    }
    else // AsNeededDrugReminderDrugLimitTypePer24Hours
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
    return [[NSMutableArray alloc] init];
}

// Returns an array of NSDates representing the times of past doses due on the given day
- (NSArray*) getPastDoseTimesDueOnDay:(NSDate*)day
{
    return [[NSMutableArray alloc] init];    
}

// Whether the current dose can be taken, skipped or postponed
- (BOOL)canTakeDose
{
	return [super canTakeDose];
}

- (BOOL)canSkipDose
{
	return NO;
}

- (BOOL)canPostponeDose
{
	return NO;
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

- (AsNeededDrugReminderDrugLimitType) limitType
{
    return limitType;
}

- (void) setLimitType:(AsNeededDrugReminderDrugLimitType)newLimitType
{
    if (limitType == newLimitType)
        return;
    
    limitType = newLimitType;
    if (newLimitType == AsNeededDrugReminderDrugLimitTypeNever)
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
    if (maxNumDailyDoses == max)
        return;
    
    if (limitType == AsNeededDrugReminderDrugLimitTypeNever && max != 0)
        max = 0;
    else if (limitType != AsNeededDrugReminderDrugLimitTypeNever && max <= 0)
        max = 1;
    
    maxNumDailyDoses = max;
}


@end