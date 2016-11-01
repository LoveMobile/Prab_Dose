//
//  LocalNotificationManager.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"
#import "DrugReminder.h"
#import "DrugDosage.h"
#import "LocalNotificationManagerDelegate.h"

@class AddressBookContact;
@class Drug;
@interface LocalNotificationManager : NSObject {
@private
    NSMutableArray* batchUpdatesStack;
    BOOL batchRefreshAllNotifications;
    BOOL batchAdjustAndMergeNotifications;
    NSMutableSet* batchServerMethodCalls;
    NSMutableSet* batchDeletedDrugIds;
    NSMutableArray* allLocalNotifications;
    NSObject<LocalNotificationManagerDelegate>* getStateDelegate;
}

// Singleton methods
+ (LocalNotificationManager*) getInstance;

// Clears and re-sets all notifications
- (void)refreshAllNotifications;

// Proxy for GetState call. If successful, updates data model.
- (void)getState:(BOOL)allowServerUpdate
        respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async;

// Proxy for CreatePill call. If successful, updates data model.
- (void)createPill:(NSString*)drugID
          drugName:(NSString*)drugName
         imageGUID:(NSString *)GUID
          personId:(NSString*)personId
		directions:(NSString*)directions
     doctorContact:(AddressBookContact*)doctor
   pharmacyContact:(AddressBookContact*)pharmacy
   prescriptionNum:(NSString*)prescripNum
	  drugReminder:(DrugReminder*)reminder
		drugDosage:(DrugDosage*)dosage
             notes:(NSString*)notes
	     respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async;

// Proxy for EditPill call. If successful, updates data model.
- (void)editPill:(NSString*)drugID
		drugName:(NSString*)drugName
       imageGUID:(NSString *)GUID
        personId:(NSString*)personId
	  directions:(NSString*)directions
   doctorContact:(AddressBookContact*)doctor
 pharmacyContact:(AddressBookContact*)pharmacy
 prescriptionNum:(NSString*)prescripNum
	drugReminder:(DrugReminder*)reminder
	  drugDosage:(DrugDosage*)dosage
           notes:(NSString*)notes
undoHistoryEventGUID:(NSString*)undoHistoryEventGUID
    updateServer:(BOOL)updateServer
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async;

// Proxy for RefillPill call. If successful, updates data model.
- (void)refillPill:(NSString*)drugID
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async;

// Proxy for DeletePill call. If successful, updates data model.
- (void)deletePill:(NSString*)drugID
      updateServer:(BOOL)updateServer
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async;

// Proxy for UndoPill call. If successful, updates data model.
- (void)undoPill:(NSString*)drugID
       respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
           async:(BOOL)async;

// Proxy for TakePill call. If successful, updates data model.
  - (void)takePill:(NSString*)drugID
		  doseTime:(NSDate*)doseTime
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async;

// Proxy for SkipPill call. If successful, updates data model.
  - (void)skipPill:(NSString*)drugID
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async;

// Proxy for PostponePill call. If successful, updates data model.
- (void)postponePill:(NSString*)drugID
			 seconds:(int)seconds // How long to postpone for
           respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
               async:(BOOL)async;

// Proxy for Subscribe call. If successful, updates data model.
  - (void)subscribe:(NSString*)receipt
  newExpirationDate:(NSDate*)newExpirationDate
          respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
              async:(BOOL)async;

// Proxy for Upgrade call. If successful, updates data model.
- (void)upgrade:(NSString*)receipt
        respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
            async:(BOOL)async;

// Proxy for StartFreeTrial call. If successful, updates data model.
- (void)startFreeTrial:(NSObject<LocalNotificationManagerDelegate>*)delegate
                 async:(BOOL)async;

// Proxy for SetBedtime call. If successful, updates data model.
- (void)setBedtime:(int)bedtimeStart
		bedtimeEnd:(int)bedtimeEnd
         respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
             async:(BOOL)async;

// Proxy for SetPreferences call. If successful, updates data model.
- (void)setPreferences:(NSMutableDictionary*)dict
             respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
                 async:(BOOL)async;

// Proxy for MoveScheduledReminders call. If successful, updates data model.
- (void)moveScheduledReminders:(NSTimeInterval)timePeriodSecs
             respondTo:(NSObject<LocalNotificationManagerDelegate>*)delegate
                 async:(BOOL)async;

// Called prior to beginning a batch of LocalNotificationManager calls - for performance purposes
- (void) beginBatchUpdates;

// Whether batch updates are in progress
- (BOOL) batchUpdatesInProgress;

// Called after ending a batch of LocalNotificationManager calls - for performance purposes
- (void) endBatchUpdates:(BOOL)completedSync;

@end
