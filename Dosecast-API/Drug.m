//
//  Drug.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/7/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "Drug.h"
#import "DataModel.h"
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "DrugDosageManager.h"
#import "AddressBookContact.h"
#import "HistoryManager.h"
#import "DosecastUtil.h"
#import "ManagedDrugDosage.h"
#import "JSONConverter.h"
#import "Preferences.h"
#import "HistoryEvent.h"

// Basic drug info
static NSString *CreatedKey = @"created";
static NSString *DrugIDKey = @"pillId";
static NSString *DrugNameKey = @"name";
static NSString *DrugImageGUIDKey = @"imageGUID";
static NSString *DirectionsKey = @"instructions";
static NSString *NotesKey = @"notes";
static NSString *PersonIDKey = @"personId";
static NSString *PrescriptionNumKey = @"prescriptionNum";
static NSString *ReminderTypeKey = @"type";
static NSString *DosageTypeKey = @"dosageType";
static NSString *IntervalDrugReminderKey = @"interval";
static NSString *DoctorAddressBookContactName = @"doctor";
static NSString *PharmacyAddressBookContactName = @"pharmacy";
static NSString *ClientEditGuidKey = @"clientEditGuid";
static NSString *ClientEditTimeKey = @"clientEditTime";
static NSString *ServerEditGuidKey = @"serverEditGuid";
static NSString *LastHistoryTokenKey = @"lastEventToken";
static NSString *HistoryKey = @"history";
static NSString *DeletedKey = @"deleted";
static NSString *UndoHistoryEventGUIDKey = @"undoHistoryEventGUID";
static float epsilon = 0.0001;

@implementation Drug

@synthesize drugId;
@synthesize name;
@synthesize drugImageGUID;
@synthesize directions;
@synthesize notes;
@synthesize prescriptionNum;
@synthesize dosage;
@synthesize personId;
@synthesize created;
@synthesize clientEditGUID;
@synthesize clientEditTime;
@synthesize serverEditGUID;
@synthesize lastHistoryToken;
@synthesize deletedHistoryGUIDs;
@synthesize undoHistoryEventGUID;
@synthesize otherDrugPreferences;

- (id)init
{
	return [self init:nil
                 name:nil
        drugImageGUID:nil
              created:nil
             personId:nil
           directions:nil
        doctorContact:nil
      pharmacyContact:nil
      prescriptionNum:nil
             reminder:nil
               dosage:nil
                notes:nil
       clientEditGUID:nil
       clientEditTime:nil
        serverEditGUID:nil
            lastHistoryToken:0
            deletedHistoryGUIDs:[[NSMutableSet alloc] init]
 undoHistoryEventGUID:nil
 otherDrugPreferences:nil];
}

        - (id)init:(NSString*)dId
              name:(NSString*)n
     drugImageGUID:(NSString *)GUID
           created:(NSDate*)createdDate
          personId:(NSString*)pId
        directions:(NSString*)direc
     doctorContact:(AddressBookContact*)doctor
   pharmacyContact:(AddressBookContact*)pharmacy
   prescriptionNum:(NSString*)prescripNum
          reminder:(DrugReminder*)r
            dosage:(DrugDosage*)d
             notes:(NSString*)note
    clientEditGUID:(NSString*)clientGUID
    clientEditTime:(NSDate*)clientTime
    serverEditGUID:(NSString*)serverGUID
  lastHistoryToken:(long long)lastHistToken
