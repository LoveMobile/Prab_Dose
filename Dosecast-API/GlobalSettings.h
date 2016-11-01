//
//  GlobalSettings.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastCoreTypes.h"
#import "GlobalSettingsDelegate.h"

@class CustomNameIDList;
@class Preferences;
@class StringList;
@class VersionNumber;

extern int DEFAULT_DOSE_HISTORY_DAYS;
extern BOOL DEFAULT_POSTPONES_DISPLAYED;
extern BOOL DEFAULT_DRUG_IMAGES_DISPLAYED;
extern BOOL DEFAULT_PREVENT_EARLY_DRUG_DOSES;
extern int DEFAULT_LATE_DOSE_PERIOD_SECS;
extern int DEFAULT_SECONDARY_REMINDER_PERIOD_SECS;

// This notification is fired when the data file is read and the contents are upgraded from an older API version
extern NSString *GlobalSettingsAPIVersionUpgrade;
extern NSString *GlobalSettingsAPIVersionUpgradeUserInfoDictionaryRead; // The user info key for accessing the dictionary read
extern NSString *GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade; // The user info key for accessing whether this is a file upgrade (if not, it is a server upgrade)

@interface GlobalSettings : NSObject<NSMutableCopying>
{
@private
    CustomNameIDList* customDrugDosageNames;
    CustomNameIDList* personNames;
    StringList* subscriptionReceipts;
    Preferences* globalPrefs;
    NSObject<GlobalSettingsDelegate>* __weak delegate;
}

- (id)initWithAPIFlags:(NSArray*)apiFlags;

// Read all values from the given dictionary
- (void)readFromDictionary:(NSMutableDictionary*)dict;

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest completedInitialSync:(BOOL)completedInitialSync;

// Update from provided server dictionary. Returns whether all notifications should be refreshed.
- (BOOL) updateFromServerDictionary:(NSMutableDictionary*)dict isInteractive:(BOOL)isInteractive currentServerTime:(NSDate*)currentServerTime limitToProductStatusOnly:(BOOL)limitToProductStatusOnly;

- (BOOL) wasPremiumPurchasedOrGrantedByServer;
- (BOOL) wasSubscriptionPurchasedOrGrantedByServer;

- (void) addSubscriptionReceipt:(NSString*)receipt;

@property (nonatomic, readonly) AccountType accountType;
@property (nonatomic, strong) NSDate* subscriptionExpires;
@property (nonatomic, assign) BOOL purchasedPremium;
@property (nonatomic, assign) int bedtimeStart;
@property (nonatomic, assign) int bedtimeEnd;
@property (nonatomic, strong) NSNumber* lastTimezoneGMTOffset;
@property (nonatomic, strong) NSString* lastTimezoneName;
@property (nonatomic, strong) NSNumber* lastDaylightSavingsTimeOffset;
@property (nonatomic, strong) NSString* reminderSoundFilename;
@property (nonatomic, strong) NSString* userData;
@property (nonatomic, assign) int doseHistoryDays;
@property (nonatomic, assign) BOOL preventEarlyDrugDoses;
@property (nonatomic, assign) BOOL postponesDisplayed;
@property (nonatomic, assign) BOOL archivedDrugsDisplayed;
@property (nonatomic, assign) BOOL drugImagesDisplayed;
@property (nonatomic, assign) BOOL drugNamesDisplayedInNotifications;
@property (nonatomic, assign) BOOL debugLoggingEnabled;
@property (nonatomic, assign) int lateDosePeriodSecs;
@property (nonatomic, assign) int secondaryReminderPeriodSecs;
@property (nonatomic, assign) DrugSortOrder drugSortOrder;
@property (nonatomic, strong) CustomNameIDList* customDrugDosageNames;
@property (nonatomic, strong) CustomNameIDList* personNames;
@property (nonatomic, strong) NSDate* lastManagedUpdate;
@property (nonatomic, strong) NSString* premiumReceipt;
@property (nonatomic, readonly) NSArray* allSubscriptionReceipts;
@property (nonatomic, assign) BOOL issued7daySubscriptionTrial;
@property (nonatomic, strong) NSDate* lastTimeZoneChangeTime;
@property (nonatomic, strong) NSDate* lastScheduledDaylightSavingsTimeChange;
@property (nonatomic, strong) NSDate* lastTimeZoneChangeCheckTime;
@property (nonatomic, readonly) VersionNumber* apiVersion;
@property (nonatomic, weak) NSObject<GlobalSettingsDelegate>* delegate;

@end
