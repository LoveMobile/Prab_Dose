//
//  Drug.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/7/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"
#import "DrugReminder.h"
#import "DrugDosage.h"
#import "DrugReminderDelegate.h"
#import "AddressBookContactDelegate.h"

@class AddressBookContact;
@class Preferences;

@interface Drug : NSObject<NSMutableCopying, DrugReminderDelegate, AddressBookContactDelegate>
{
@private
    NSDate* created;
	NSString* drugId;
	NSString* name;
    NSString* drugImageGUID;
	NSString* directions;
    NSString* personId;
    NSString* notes;
    NSString* clientEditGUID;
    NSDate* clientEditTime;
    NSString* serverEditGUID;
    AddressBookContact* doctorContact;
    AddressBookContact* pharmacyContact;
    NSString* prescriptionNum;
	DrugReminder* reminder;
	DrugDosage* dosage;
    long long lastHistoryToken;
    NSMutableSet* deletedHistoryGUIDs;
    NSString* undoHistoryEventGUID;
    Preferences* otherDrugPreferences;
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
otherDrugPreferences:(Preferences*)otherPrefs;

// Initialization using a dictionary (the designated initializer)
- (id)initWithDictionary:(NSMutableDictionary*) dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest;

// Returns whether the remaining quantity is empty
- (BOOL) isEmpty;

// Returns whether the remaining quantity is running low and a refill is needed
- (BOOL) isRunningLow;

// Returns whether this is a managed drug
- (BOOL) isManaged;

// Returns whether the dose limit would be exceeded if a dose were taken on the given date. If so, returns the next available time the dose could be taken
- (BOOL) wouldExceedDoseLimitIfTakenAtDate:(NSDate*)date
                     nextAvailableDoseTime:(NSDate**)nextAvailableDoseTime;

// Returns whether the next dose would exceed the dose limit if a dose were taken on the given date.
- (BOOL) wouldNextDoseExceedDoseLimitIfTakenAtDate:(NSDate*)date;

// Returns whether the dose limit is being exceeded
- (BOOL) isExceedingDoseLimit;

// Return the daily dose count for the given date if dose limits are used
- (int) getDailyDoseCountAsOfDate:(NSDate*)date;

// Returns whether a refill notification needs to be displayed for this drug
- (BOOL) needsRefillNotification;

// Refresh internal drug state
- (void)refreshDrugInternalState;

// Undo support
- (void) createUndoState:(NSString*)createdHistoryEventGUID;
- (void) performUndo;
- (BOOL) hasUndoState;
- (NSString*) undoOperation;

@property (nonatomic, readonly) NSString* drugId;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong)  NSString* drugImageGUID;
@property (nonatomic, strong) NSDate* created;
@property (nonatomic, strong) AddressBookContact* doctorContact;
@property (nonatomic, strong) AddressBookContact* pharmacyContact;
@property (nonatomic, strong) NSString* prescriptionNum;
@property (nonatomic, strong) NSString* personId;
@property (nonatomic, strong) DrugDosage* dosage;
@property (nonatomic, strong) NSString* directions;
@property (nonatomic, strong) NSString* notes;
@property (nonatomic, strong) DrugReminder* reminder;
@property (nonatomic, strong) NSString* clientEditGUID;
@property (nonatomic, strong) NSDate* clientEditTime;
@property (nonatomic, strong) NSString* serverEditGUID;
@property (nonatomic, readonly) NSString* undoHistoryEventGUID;
@property (nonatomic, assign) long long lastHistoryToken;
@property (nonatomic, strong) NSMutableSet* deletedHistoryGUIDs;
@property (nonatomic, strong) Preferences* otherDrugPreferences;
@end