deletedHistoryGUIDs:(NSMutableSet*)deletedHistGUIDs
undoHistoryEventGUID:(NSString*)undoEventGUID
otherDrugPreferences:(Preferences *)otherPrefs
{
    if ((self = [super init]))
    {
        created = createdDate;
		drugId = dId;
		name = n;
        if (!direc)
            direc = @"";
		directions = direc;
		reminder = r;
        reminder.delegate = self;
		dosage = d;
        if (!undoEventGUID)
            undoEventGUID = @"";
        undoHistoryEventGUID = undoEventGUID;
        if (!doctor)
            doctor = [[AddressBookContact alloc] init:DoctorAddressBookContactName contactType:AddressBookContactTypePerson];
        doctorContact = doctor;
        doctorContact.delegate = self;
        if (!pharmacy)
            pharmacy = [[AddressBookContact alloc] init:PharmacyAddressBookContactName contactType:AddressBookContactTypeOrganization];
        pharmacyContact = pharmacy;
        pharmacyContact.delegate = self;
        if (!prescripNum)
            prescripNum = @"";
        prescriptionNum = prescripNum;
        if (!note)
            note = @"";
        notes = note;
        if (!pId)
            pId = @"";
        personId = pId;
        lastHistoryToken = lastHistToken;
        drugImageGUID = GUID;
        clientEditGUID = clientGUID;
        if (!clientEditGUID)
            clientEditGUID = [DosecastUtil createGUID];
        clientEditTime = clientTime;
        if (!clientEditTime)
            clientEditTime = [NSDate date];
        serverEditGUID = serverGUID;
        if (!deletedHistGUIDs)
            deletedHistGUIDs = [[NSMutableSet alloc] init];
        deletedHistoryGUIDs = deletedHistGUIDs;
        if (!otherPrefs)
            otherPrefs = [[Preferences alloc] init:nil storeModifiedDate:NO];
        otherDrugPreferences = otherPrefs;
	}
	
    return self;	
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [[Drug alloc] init:[drugId mutableCopyWithZone:zone]
						 name:[name mutableCopyWithZone:zone]
                drugImageGUID:[drugImageGUID mutableCopyWithZone:zone]
                      created:[created copyWithZone:zone]
                     personId:[personId mutableCopyWithZone:zone]
				   directions:[directions mutableCopyWithZone:zone]
                doctorContact:[doctorContact mutableCopyWithZone:zone]
              pharmacyContact:[pharmacyContact mutableCopyWithZone:zone]
              prescriptionNum:[prescriptionNum mutableCopyWithZone:zone]
					 reminder:[reminder mutableCopyWithZone:zone]
					   dosage:[dosage mutableCopyWithZone:zone]
                        notes:[notes mutableCopyWithZone:zone]
            clientEditGUID:[clientEditGUID mutableCopyWithZone:zone]
               clientEditTime:[clientEditTime copyWithZone:zone]
               serverEditGUID:[serverEditGUID mutableCopyWithZone:zone]
             lastHistoryToken:lastHistoryToken
          deletedHistoryGUIDs:[deletedHistoryGUIDs mutableCopyWithZone:zone]
            undoHistoryEventGUID:[undoHistoryEventGUID mutableCopyWithZone:zone]
            otherDrugPreferences:[otherDrugPreferences mutableCopyWithZone:zone]];
}

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*) dict
{
    // Set the string values
	NSString* dId = [dict objectForKey:DrugIDKey];
	NSString* n = [dict objectForKey:DrugNameKey];
	NSString* direc = [dict objectForKey:DirectionsKey];
	
	// Set the created value
	NSDate *createdDate = nil;
	NSNumber* createdNum = [dict objectForKey:CreatedKey];
	if (createdNum && [createdNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		createdDate = [NSDate dateWithTimeIntervalSince1970:[createdNum longLongValue]];
	}
    
	// Set the type of drug reminder
	NSString* reminderTypeStr = [dict objectForKey:ReminderTypeKey];
	DrugReminder* r = nil;
	if ([reminderTypeStr caseInsensitiveCompare:[IntervalDrugReminder getReminderTypeName]] == NSOrderedSame)
	{
		// Look for 0 intervals as a way of identifying as-needed reminders
		int i = -1;
		NSNumber* intervalNum = [dict objectForKey:IntervalDrugReminderKey];
		if (intervalNum)
			i = [intervalNum intValue];
		
		if (i == 0)
			r = [[AsNeededDrugReminder alloc] initWithDictionary:dict];
		else
			r = [[IntervalDrugReminder alloc] initWithDictionary:dict];
	}
	else if ([reminderTypeStr caseInsensitiveCompare:[ScheduledDrugReminder getReminderTypeName]] == NSOrderedSame)
		r = [[ScheduledDrugReminder alloc] initWithDictionary:dict];
	else
		r = [[ScheduledDrugReminder alloc] initWithDictionary:dict];
	
	// Set the per-pill preferences items    
	DrugDosageManager* dosageManager = [DrugDosageManager getInstance];
	DrugDosage* d = nil;
    NSString* prescripNum = nil;
    NSString* note = nil;
    NSString* pId = nil;
    NSString* imageGUID = nil;
    NSString* undoEventGUID = nil;
    
    NSString* dosageTypeStr = nil;
    if ([Preferences readPreferenceFromDictionary:dict key:DosageTypeKey value:&dosageTypeStr modifiedDate:nil perDevice:nil] && dosageTypeStr)
    {
        d = [dosageManager createDrugDosageWithFileTypeName:dosageTypeStr withDictionary:dict];
        if (!d)
            d = [dosageManager createDrugDosageWithTypeName:dosageManager.defaultTypeName withDictionary:dict];
    }
    else
        d = [dosageManager createDrugDosageWithTypeName:dosageManager.defaultTypeName withDictionary:dict];

    [Preferences readPreferenceFromDictionary:dict key:PrescriptionNumKey value:&prescripNum modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:NotesKey value:&note modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:PersonIDKey value:&pId modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:DrugImageGUIDKey value:&imageGUID modifiedDate:nil perDevice:nil];
    [Preferences readPreferenceFromDictionary:dict key:UndoHistoryEventGUIDKey value:&undoEventGUID modifiedDate:nil perDevice:nil];
				
    // Set the doctor and pharmacy
    AddressBookContact* doctor = [[AddressBookContact alloc] initWithDictionary:dict name:DoctorAddressBookContactName contactType:AddressBookContactTypePerson];
    AddressBookContact* pharmacy = [[AddressBookContact alloc] initWithDictionary:dict name:PharmacyAddressBookContactName contactType:AddressBookContactTypeOrganization];

    NSString* clientGUID = [dict objectForKey:ClientEditGuidKey];
    NSString* serverGUID = [dict objectForKey:ServerEditGuidKey];
    
    NSDate* clientTime = nil;
	NSNumber* clientTimeNum = [dict objectForKey:ClientEditTimeKey];
	if (clientTimeNum && [clientTimeNum longLongValue] > 0)
	{
		// Convert to NSDate from UNIX time
		clientTime = [NSDate dateWithTimeIntervalSince1970:[clientTimeNum longLongValue]];
	}

    long long lastHistToken = 0;
    NSMutableSet* deletedHistGUIDs = [[NSMutableSet alloc] init];
    NSMutableDictionary* historyDict = [dict objectForKey:HistoryKey];
    if (historyDict)
    {
        NSNumber* lastHistoryTokenNum = [historyDict objectForKey:LastHistoryTokenKey];
        if (lastHistoryTokenNum)
            lastHistToken = [lastHistoryTokenNum longLongValue];
        
        NSMutableArray* thisDeletedHistGUIDs = [historyDict objectForKey:DeletedKey];
        if (thisDeletedHistGUIDs)
            [deletedHistGUIDs addObjectsFromArray:thisDeletedHistGUIDs];
    }

    Preferences* otherPrefs = [[Preferences alloc] init:nil storeModifiedDate:NO];
    [otherPrefs readFromDictionary:dict];
    
	return [self init:dId
				 name:n
                drugImageGUID:imageGUID
              created:createdDate
             personId:pId
		   directions:direc
        doctorContact:doctor
      pharmacyContact:pharmacy
      prescriptionNum:prescripNum
			 reminder:r
			   dosage:d
                notes:note
       clientEditGUID:clientGUID
       clientEditTime:clientTime
       serverEditGUID:serverGUID
            lastHistoryToken:lastHistToken
            deletedHistoryGUIDs:deletedHistGUIDs
            undoHistoryEventGUID:undoEventGUID
 otherDrugPreferences:otherPrefs];
}

// Notifies when a contact has been changed
- (void)addressBookContactChanged
{
    clientEditGUID = [DosecastUtil createGUID];
    clientEditTime = [NSDate date];
    [DataModel getInstance].syncNeeded = YES;
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest
{
    [otherDrugPreferences populateDictionary:dict forSyncRequest:forSyncRequest]; // write these out first so that where they overlap with other drug data, the drug data will overwrite these
    
    HistoryManager* historyManager = [HistoryManager getInstance];
	if (drugId)
		[dict setObject:drugId forKey:DrugIDKey];
    if (name)
        [dict setObject:name forKey:DrugNameKey];
    if (directions)
        [dict setObject:directions forKey:DirectionsKey];
    
    NSDate* createdDate = created;
    if (!createdDate && forSyncRequest && drugId) // if we don't have a created date and this is for a server request, calculate one
    {
        createdDate = [historyManager oldestEventForDrugId:drugId];
    }
    if (createdDate)
        [dict setObject:[NSNumber numberWithLongLong:(long long)[created timeIntervalSince1970]] forKey:CreatedKey];
    
    [Preferences populatePreferenceInDictionary:dict key:PrescriptionNumKey value:prescriptionNum modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:NotesKey value:notes modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:PersonIDKey value:personId modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:DrugImageGUIDKey value:drugImageGUID modifiedDate:nil perDevice:NO];
    [Preferences populatePreferenceInDictionary:dict key:UndoHistoryEventGUIDKey value:undoHistoryEventGUID modifiedDate:nil perDevice:NO];
    
    [doctorContact populateDictionary:dict forSyncRequest:forSyncRequest];
    [pharmacyContact populateDictionary:dict forSyncRequest:forSyncRequest];

	[reminder populateDictionary:dict forSyncRequest:forSyncRequest];
	[dosage populateDictionary:dict forSyncRequest:forSyncRequest];
    
    if (clientEditGUID)
        [dict setObject:clientEditGUID forKey:ClientEditGuidKey];
    if (serverEditGUID)
        [dict setObject:serverEditGUID forKey:ServerEditGuidKey];
    
	long long clientTimeVal = -1;
	if (clientEditTime != nil)
	{
		clientTimeVal = (long long)[clientEditTime timeIntervalSince1970];
	}
	[dict setObject:[NSNumber numberWithLongLong:clientTimeVal] forKey:ClientEditTimeKey];
    
    NSMutableDictionary* historyDict = [dict objectForKey:HistoryKey];
    if (!historyDict)
        historyDict = [[NSMutableDictionary alloc] init];

    if (lastHistoryToken >= 0)
    	[historyDict setObject:[NSNumber numberWithLongLong:lastHistoryToken] forKey:LastHistoryTokenKey];
    
    if (deletedHistoryGUIDs)
    {
        NSMutableArray* deletedHistoryGUIDArray = [NSMutableArray arrayWithArray:[deletedHistoryGUIDs allObjects]];
        [historyDict setObject:deletedHistoryGUIDArray forKey:DeletedKey];
    }
    
    [dict setObject:historyDict forKey:HistoryKey];
    
}

// Returns whether the remaining quantity is empty
- (BOOL) isEmpty
{
    if (reminder.refillAlertDoses <= 0)
        return NO;
    
    float remainingQuantity = 0.0f;
    [dosage getValueForRemainingQuantity:&remainingQuantity];
	if (remainingQuantity < epsilon) // if we're empty
		return YES;
	else
	{
		float remainingDoses;
		if ([dosage getRemainingDoses:&remainingDoses])
		{
			float remainingDosesFrac = remainingDoses - floorf(remainingDoses);
			int remainingDosesInt = (int)remainingDoses;
			if (remainingDosesFrac > (1.0f - epsilon))
				remainingDosesInt += 1;
			
			return remainingDosesInt == 0;
		}
		else
			return NO;		
	}
}

// Returns whether this is a managed drug
- (BOOL) isManaged
{
    return [dosage isKindOfClass:[ManagedDrugDosage class]];
}

- (BOOL)allowReminders
{
    return (![self isManaged] || !((ManagedDrugDosage*)dosage).isDiscontinued);
}

- (BOOL)allowUserActions
{
    return (![self isManaged] || !((ManagedDrugDosage*)dosage).isDiscontinued);
}

- (NSString*)getDrugId
{
    return drugId;
}

// Returns whether the remaining quantity is running low and a refill is needed
- (BOOL) isRunningLow
{
	float remainingDoses;
	if ([dosage getRemainingDoses:&remainingDoses] && reminder.refillAlertDoses > 0)
	{
		float remainingDosesFrac = remainingDoses - floorf(remainingDoses);
		int remainingDosesInt = (int)remainingDoses;
		if (remainingDosesFrac > (1.0f - epsilon))
			remainingDosesInt += 1;
		
		return remainingDosesInt <= reminder.refillAlertDoses;
	}
	else
		return NO;
}

// Returns whether a refill notification needs to be displayed for this drug
- (BOOL) needsRefillNotification
{
	float remainingDoses;
	if ([dosage getRemainingDoses:&remainingDoses] && reminder.refillAlertDoses > 0)
	{
		float remainingDosesFrac = remainingDoses - floorf(remainingDoses);
		int remainingDosesInt = (int)remainingDoses;
		if (remainingDosesFrac > (1.0f - epsilon))
			remainingDosesInt += 1;

		return remainingDosesInt == reminder.refillAlertDoses || remainingDosesInt == 0;
	}
	else
		return NO;
}

// Return the daily dose count for the given date if dose limits are used
- (int) getDailyDoseCountAsOfDate:(NSDate*)date
{
    HistoryManager* historyManager = [HistoryManager getInstance];
    if ([reminder isKindOfClass:[AsNeededDrugReminder class]])
    {
        AsNeededDrugReminder* asNeededReminder = (AsNeededDrugReminder*)reminder;
        if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypePer24Hours)
            return [historyManager getNumTakePillEventsForPrior24Hours:date drugId:drugId earliestEventTime:nil];
        else if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypePerDay)
            return [historyManager getNumTakePillEventsForDay:date drugId:drugId];
        else
            return -1;
    }
    else if ([reminder isKindOfClass:[IntervalDrugReminder class]])
    {
        IntervalDrugReminder* intervalReminder = (IntervalDrugReminder*)reminder;
        if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypePer24Hours)
            return [historyManager getNumTakePillEventsForPrior24Hours:date drugId:drugId earliestEventTime:nil];
        else if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypePerDay)
            return [historyManager getNumTakePillEventsForDay:date drugId:drugId];
        else
            return -1;
    }
    else
        return -1;    
}

