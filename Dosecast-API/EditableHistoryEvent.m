//
//  EditableHistoryEvent.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 2/20/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "EditableHistoryEvent.h"
#import "HistoryEvent.h"
#import "HistoryManager.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "JSONConverter.h"
#import "DrugDosage.h"
#import "VersionNumber.h"
#import "Drug.h"
#import "GlobalSettings.h"
#import "DrugDosageManager.h"

static const double MIN_PER_DAY = 60*24;
static NSString *DosageTypeKey = @"dosageType";
static NSString *KeyKey = @"key";
static NSString *ValueKey = @"value";
static NSString *SyncPreferencesKey = @"syncPreferences";
static NSString *RefillQuantityKey = @"refillAmount";
static float epsilon = 0.0001;

@implementation EditableHistoryEvent

- (id)init
{
    return [self init:nil];
}

- (id)init:(HistoryEvent*)e
    drugId:(NSString*)drugId
creationDate:(NSDate*)creationDate
 operation:(NSString*)operation
operationData:(NSString*)operationData
scheduleDate:(NSDate*)scheduleDate
    dosage:(DrugDosage*)dosage
{
    if ((self = [super init]))
    {
        event = e;
        editedDrugId = drugId;
        editedGUID = nil;
        editedOperation = operation;
        editedCreationDate = creationDate;
        editedOperationData = operationData;
        editedEventDescription = nil;
        editedScheduleDate = scheduleDate;
        clearedScheduleDate = NO;
        clearedOperationData = NO;
        editedDosageType = nil;
        editedDosageTypePrefKey1 = nil;
        editedDosageTypePrefValue1 = nil;
        editedDosageTypePrefKey2 = nil;
        editedDosageTypePrefValue2 = nil;
        editedDosageTypePrefKey3 = nil;
        editedDosageTypePrefValue3 = nil;
        editedDosageTypePrefKey4 = nil;
        editedDosageTypePrefValue4 = nil;
        editedDosageTypePrefKey5 = nil;
        editedDosageTypePrefValue5 = nil;
        clearedDosageTypePrefKey1 = NO;
        clearedDosageTypePrefValue1 = NO;
        clearedDosageTypePrefKey2 = NO;
        clearedDosageTypePrefValue2 = NO;
        clearedDosageTypePrefKey3 = NO;
        clearedDosageTypePrefValue3 = NO;
        clearedDosageTypePrefKey4 = NO;
        clearedDosageTypePrefValue4 = NO;
        clearedDosageTypePrefKey5 = NO;
        clearedDosageTypePrefValue5 = NO;
        
        if (!e)
        {
            if (dosage)
            {
                [self setDosageTypeToDrugDosage:dosage];
            }
            else if (drugId)
            {
                Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
                [self setDosageTypeToDrugDosage:d.dosage];
            }
        }
    }
    
    return self;
}

- (id)init:(NSString*)drugId
creationDate:(NSDate*)creationDate
 operation:(NSString*)operation
operationData:(NSString*)operationData
scheduleDate:(NSDate*)scheduleDate
    dosage:(DrugDosage*)dosage
{
    return [self init:nil
               drugId:drugId
         creationDate:creationDate
            operation:operation
        operationData:operationData
         scheduleDate:scheduleDate
            dosage:dosage];
}

- (id)init:(HistoryEvent*)e
{
    return [self init:e
               drugId:nil
         creationDate:nil
            operation:nil
        operationData:nil
         scheduleDate:nil
            dosage:nil];
}

+ (EditableHistoryEvent*) editableHistoryEventWithHistoryEvent:(HistoryEvent*)e
{
    return [[EditableHistoryEvent alloc] init:e];
}

+ (EditableHistoryEvent*) editableHistoryEvent:(NSString*)drugId
                                  creationDate:(NSDate*)creationDate
                                     operation:(NSString*)operation
                                 operationData:(NSString*)operationData
                                  scheduleDate:(NSDate*)scheduleDate
                                        dosage:(DrugDosage*)dosage
{
    return [[EditableHistoryEvent alloc] init:drugId
                                 creationDate:creationDate
                                    operation:operation
                                operationData:operationData
                                 scheduleDate:scheduleDate
                                       dosage:dosage];
}

