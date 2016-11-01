//
//  EditableHistoryEvent.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 2/20/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HistoryEvent;
@class DrugDosage;
@interface EditableHistoryEvent : NSObject
{
@private
	HistoryEvent* event;
	NSString* editedDrugId;
    NSString* editedGUID;
	NSString* editedOperation;
	NSDate* editedCreationDate;
	NSString* editedOperationData;
	NSString* editedEventDescription; // legacy
    NSDate* editedScheduleDate;
    NSString* editedDosageType;
    NSString* editedDosageTypePrefKey1;
    NSString* editedDosageTypePrefValue1;
    NSString* editedDosageTypePrefKey2;
    NSString* editedDosageTypePrefValue2;
    NSString* editedDosageTypePrefKey3;
    NSString* editedDosageTypePrefValue3;
    NSString* editedDosageTypePrefKey4;
    NSString* editedDosageTypePrefValue4;
    NSString* editedDosageTypePrefKey5;
    NSString* editedDosageTypePrefValue5;
    BOOL clearedDosageTypePrefKey1;
    BOOL clearedDosageTypePrefValue1;
    BOOL clearedDosageTypePrefKey2;
    BOOL clearedDosageTypePrefValue2;
    BOOL clearedDosageTypePrefKey3;
    BOOL clearedDosageTypePrefValue3;
    BOOL clearedDosageTypePrefKey4;
    BOOL clearedDosageTypePrefValue4;
    BOOL clearedDosageTypePrefKey5;
    BOOL clearedDosageTypePrefValue5;
    BOOL clearedScheduleDate;
    BOOL clearedOperationData;
}

- (BOOL) commitChanges;
- (BOOL) deleteFromHistory;
- (void) setDosageTypeToDrugDosage:(DrugDosage*)dosage;

// Calculate the offset to the remaining quantity and refill quantity for 1-2 affected drugs
- (void) getOffsetToRemainingRefillQuantityForDrug:(NSString**)drugIdA remainingQuantityOffset:(float*)remainingQuantityOffsetA refillQuantityOffset:(int*)refillQuantityOffsetA
                                        andForDrug:(NSString**)drugIdB remainingQuantityOffset:(float*)remainingQuantityOffsetB refillQuantityOffset:(int*)refillQuantityOffsetB;

- (NSDictionary*) createHistoryEventPreferencesDict;

- (NSString*) latePeriodDescription; // Returns a description of the late period, if any

- (NSString*) getDosageTypePrefValue:(NSString*)prefKey;
- (void) replaceDosageTypePrefValue:(NSString*)prefKey withValue:(NSString*)newVal;

+ (EditableHistoryEvent*) editableHistoryEventWithHistoryEvent:(HistoryEvent*)e;

+ (EditableHistoryEvent*) editableHistoryEvent:(NSString*)drugId
                                  creationDate:(NSDate*)creationDate
                                     operation:(NSString*)operation
                                 operationData:(NSString*)operationData
                                  scheduleDate:(NSDate*)scheduleDate
                                        dosage:(DrugDosage*)dosage;

@property (nonatomic, strong) NSString * drugId;
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSString * operation;
@property (nonatomic, strong) NSDate * creationDate;
@property (nonatomic, strong) NSString * operationData;
@property (nonatomic, strong) NSString * eventDescription;
@property (nonatomic, strong) NSDate * scheduleDate;
@property (nonatomic, strong) NSString * dosageType;
@property (nonatomic, strong) NSString * dosageTypePrefKey1;
@property (nonatomic, strong) NSString * dosageTypePrefValue1;
@property (nonatomic, strong) NSString * dosageTypePrefKey2;
@property (nonatomic, strong) NSString * dosageTypePrefValue2;
@property (nonatomic, strong) NSString * dosageTypePrefKey3;
@property (nonatomic, strong) NSString * dosageTypePrefValue3;
@property (nonatomic, strong) NSString * dosageTypePrefKey4;
@property (nonatomic, strong) NSString * dosageTypePrefValue4;
@property (nonatomic, strong) NSString * dosageTypePrefKey5;
@property (nonatomic, strong) NSString * dosageTypePrefValue5;
@property (nonatomic, readonly) BOOL changed;
@property (nonatomic, readonly) BOOL late; // Returns whether this event is late relative to its scheduled time

@end