// Returns whether the dose limit would be exceeded if a dose were taken on the given date. If so, returns the next available time the dose could be taken
- (BOOL) wouldExceedDoseLimitIfTakenAtDate:(NSDate*)date
                     nextAvailableDoseTime:(NSDate**)nextAvailableDoseTime
                           adjustDoseLimit:(int)adjustDoseLimit // an amount to adjust the dose limit by for pro-forma calculations (into the future)
{
    if (nextAvailableDoseTime)
        *nextAvailableDoseTime = nil;
        
    HistoryManager* historyManager = [HistoryManager getInstance];

    if ([reminder isKindOfClass:[AsNeededDrugReminder class]])
    {
        AsNeededDrugReminder* asNeededReminder = (AsNeededDrugReminder*)reminder;
        if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypeNever || asNeededReminder.maxNumDailyDoses <= 0)
            return NO;
        else
        {
            BOOL wouldExceedDoseLimit = NO;
            
            // Calculate the next available dose time (if we would exceed the max dose limit)
            if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypePer24Hours)
            {
                NSDate* earliestEventTime = nil;
                int dailyDoseCount = [historyManager getNumTakePillEventsForPrior24Hours:date drugId:drugId earliestEventTime:&earliestEventTime];
                wouldExceedDoseLimit = (dailyDoseCount >= asNeededReminder.maxNumDailyDoses+adjustDoseLimit);
                if (wouldExceedDoseLimit && nextAvailableDoseTime && earliestEventTime)
                    *nextAvailableDoseTime = [DosecastUtil addTimeIntervalToDate:date timeInterval:[earliestEventTime timeIntervalSinceDate:[DosecastUtil addDaysToDate:date numDays:-1]]];
            }
            else // AsNeededDrugReminderDrugLimitTypePerDay
            {
                int dailyDoseCount = [historyManager getNumTakePillEventsForDay:date drugId:drugId];
                wouldExceedDoseLimit = (dailyDoseCount >= asNeededReminder.maxNumDailyDoses+adjustDoseLimit);
                if (wouldExceedDoseLimit && nextAvailableDoseTime)
                    *nextAvailableDoseTime = [DosecastUtil addDaysToDate:[DosecastUtil getMidnightOnDate:date] numDays:1];
            }
            
            return wouldExceedDoseLimit;
        }
    }
    else if ([reminder isKindOfClass:[IntervalDrugReminder class]])
    {
        IntervalDrugReminder* intervalReminder = (IntervalDrugReminder*)reminder;
        if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypeNever || intervalReminder.maxNumDailyDoses <= 0)
            return NO;
        else
        {
            BOOL wouldExceedDoseLimit = NO;
            
            // Calculate the next available dose time (if we would exceed the max dose limit)
            if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypePer24Hours)
            {
                NSDate* earliestEventTime = nil;
                int dailyDoseCount = [historyManager getNumTakePillEventsForPrior24Hours:date drugId:drugId earliestEventTime:&earliestEventTime];
                wouldExceedDoseLimit = (dailyDoseCount >= intervalReminder.maxNumDailyDoses+adjustDoseLimit);
                if (wouldExceedDoseLimit && nextAvailableDoseTime && earliestEventTime)
                    *nextAvailableDoseTime = [DosecastUtil addTimeIntervalToDate:date timeInterval:[earliestEventTime timeIntervalSinceDate:[DosecastUtil addDaysToDate:date numDays:-1]]];
            }
            else // IntervalDrugReminderDrugLimitTypePerDay
            {
                int dailyDoseCount = [historyManager getNumTakePillEventsForDay:date drugId:drugId];
                wouldExceedDoseLimit = (dailyDoseCount >= intervalReminder.maxNumDailyDoses+adjustDoseLimit);
                if (wouldExceedDoseLimit && nextAvailableDoseTime)
                    *nextAvailableDoseTime = [DosecastUtil addDaysToDate:[DosecastUtil getMidnightOnDate:date] numDays:1];
            }
            
            if (wouldExceedDoseLimit && nextAvailableDoseTime && (*nextAvailableDoseTime))
            {
                // Check if there's a next reminder occurring after the next available dose time (if we would exceed the max dose limit)
                // If so, set the next available dose time to the next reminder time.
                if (intervalReminder.nextReminder && [intervalReminder.nextReminder timeIntervalSinceDate:(*nextAvailableDoseTime)] > 0)
                    *nextAvailableDoseTime = intervalReminder.nextReminder;
                
                // Check if the next available dose time occurs during bedtime. If so, shift to the end of bedtime.
                DataModel* dataModel = [DataModel getInstance];
                if ([dataModel dateOccursDuringBedtime:(*nextAvailableDoseTime)])
                {
                    NSDate* bedtimeStart = nil;
                    NSDate* bedtimeEnd = nil;
                    [dataModel getBedtimeAsDates:&bedtimeStart bedtimeEnd:&bedtimeEnd];
                    if ([DosecastUtil areDatesOnSameDay:(*nextAvailableDoseTime) date2:bedtimeStart])
                        *nextAvailableDoseTime = [dataModel getBedtimeEndDateOnDay:[DosecastUtil addDaysToDate:(*nextAvailableDoseTime) numDays:1]];
                    else
                        *nextAvailableDoseTime = [dataModel getBedtimeEndDateOnDay:(*nextAvailableDoseTime)];
                }
            }
            
            return wouldExceedDoseLimit;
        }
    }
    else
        return NO;
}