- (void) clearEditedData
{
    editedDrugId = nil;
    editedGUID = nil;
    editedOperation = nil;
    editedCreationDate = nil;
    editedOperationData = nil;
    editedEventDescription = nil;
    editedScheduleDate = nil;
    editedDosageType = nil;
    editedDosageTypePrefKey1 = nil;
    editedDosageTypePrefValue1 = nil;
    editedDosageTypePrefKey2 = nil;
    editedDosageTypePrefValue2 = nil;
    editedDosageTypePrefKey3 = nil;
    editedDosageTypePrefValue3 = nil;
    editedDosageTypePrefKey4 = nil;
    editedDosageTypePrefValue4 = nil;
    editedDosageTypePrefKey5 = nil;
    editedDosageTypePrefValue5 = nil;
    clearedScheduleDate = NO;
    clearedOperationData = NO;
    clearedDosageTypePrefKey1 = NO;
    clearedDosageTypePrefValue1 = NO;
    clearedDosageTypePrefKey2 = NO;
    clearedDosageTypePrefValue2 = NO;
    clearedDosageTypePrefKey3 = NO;
    clearedDosageTypePrefValue3 = NO;
    clearedDosageTypePrefKey4 = NO;
    clearedDosageTypePrefValue4 = NO;
    clearedDosageTypePrefKey5 = NO;
    clearedDosageTypePrefValue5 = NO;
}

- (BOOL) commitChanges
{
	if (!self.changed)
		return NO;

    // History events are immutable, so create a new event and delete the old one
    HistoryEvent* oldEvent = event;
    
    event = [[HistoryManager getInstance] addHistoryEvent:self.drugId
                                                     guid:nil
                                             creationDate:self.creationDate
                                         eventDescription:self.eventDescription
                                                operation:self.operation
                                            operationData:self.operationData
                                             scheduleDate:self.scheduleDate
                                          preferencesDict:[self createHistoryEventPreferencesDict]
                                        isManuallyCreated:YES
                                             notifyServer:YES
                                             errorMessage:nil];
    
    if (oldEvent)
        [[HistoryManager getInstance] deleteEvent:oldEvent notifyServer:YES];

	[self clearEditedData];
    
	return YES;
}

- (NSString*) getDosageTypePrefValue:(NSString*)prefKey
{
    if (!prefKey)
        return nil;
    
    NSString* valStr = nil;
    if (self.dosageTypePrefKey1 && [self.dosageTypePrefKey1 isEqualToString:prefKey])
        valStr = self.dosageTypePrefValue1;
    else if (self.dosageTypePrefKey2 && [self.dosageTypePrefKey2 isEqualToString:prefKey])
        valStr = self.dosageTypePrefValue2;
    else if (self.dosageTypePrefKey3 && [self.dosageTypePrefKey3 isEqualToString:prefKey])
        valStr = self.dosageTypePrefValue3;
    else if (self.dosageTypePrefKey4 && [self.dosageTypePrefKey4 isEqualToString:prefKey])
        valStr = self.dosageTypePrefValue4;
    else if (self.dosageTypePrefKey5 && [self.dosageTypePrefKey5 isEqualToString:prefKey])
        valStr = self.dosageTypePrefValue5;
    return valStr;
}

- (void) replaceDosageTypePrefValue:(NSString*)prefKey withValue:(NSString*)newVal
{
    if (!prefKey)
        return;
    
    if (self.dosageTypePrefKey1 && [self.dosageTypePrefKey1 isEqualToString:prefKey])
        self.dosageTypePrefValue1 = newVal;
    else if (self.dosageTypePrefKey2 && [self.dosageTypePrefKey2 isEqualToString:prefKey])
        self.dosageTypePrefValue2 = newVal;
    else if (self.dosageTypePrefKey3 && [self.dosageTypePrefKey3 isEqualToString:prefKey])
        self.dosageTypePrefValue3 = newVal;
    else if (self.dosageTypePrefKey4 && [self.dosageTypePrefKey4 isEqualToString:prefKey])
        self.dosageTypePrefValue4 = newVal;
    else if (self.dosageTypePrefKey5 && [self.dosageTypePrefKey5 isEqualToString:prefKey])
        self.dosageTypePrefValue5 = newVal;
}


// Calculate the offset to the remaining quantity and refill quantity for 1-2 affected drugs.
- (void) getOffsetToRemainingRefillQuantityForDrug:(NSString**)drugIdA remainingQuantityOffset:(float*)remainingQuantityOffsetA refillQuantityOffset:(int*)refillQuantityOffsetA
                                        andForDrug:(NSString**)drugIdB remainingQuantityOffset:(float*)remainingQuantityOffsetB refillQuantityOffset:(int*)refillQuantityOffsetB
{
    *remainingQuantityOffsetA = 0.0f;
    *refillQuantityOffsetA = 0;
    *remainingQuantityOffsetB = 0.0f;
    *refillQuantityOffsetB = 0;
    *drugIdA = nil;
    *drugIdB = nil;
    
    if (event && event.drugId)
    {
        *drugIdA = event.drugId;
        float thisRemainingQuantityOffset = 0.0f;
        int thisRefillQuantityOffset = 0;

        [[HistoryManager getInstance] getOffsetToRemainingRefillQuantityFromHistoryEvent:event remainingQuantityOffset:&thisRemainingQuantityOffset refillQuantityOffset:&thisRefillQuantityOffset];

        *remainingQuantityOffsetA -= thisRemainingQuantityOffset;
        *refillQuantityOffsetA -= thisRefillQuantityOffset;
    }
    
    if (self.changed && self.drugId)
    {
        *drugIdB = self.drugId;
        
        if ([self.operation isEqualToString:HistoryManagerTakePillOperationName])
        {
            float thisRemainingQuantityOffset = 0.0f;
            if (self.dosageType)
            {
                NSString* remainingQuantityPrefKey = [[DrugDosageManager getInstance] getDoseQuantityToDecrementRemainingQuantityWithFileTypeName:self.dosageType];
                if (!remainingQuantityPrefKey)
                    thisRemainingQuantityOffset = -1.0f;
                NSString* dosageStr = [self getDosageTypePrefValue:remainingQuantityPrefKey];
                if (dosageStr && [dosageStr length] > 0 && [dosageStr floatValue] > epsilon)
                    thisRemainingQuantityOffset = -[dosageStr floatValue];
            }
            else
            {
                Drug* d = [[DataModel getInstance] findDrugWithId:self.drugId];
                if (d)
                {
                    NSString* remainingQuantityPrefKey = [d.dosage getDoseQuantityToDecrementRemainingQuantity];
                    if (!remainingQuantityPrefKey)
                        thisRemainingQuantityOffset = -1.0f;
                }
            }

            *remainingQuantityOffsetB += thisRemainingQuantityOffset;
        }
        else if ([self.operation isEqualToString:HistoryManagerRefillOperationName])
        {
            NSString* remainingQuantityAmountStr = [self getDosageTypePrefValue:RefillQuantityKey];
            if (remainingQuantityAmountStr && [remainingQuantityAmountStr length] > 0 && [remainingQuantityAmountStr floatValue] > epsilon)
                *remainingQuantityOffsetB += [remainingQuantityAmountStr floatValue];

            *refillQuantityOffsetB += -1;
        }
    }
}

- (BOOL) deleteFromHistory
{
    BOOL result = NO;
    
    if (event)
    {
        result = [[HistoryManager getInstance] deleteEvent:event notifyServer:YES];
        event = nil;
    }
    else
        result = YES;
    
    [self clearEditedData];
	
	return result;
}

- (BOOL) late // Returns whether this event is late relative to its scheduled time
{    
    DataModel* dataModel = [DataModel getInstance];
    
    if (dataModel.globalSettings.lateDosePeriodSecs < 0)
        return NO;
    
    NSString* op = self.operation;
    NSDate* creation = self.creationDate;
    NSDate* schedule = self.scheduleDate;
    if (!op || !creation || !schedule)
        return NO;
    
    // For some reason, the timeIntervalSinceDate call sometimes has rounding errors that result in it being a second off.
    // To correct for this, convert the seconds result to minutes, rounding to the nearest minute, and then convert back to seconds.
    int minLate = ([creation timeIntervalSinceDate:schedule] / 60.0) + 0.5; // round to nearest minute
    return (minLate*60 > dataModel.globalSettings.lateDosePeriodSecs);
}