// Returns whether the dose limit would be exceeded if a dose were taken on the given date. If so, returns the next available time the dose could be taken
- (BOOL) wouldExceedDoseLimitIfTakenAtDate:(NSDate*)date
                     nextAvailableDoseTime:(NSDate**)nextAvailableDoseTime
{
    return [self wouldExceedDoseLimitIfTakenAtDate:date nextAvailableDoseTime:nextAvailableDoseTime adjustDoseLimit:0];
}

// Returns whether the next dose would exceed the dose limit if a dose were taken on the given date.
- (BOOL) wouldNextDoseExceedDoseLimitIfTakenAtDate:(NSDate*)date
{
    if ([reminder isKindOfClass:[IntervalDrugReminder class]])
    {
        // Check whether we would be at or exceed the dose limit by taking this drug
        NSDate* nextAvailableDoseTime = nil;
        if ([self wouldExceedDoseLimitIfTakenAtDate:date nextAvailableDoseTime:&nextAvailableDoseTime adjustDoseLimit:-1])
        {
            IntervalDrugReminder* intervalReminder = (IntervalDrugReminder*)reminder;
            
            NSDate* baseTime = date;
            
            NSDate* nextReminder = [baseTime dateByAddingTimeInterval:intervalReminder.interval];

            // Check if the next reminder time occurs before the next available dose time
            if ([nextReminder timeIntervalSinceDate:nextAvailableDoseTime] < 0)
                return YES;
            else // If the next reminder time occurs after, make sure we still aren't at the dose limit at that time
                return [self wouldExceedDoseLimitIfTakenAtDate:nextReminder nextAvailableDoseTime:nil adjustDoseLimit:-2];
        }
        else
            return NO;
    }
    else
        return NO;
}

// Returns whether the dose limit is being exceeded
- (BOOL) isExceedingDoseLimit
{
    NSDate* nextAvailableDoseTime = nil;
    if ([self wouldExceedDoseLimitIfTakenAtDate:[NSDate date] nextAvailableDoseTime:&nextAvailableDoseTime adjustDoseLimit:0] &&
        (reminder.nextReminder || reminder.overdueReminder))
    {
        NSDate* checkReminder = reminder.nextReminder;
        if (!checkReminder)
            checkReminder = reminder.overdueReminder;
        
        // Check if the check reminder time occurs before the next available dose time
        if ([checkReminder timeIntervalSinceDate:nextAvailableDoseTime] < 0)
            return YES;
        else // If the next reminder time occurs after, make sure we still aren't at the dose limit at that time
            return [self wouldExceedDoseLimitIfTakenAtDate:checkReminder nextAvailableDoseTime:nil adjustDoseLimit:0];
    }
    else
        return NO;
}

- (void)refreshDrugInternalState
{
    NSDate* now = [NSDate date];
    BOOL isOverdue = NO;
    while (reminder.nextReminder && [now timeIntervalSinceDate:reminder.nextReminder] >= 0)
    {
        isOverdue = YES;
        reminder.overdueReminder = reminder.nextReminder;
        reminder.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        reminder.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        if ([reminder isKindOfClass:[IntervalDrugReminder class]])
        {
            reminder.nextReminder = nil;
            reminder.maxPostponeTime = [DosecastUtil addDaysToDate:now numDays:1]; // postpone up to 1 day from now
        }
        else if ([reminder isKindOfClass:[ScheduledDrugReminder class]])
        {
            ScheduledDrugReminder* scheduledReminder = ((ScheduledDrugReminder*)reminder);
            
            // For overdue pills, you postpone the current reminder - and therefore the maxPostponeTime is
            // the next reminder, not the following one
            reminder.maxPostponeTime = [scheduledReminder getReminderTimeAfterTime:reminder.nextReminder remindAtLimit:YES];
            reminder.nextReminder = [scheduledReminder getReminderTimeAfterTime:reminder.nextReminder remindAtLimit:NO];
        }
        else // AsNeededDrugReminder
        {
            reminder.nextReminder = nil;
            reminder.maxPostponeTime = nil;
        }
    }
    
    // For overdue drugs with reminders disabled, check for missed doses now
    if (isOverdue && !reminder.remindersEnabled)
    {
        [[HistoryManager getInstance] checkForMissedDosesForDrugId:drugId errorMessage:nil];
    }
    
    if (reminder.takePillAfter && [reminder.takePillAfter timeIntervalSince1970] > 1 && [now timeIntervalSinceDate:reminder.takePillAfter] >= 0)
    {
        if ([reminder isKindOfClass:[IntervalDrugReminder class]] || [reminder isKindOfClass:[AsNeededDrugReminder class]] || reminder.overdueReminder || reminder.nextReminder)
            reminder.takePillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        else // ScheduledDrugReminder
            reminder.takePillAfter = nil;
    }
    
    if (reminder.skipPillAfter && [reminder.skipPillAfter timeIntervalSince1970] > 1 && [now timeIntervalSinceDate:reminder.skipPillAfter] >= 0)
    {
        if (reminder.overdueReminder || reminder.nextReminder)
            reminder.skipPillAfter = [NSDate dateWithTimeIntervalSince1970:1];
        else
            reminder.skipPillAfter = nil;
    }
}