- (NSString*) latePeriodDescription // Returns a description of the late period, if any
{
    NSMutableString* result = nil;
    if (self.late)
    {
        result = [NSMutableString stringWithString:@""];
        NSDate* creation = self.creationDate;
        NSDate* schedule = self.scheduleDate;
        
        int minLate = ([creation timeIntervalSinceDate:schedule] / 60.0) + 0.5; // round to nearest minute
        if (minLate > MIN_PER_DAY)
            [result appendString:@">24:00"];
        else
        {
            int minLateLeft = minLate % 60;
            int hoursLateLeft = minLate / 60;
            if (hoursLateLeft > 0)
                [result appendFormat:@"%d", hoursLateLeft];
            [result appendFormat:@":%02d", minLateLeft];
        }
    }
    
    return result;
}

- (NSString*) drugId
{
    if (event && !editedDrugId)
        return event.drugId;
    else
		return editedDrugId;
}

- (void) setDrugId:(NSString *)dId
{
    editedDrugId = dId;
}

- (NSString*) guid
{
    if (event && !editedGUID)
        return event.guid;
    else
		return editedGUID;
}

- (void) setGuid:(NSString *)gid
{
    editedGUID = gid;
}

- (NSString*) operation
{
    if (event && !editedOperation)
        return event.operation;
    else
		return editedOperation;
}

- (void) setOperation:(NSString *)op
{
    editedOperation = op;
}

- (NSDate*) creationDate
{
    if (event && !editedCreationDate)
        return event.creationDate;
    else
		return editedCreationDate;
}

- (void) setCreationDate:(NSDate *)date
{
    editedCreationDate = date;
}

- (NSString*) operationData
{
    if (event && !editedOperationData && !clearedOperationData)
        return event.operationData;
    else
		return editedOperationData;
}

- (void) setOperationData:(NSString *)opData
{
    NSString* oldOperationData = self.operationData;
    editedOperationData = opData;
    if (oldOperationData && !editedOperationData)
        clearedOperationData = YES;
}

- (NSString*) eventDescription
{
    if (event && !editedEventDescription)
        return event.eventDescription;
    else
		return editedEventDescription;
}

- (void) setEventDescription:(NSString *)descrip
{
    editedEventDescription = descrip;
}

- (NSDate*) scheduleDate
{
    if (event && !editedScheduleDate && !clearedScheduleDate)
        return event.scheduleDate;
    else
		return editedScheduleDate;
}

- (void) setScheduleDate:(NSDate *)date
{
    NSDate* oldScheduleDate = self.scheduleDate;
    editedScheduleDate = date;
    if (oldScheduleDate && !editedScheduleDate)
        clearedScheduleDate = YES;
}

- (NSString*) dosageType
{
    if (event && !editedDosageType)
        return event.dosageType;
    else
		return editedDosageType;
}

- (void) setDosageType:(NSString *)dt
{
    editedDosageType = dt;
}

- (NSString*) dosageTypePrefKey1
{
    if (event && !editedDosageTypePrefKey1 && !clearedDosageTypePrefKey1)
        return event.dosageTypePrefKey1;
    else
		return editedDosageTypePrefKey1;
}

- (void) setDosageTypePrefKey1:(NSString *)dt
{
    NSString* oldDosageTypePrefKey1 = self.dosageTypePrefKey1;
    editedDosageTypePrefKey1 = dt;
    if (oldDosageTypePrefKey1 && !editedDosageTypePrefKey1)
        clearedDosageTypePrefKey1 = YES;
}

- (NSString*) dosageTypePrefKey2
{
    if (event && !editedDosageTypePrefKey2 && !clearedDosageTypePrefKey2)
        return event.dosageTypePrefKey2;
    else
		return editedDosageTypePrefKey2;
}