- (DrugReminder*) reminder
{
    return reminder;
}

- (void) setReminder:(DrugReminder *)r
{
    reminder.delegate = nil;
    reminder = r;
    reminder.delegate = self;
}

- (AddressBookContact*) doctorContact
{
    return doctorContact;
}

- (void) setDoctorContact:(AddressBookContact *)doctor
{
    if (!doctor)
        doctor = [[AddressBookContact alloc] init:DoctorAddressBookContactName contactType:AddressBookContactTypePerson];

    doctorContact.delegate = nil;
    doctorContact = doctor;
    doctorContact.delegate = self;
}

- (AddressBookContact*) pharmacyContact
{
    return pharmacyContact;
}

- (void) setPharmacyContact:(AddressBookContact *)pharmacy
{
    if (!pharmacy)
        pharmacy = [[AddressBookContact alloc] init:PharmacyAddressBookContactName contactType:AddressBookContactTypeOrganization];

    pharmacyContact.delegate = nil;
    pharmacyContact = pharmacy;
    pharmacyContact.delegate = self;
}

// Undo support
- (void) createUndoState:(NSString*)createdHistoryEventGUID
{
    if (!createdHistoryEventGUID)
        createdHistoryEventGUID = @"";
    undoHistoryEventGUID = createdHistoryEventGUID;    
}