- (void) setDosageTypePrefKey2:(NSString *)dt
{
    NSString* oldDosageTypePrefKey2 = self.dosageTypePrefKey2;
    editedDosageTypePrefKey2 = dt;
    if (oldDosageTypePrefKey2 && !editedDosageTypePrefKey2)
        clearedDosageTypePrefKey2 = YES;
}

- (NSString*) dosageTypePrefKey3
{
    if (event && !editedDosageTypePrefKey3 && !clearedDosageTypePrefKey3)
        return event.dosageTypePrefKey3;
    else
		return editedDosageTypePrefKey3;
}

- (void) setDosageTypePrefKey3:(NSString *)dt
{
    NSString* oldDosageTypePrefKey3 = self.dosageTypePrefKey3;
    editedDosageTypePrefKey3 = dt;
    if (oldDosageTypePrefKey3 && !editedDosageTypePrefKey3)
        clearedDosageTypePrefKey3 = YES;
}

- (NSString*) dosageTypePrefKey4
{
    if (event && !editedDosageTypePrefKey4 && !clearedDosageTypePrefKey4)
        return event.dosageTypePrefKey4;
    else
		return editedDosageTypePrefKey4;
}

- (void) setDosageTypePrefKey4:(NSString *)dt
{
    NSString* oldDosageTypePrefKey4 = self.dosageTypePrefKey4;
    editedDosageTypePrefKey4 = dt;
    if (oldDosageTypePrefKey4 && !editedDosageTypePrefKey4)
        clearedDosageTypePrefKey4 = YES;
}


- (NSString*) dosageTypePrefKey5
{
    if (event && !editedDosageTypePrefKey5 && !clearedDosageTypePrefKey5)
        return event.dosageTypePrefKey5;
    else
		return editedDosageTypePrefKey5;
}

- (void) setDosageTypePrefKey5:(NSString *)dt
{
    NSString* oldDosageTypePrefKey5 = self.dosageTypePrefKey5;
    editedDosageTypePrefKey5 = dt;
    if (oldDosageTypePrefKey5 && !editedDosageTypePrefKey5)
        clearedDosageTypePrefKey5 = YES;
}

- (NSString*) dosageTypePrefValue1
{
    if (event && !editedDosageTypePrefValue1 && !clearedDosageTypePrefValue1)
        return event.dosageTypePrefValue1;
    else
		return editedDosageTypePrefValue1;
}

- (void) setDosageTypePrefValue1:(NSString *)dt
{
    NSString* oldDosageTypePrefValue1 = self.dosageTypePrefValue1;
    editedDosageTypePrefValue1 = dt;
    if (oldDosageTypePrefValue1 && !editedDosageTypePrefValue1)
        clearedDosageTypePrefValue1 = YES;
}

- (NSString*) dosageTypePrefValue2
{
    if (event && !editedDosageTypePrefValue2 && !clearedDosageTypePrefValue2)
        return event.dosageTypePrefValue2;
    else
		return editedDosageTypePrefValue2;
}

- (void) setDosageTypePrefValue2:(NSString *)dt
{
    NSString* oldDosageTypePrefValue2 = self.dosageTypePrefValue2;
    editedDosageTypePrefValue2 = dt;
    if (oldDosageTypePrefValue2 && !editedDosageTypePrefValue2)
        clearedDosageTypePrefValue2 = YES;
}

- (NSString*) dosageTypePrefValue3
{
    if (event && !editedDosageTypePrefValue3 && !clearedDosageTypePrefValue3)
        return event.dosageTypePrefValue3;
    else
		return editedDosageTypePrefValue3;
}

- (void) setDosageTypePrefValue3:(NSString *)dt
{
    NSString* oldDosageTypePrefValue3 = self.dosageTypePrefValue3;
    editedDosageTypePrefValue3 = dt;
    if (oldDosageTypePrefValue3 && !editedDosageTypePrefValue3)
        clearedDosageTypePrefValue3 = YES;
}

- (NSString*) dosageTypePrefValue4
{
    if (event && !editedDosageTypePrefValue4 && !clearedDosageTypePrefValue4)
        return event.dosageTypePrefValue4;
    else
		return editedDosageTypePrefValue4;
}

- (void) setDosageTypePrefValue4:(NSString *)dt
{
    NSString* oldDosageTypePrefValue4 = self.dosageTypePrefValue4;
    editedDosageTypePrefValue4 = dt;
    if (oldDosageTypePrefValue4 && !editedDosageTypePrefValue4)
        clearedDosageTypePrefValue4 = YES;
}

- (NSString*) dosageTypePrefValue5
{
    if (event && !editedDosageTypePrefValue5 && !clearedDosageTypePrefValue5)
        return event.dosageTypePrefValue5;
    else
		return editedDosageTypePrefValue5;
}

- (void) setDosageTypePrefValue5:(NSString *)dt
{
    NSString* oldDosageTypePrefValue5 = self.dosageTypePrefValue5;
    editedDosageTypePrefValue5 = dt;
    if (oldDosageTypePrefValue5 && !editedDosageTypePrefValue5)
        clearedDosageTypePrefValue5 = YES;
}

- (BOOL) changed
{
	return  !event ||
             editedGUID ||
             editedDrugId ||
             editedOperation ||
             editedCreationDate ||
             editedOperationData ||
             editedEventDescription ||
             editedScheduleDate ||
             editedDosageType ||
             editedDosageTypePrefKey1 ||
             editedDosageTypePrefValue1 ||
             editedDosageTypePrefKey2 ||
             editedDosageTypePrefValue2 ||
             editedDosageTypePrefKey3 ||
             editedDosageTypePrefValue3 ||
             editedDosageTypePrefKey4 ||
             editedDosageTypePrefValue4 ||
             editedDosageTypePrefKey5 ||
             editedDosageTypePrefValue5 ||
             clearedScheduleDate ||
             clearedOperationData ||
             clearedDosageTypePrefKey1 ||
             clearedDosageTypePrefValue1 ||
             clearedDosageTypePrefKey2 ||
             clearedDosageTypePrefValue2 ||
             clearedDosageTypePrefKey3 ||
             clearedDosageTypePrefValue3 ||
             clearedDosageTypePrefKey4 ||
             clearedDosageTypePrefValue4 ||
             clearedDosageTypePrefKey5 ||
             clearedDosageTypePrefValue5;
}

- (NSDictionary*) extractHistoryPreferencesFromSyncDict:(NSDictionary*)dict
{
    NSMutableDictionary* historyPreferences = [[NSMutableDictionary alloc] init];
    
    NSMutableArray* syncPreferences = [dict objectForKey:SyncPreferencesKey];
    if (syncPreferences)
    {
        for (NSMutableDictionary* thisPref in syncPreferences)
        {
            NSString* key = [thisPref objectForKey:KeyKey];
            if (key)
            {
                NSString* value = [thisPref objectForKey:ValueKey];
                if (value)
                    [historyPreferences setObject:value forKey:key];
            }
        }
    }

    return historyPreferences;
}