- (void) performUndo
{
    if ([undoHistoryEventGUID length] == 0)
        return;

    HistoryManager* historyManager = [HistoryManager getInstance];
    HistoryEvent* event = [historyManager getEventForGUID:undoHistoryEventGUID errorMessage:nil];
    
    if (!event)
        return;
    
    // Calculate impact to remaining/refill quantity of deleting this record
    float remainingQuantityOffset = 0.0f;
    int refillQuantityOffset = 0;
    if (event)
    {
        [historyManager getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&remainingQuantityOffset refillQuantityOffset:&refillQuantityOffset];
        [historyManager deleteEvent:event notifyServer:YES];
    }
    
    // Update remaining quantity and refills remaining, if they were changed by the history
    if (fabsf(remainingQuantityOffset) > epsilon)
    {
        float remainingQuantity = 0.0f;
        [dosage getValueForRemainingQuantity:&remainingQuantity];
        [dosage setValueForRemainingQuantity:remainingQuantity - remainingQuantityOffset];
    }
    
    if (abs(refillQuantityOffset) > 0)
    {
        int refillQuantity = [dosage getRefillsRemaining];
        [dosage setRefillsRemaining:refillQuantity - refillQuantityOffset];
    }
    
    undoHistoryEventGUID = @"";
}

- (BOOL) hasUndoState
{
    return ([undoHistoryEventGUID length] > 0 && [[HistoryManager getInstance] getEventForGUID:undoHistoryEventGUID errorMessage:nil]);
}

- (NSString*) undoOperation
{
    if ([undoHistoryEventGUID length] == 0)
        return nil;
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    HistoryEvent* undoEvent = [historyManager getEventForGUID:undoHistoryEventGUID errorMessage:nil];
    if (undoEvent)
        return undoEvent.operation;
    else
        return nil;
}

@end