- (void) setDosageTypeToDrugDosage:(DrugDosage*)dosage
{
    if ([self.operation isEqualToString:HistoryManagerRefillOperationName])
    {
        float refillAmount = 0.0f;
        [dosage getValueForRefillQuantity:&refillAmount];

        self.dosageType = nil;
        self.dosageTypePrefKey1 = RefillQuantityKey;
        self.dosageTypePrefValue1 = [DrugDosage getStringFromQuantity:refillAmount unit:nil numDecimals:2];
        self.dosageTypePrefKey2 = nil;
        self.dosageTypePrefValue2 = nil;
        self.dosageTypePrefKey3 = nil;
        self.dosageTypePrefValue3 = nil;
        self.dosageTypePrefKey4 = nil;
        self.dosageTypePrefValue4 = nil;
        self.dosageTypePrefKey5 = nil;
        self.dosageTypePrefValue5 = nil;
    }
    else if (![self.operation isEqualToString:HistoryManagerSetInventoryOperationName] &&
            ![self.operation isEqualToString:HistoryManagerAdjustInventoryOperationName] &&
            ![self.operation isEqualToString:HistoryManagerAdjustRefillOperationName])
    {
        self.dosageType = [dosage getFileTypeName];
        NSDictionary* doseData = [self extractHistoryPreferencesFromSyncDict:[dosage getDoseData]];
        NSMutableArray* allKeys = [NSMutableArray arrayWithArray:[doseData allKeys]];
        if ([allKeys count] > 0)
        {
            self.dosageTypePrefKey1 = [allKeys objectAtIndex:0];
            self.dosageTypePrefValue1 = [doseData objectForKey:self.dosageTypePrefKey1];
            [allKeys removeObjectAtIndex:0];
        }
        else
        {
            self.dosageTypePrefKey1 = nil;
            self.dosageTypePrefValue1 = nil;
        }
        if ([allKeys count] > 0)
        {
            self.dosageTypePrefKey2 = [allKeys objectAtIndex:0];
            self.dosageTypePrefValue2 = [doseData objectForKey:self.dosageTypePrefKey2];
            [allKeys removeObjectAtIndex:0];
        }
        else
        {
            self.dosageTypePrefKey2 = nil;
            self.dosageTypePrefValue2 = nil;
        }
        if ([allKeys count] > 0)
        {
            self.dosageTypePrefKey3 = [allKeys objectAtIndex:0];
            self.dosageTypePrefValue3 = [doseData objectForKey:self.dosageTypePrefKey3];
            [allKeys removeObjectAtIndex:0];
        }
        else
        {
            self.dosageTypePrefKey3 = nil;
            self.dosageTypePrefValue3 = nil;
        }
        if ([allKeys count] > 0)
        {
            self.dosageTypePrefKey4 = [allKeys objectAtIndex:0];
            self.dosageTypePrefValue4 = [doseData objectForKey:self.dosageTypePrefKey4];
            [allKeys removeObjectAtIndex:0];
        }
        else
        {
            self.dosageTypePrefKey4 = nil;
            self.dosageTypePrefValue4 = nil;
        }
        if ([allKeys count] > 0)
        {
            self.dosageTypePrefKey5 = [allKeys objectAtIndex:0];
            self.dosageTypePrefValue5 = [doseData objectForKey:self.dosageTypePrefKey5];
            [allKeys removeObjectAtIndex:0];
        }
        else
        {
            self.dosageTypePrefKey5 = nil;
            self.dosageTypePrefValue5 = nil;
        }
    }
}

- (NSDictionary*) createHistoryEventPreferencesDict
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    if (![self.operation isEqualToString:HistoryManagerSetInventoryOperationName] &&
        ![self.operation isEqualToString:HistoryManagerAdjustInventoryOperationName] &&
        ![self.operation isEqualToString:HistoryManagerAdjustRefillOperationName] &&
        ![self.operation isEqualToString:HistoryManagerRefillOperationName] &&
        self.dosageType && [self.dosageType length] > 0)
    {
        [dict setObject:self.dosageType forKey:DosageTypeKey];
    }
    if (self.dosageTypePrefKey1 && [self.dosageTypePrefKey1 length] > 0)
        [dict setObject:self.dosageTypePrefValue1 forKey:self.dosageTypePrefKey1];
    if (self.dosageTypePrefKey2 && [self.dosageTypePrefKey2 length] > 0)
        [dict setObject:self.dosageTypePrefValue2 forKey:self.dosageTypePrefKey2];
    if (self.dosageTypePrefKey3 && [self.dosageTypePrefKey3 length] > 0)
        [dict setObject:self.dosageTypePrefValue3 forKey:self.dosageTypePrefKey3];
    if (self.dosageTypePrefKey4 && [self.dosageTypePrefKey4 length] > 0)
        [dict setObject:self.dosageTypePrefValue4 forKey:self.dosageTypePrefKey4];
    if (self.dosageTypePrefKey5 && [self.dosageTypePrefKey5 length] > 0)
        [dict setObject:self.dosageTypePrefValue5 forKey:self.dosageTypePrefKey5];
    return dict;
}

@end
