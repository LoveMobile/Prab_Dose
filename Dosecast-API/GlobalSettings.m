//
//  GlobalSettings.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "GlobalSettings.h"
#import "CustomNameIDList.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "Preferences.h"
#import "JSONConverter.h"
#import "DataModel.h"
#import "VersionNumber.h"
#import "StringList.h"
#import "VersionNumber.h"
#import "HistoryManager.h"

static NSString *DefaultReminderSoundFilename = @"Default.caf";
static NSString *CustomDrugDosageNamesKey = @"customDrugDosageNames";
static NSString *PersonNamesKey = @"personNames";
static NSString *DeviceTokenKey = @"notificationToken";
static NSString *PurchasedSubscriptionExpiresKey = @"purchasedSubscriptionExpires";
static NSString *ManualSubscriptionExpiresKey = @"manualSubscriptionExpires";
static NSString *LastDaylightSavingsTimeOffsetKey = @"dstOffset_secs";
static NSString *LastTimezoneGMTOffsetKey = @"tz_secs";
static NSString *LastTimezoneNameKey = @"tz_name";
static NSString *LastManagedUpdateKey = @"lastManagedUpdate";
static NSString *ReminderSoundFilenameKey = @"reminderSoundFilename";
static NSString *DoseHistoryDaysKey = @"doseHistoryDays";
static NSString *PostponesDisplayedKey = @"postponesDisplayed";
static NSString *ArchivedDrugsDisplayedKey = @"archivedDrugsDisplayed";
static NSString *DrugImagesDisplayedKey = @"showImages";
static NSString *DrugNamesDisplayedInNotificationsKey = @"privacyMode";
static NSString *PreventEarlyDrugDosesKey = @"earlyDoseWarning";
static NSString *LateDosePeriodSecsKey = @"lateDosePeriodSecs";
static NSString *SecondaryReminderPeriodSecsKey = @"secondaryReminderPeriodSecs";
static NSString *DrugSortOrderKey = @"drugSortOrder";
static NSString *UserDataKey = @"userData";
static NSString *LegacySubscriptionTypeKey = @"subscriptionType"; // legacy
static NSString *LegacyDemoAccountTypeName = @"demo"; // legacy
static NSString *LegacyPremiumAccountTypeName = @"paid"; // legacy
static NSString *ProductStatusKey = @"productStatus";
static NSString *ProductStatusDemoName = @"demo";
static NSString *ProductStatusPremiumName = @"premium";
static NSString *ProductStatusSubscriptionName = @"subscription";
static NSString *PurchasedPremiumKey = @"premiumPurchased";
static NSString *SubscriptionActiveKey = @"subscriptionActive";
static NSString *PremiumReceiptKey = @"premiumReceipt";
static NSString *BedtimeStartKey = @"bedTimeStart";
static NSString *BedtimeEndKey = @"bedTimeEnd";
static NSString *DeviceNameKey = @"deviceName";
static NSString *OSVersionKey = @"osVersion";
static NSString *LanguageKey = @"language";
static NSString *SubscriptionReceiptsKey = @"subscriptionReceipts";
static NSString *FriendlyNameKey = @"friendlyName";
static NSString *Issued7daySubscriptionTrialKey = @"issued7daySubscriptionTrial";
static NSString *LastTZChangeTimeKey = @"lastTZChangeTime";
static NSString *LastTZChangeCheckTimeKey = @"lastTZChangeCheckTime";
static NSString *LastScheduledDSTChangeKey = @"lastScheduledDSTChange";
static NSString *APIVersionKey = @"apiVersion";
static NSString *ClientVersionKey = @"clientVersion";
static NSString *DebugLoggingEnabledKey = @"debugLoggingEnabled";

// This notification is fired when the data file is read and the contents are upgraded from an older API version
NSString *GlobalSettingsAPIVersionUpgrade = @"GlobalSettingsAPIVersionUpgrade";
NSString *GlobalSettingsAPIVersionUpgradeUserInfoDictionaryRead = @"GlobalSettingsAPIVersionUpgradeUserInfoDictionaryRead"; // The user info key for accessing the dictionary read
NSString *GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade = @"GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade"; // The user info key for accessing whether this is a file upgrade (if not, it is a server upgrade)

static NSString* CurrAPIVersionStr = @"Version 7.0.4"; // Note: must be of the form "Version x.y.z"

int DEFAULT_DOSE_HISTORY_DAYS = 30;
BOOL DEFAULT_POSTPONES_DISPLAYED = YES;
BOOL DEFAULT_DRUG_IMAGES_DISPLAYED = YES;
BOOL DEFAULT_PREVENT_EARLY_DRUG_DOSES = YES;
int DEFAULT_LATE_DOSE_PERIOD_SECS = 3600;
int DEFAULT_SECONDARY_REMINDER_PERIOD_SECS = 300;

@implementation GlobalSettings

@synthesize customDrugDosageNames;
@synthesize personNames;
@synthesize delegate;

- (id)init
{
    return [self initWithAPIFlags:[[NSArray alloc] init]];
}

- (id)initWithAPIFlags:(NSArray*)apiFlags
{
	return [self init:NO
  purchasedSubscriptionExpires:nil
manualSubscriptionExpires:nil
         bedtimeStart:-1
           bedtimeEnd:-1
lastTimezoneGMTOffset:[DosecastUtil getCurrTimezoneGMTOffset]
     lastTimezoneName:[DosecastUtil getCurrTimezoneName]
lastDaylightSavingsTimeOffset:[DosecastUtil getCurrDaylightSavingsTimeOffset]
reminderSoundFilename:DefaultReminderSoundFilename
      doseHistoryDays:DEFAULT_DOSE_HISTORY_DAYS
preventEarlyDrugDoses:DEFAULT_PREVENT_EARLY_DRUG_DOSES
   postponesDisplayed:DEFAULT_POSTPONES_DISPLAYED
archivedDrugsDisplayed:([apiFlags containsObject:DosecastAPIShowArchivedDrugsByDefault] ? YES : NO)
  drugImagesDisplayed:DEFAULT_DRUG_IMAGES_DISPLAYED
drugNamesDisplayedInNotifications:([apiFlags containsObject:DosecastAPIShowDrugNamesInNotificationsByDefault] ? YES : NO)
   lateDosePeriodSecs:DEFAULT_LATE_DOSE_PERIOD_SECS
secondaryReminderPeriodSecs:DEFAULT_SECONDARY_REMINDER_PERIOD_SECS
        drugSortOrder:DrugSortOrderByNextDoseTime
             userData:nil
customDrugDosageNames:[[CustomNameIDList alloc] init:CustomDrugDosageNamesKey]
          personNames:[[CustomNameIDList alloc] init:PersonNamesKey]
    lastManagedUpdate:nil
premiumReceipt:nil
 subscriptionReceipts:[[StringList alloc] init:SubscriptionReceiptsKey activeGuids:nil deletedGuids:nil]
issued7daySubscriptionTrial:NO
            lastTZChangeTime:nil
lastScheduledDSTChange:[DosecastUtil getNextDaylightSavingsTimeTransition]
     lastTZChangeCheckTime:nil
  debugLoggingEnabled:NO
           apiVersion:[VersionNumber versionNumberWithVersionString:CurrAPIVersionStr] // Note: string must be of the form "Version x.y.z"
             delegate:nil];
}

            -(id)init:(BOOL)purchasedPremium
purchasedSubscriptionExpires:(NSDate*)purchasedSubscriptionExpires
manualSubscriptionExpires:(NSDate*)manualSubscriptionExpires
         bedtimeStart:(int)bedtimeStart
           bedtimeEnd:(int)bedtimeEnd
lastTimezoneGMTOffset:(NSNumber*)lastTimezoneGMTOffset
     lastTimezoneName:(NSString*)lastTimezoneName
lastDaylightSavingsTimeOffset:(NSNumber*)dstOffset
reminderSoundFilename:(NSString*)reminderSoundFilename
      doseHistoryDays:(int)historyDays
     preventEarlyDrugDoses:(BOOL)preventEarlyDoses
   postponesDisplayed:(BOOL)postponesDisp
archivedDrugsDisplayed:(BOOL)archivedDrugsDisp
  drugImagesDisplayed:(BOOL)drugImagesDisp
drugNamesDisplayedInNotifications:(BOOL)drugNamesDisplayed
   lateDosePeriodSecs:(int)latePeriodSecs
secondaryReminderPeriodSecs:(int)secondaryPeriodSecs
        drugSortOrder:(DrugSortOrder)sortOrder
			 userData:(NSString*)userData
customDrugDosageNames:(CustomNameIDList *)dosageNames
          personNames:(CustomNameIDList*)persons
    lastManagedUpdate:(NSDate *)managedUpdate
premiumReceipt:(NSString*)premiumReceipt
 subscriptionReceipts:(StringList*)receipts
issued7daySubscriptionTrial:(BOOL)issued7daySubscriptionTrial
    lastTZChangeTime:(NSDate*)lastTZChangeTime
lastScheduledDSTChange:(NSDate*)lastScheduledDSTChange
     lastTZChangeCheckTime:(NSDate*)lastTZChangeCheckTime
  debugLoggingEnabled:(BOOL)debugLoggingEnabled
           apiVersion:(VersionNumber*)apiVersion
             delegate:(NSObject<GlobalSettingsDelegate>*)del
{
	if ((self = [super init]))
    {
        subscriptionReceipts = receipts;
        
        globalPrefs = [[Preferences alloc] init:nil storeModifiedDate:YES];
        
        NSString* apiVersionStr = @"";
        if (apiVersion)
            apiVersionStr = apiVersion.versionString;
        [globalPrefs addPreference:APIVersionKey value:apiVersionStr perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        NSString* dstOffsetStr = @"";
        if (dstOffset)
            dstOffsetStr = [NSString stringWithFormat:@"%lld", [dstOffset longLongValue]];
        [globalPrefs addPreference:LastDaylightSavingsTimeOffsetKey value:dstOffsetStr perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        NSString* lastTimezoneGMTOffsetStr = @"";
        if (lastTimezoneGMTOffset)
            lastTimezoneGMTOffsetStr = [NSString stringWithFormat:@"%lld", [lastTimezoneGMTOffset longLongValue]];
        [globalPrefs addPreference:LastTimezoneGMTOffsetKey value:lastTimezoneGMTOffsetStr perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        if (!lastTimezoneName)
            lastTimezoneName = @"";
        [globalPrefs addPreference:LastTimezoneNameKey value:lastTimezoneName perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        NSString* lastTZChangeTimeStr = @"";
        if (lastTZChangeTime)
            lastTZChangeTimeStr = [NSString stringWithFormat:@"%lld", (long long)[lastTZChangeTime timeIntervalSince1970]];
        [globalPrefs addPreference:LastTZChangeTimeKey value:lastTZChangeTimeStr perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        NSString* lastTZChangeCheckTimeStr = @"";
        if (lastTZChangeCheckTime)
            lastTZChangeCheckTimeStr = [NSString stringWithFormat:@"%lld", (long long)[lastTZChangeCheckTime timeIntervalSince1970]];
        [globalPrefs addPreference:LastTZChangeCheckTimeKey value:lastTZChangeCheckTimeStr perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        NSString* lastScheduledDSTChangeStr = @"";
        if (lastScheduledDSTChange)
            lastScheduledDSTChangeStr = [NSString stringWithFormat:@"%lld", (long long)[lastScheduledDSTChange timeIntervalSince1970]];
        [globalPrefs addPreference:LastScheduledDSTChangeKey value:lastScheduledDSTChangeStr perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        NSString* purchasedSubscriptionExpiresStr = @"";
        if (purchasedSubscriptionExpires)
            purchasedSubscriptionExpiresStr = [NSString stringWithFormat:@"%lld", (long long)[purchasedSubscriptionExpires timeIntervalSince1970]];
        [globalPrefs addPreference:PurchasedSubscriptionExpiresKey value:purchasedSubscriptionExpiresStr perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        NSString* manualSubscriptionExpiresStr = @"";
        if (manualSubscriptionExpires)
            manualSubscriptionExpiresStr = [NSString stringWithFormat:@"%lld", (long long)[manualSubscriptionExpires timeIntervalSince1970]];
        [globalPrefs addPreference:ManualSubscriptionExpiresKey value:manualSubscriptionExpiresStr perDevice:NO persistLocally:YES persistOnServer:NO sendAfterCompletedFirstSync:NO];

        NSString* lastManagedUpdateStr = @"";
        if (managedUpdate)
            lastManagedUpdateStr = [NSString stringWithFormat:@"%lld", (long long)[managedUpdate timeIntervalSince1970]];
        [globalPrefs addPreference:LastManagedUpdateKey value:lastManagedUpdateStr perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        if (!reminderSoundFilename)
            reminderSoundFilename = @"";
        [globalPrefs addPreference:ReminderSoundFilenameKey value:reminderSoundFilename perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        if (!userData)
            userData = @"";
        [globalPrefs addPreference:UserDataKey value:userData perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:NO];
        
        NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
        NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];
        
        int bedtimeStartGMTNum = -1;
        if (bedtimeStart >= 0)
        {
            NSDate* bedtimeStartLocalGMT = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeStart] timeInterval:-secondsFromGMT];
            bedtimeStartGMTNum = [DosecastUtil getDateAs24hrTime:bedtimeStartLocalGMT];
        }
        [globalPrefs addPreference:BedtimeStartKey value:[NSString stringWithFormat:@"%d", bedtimeStartGMTNum] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        int bedtimeEndGMTNum = -1;
        if (bedtimeEnd >= 0)
        {
            NSDate* bedtimeEndLocalGMT = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeEnd] timeInterval:-secondsFromGMT];
            bedtimeEndGMTNum = [DosecastUtil getDateAs24hrTime:bedtimeEndLocalGMT];
        }
        [globalPrefs addPreference:BedtimeEndKey value:[NSString stringWithFormat:@"%d", bedtimeEndGMTNum] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        
        [globalPrefs addPreference:DoseHistoryDaysKey value:[NSString stringWithFormat:@"%d", historyDays] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:PostponesDisplayedKey value:[NSString stringWithFormat:@"%d", (postponesDisp ? 1 : 0)] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:ArchivedDrugsDisplayedKey value:[NSString stringWithFormat:@"%d", (archivedDrugsDisp ? 1 : 0)] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:DrugImagesDisplayedKey value:[NSString stringWithFormat:@"%d", (drugImagesDisp ? 1 : 0)] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:DrugNamesDisplayedInNotificationsKey value:[NSString stringWithFormat:@"%d", (drugNamesDisplayed ? 0 : 1)] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:PreventEarlyDrugDosesKey value:[NSString stringWithFormat:@"%d", (preventEarlyDoses ? 1 : 0)] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:DrugSortOrderKey value:[NSString stringWithFormat:@"%d", (int)sortOrder] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:LateDosePeriodSecsKey value:[NSString stringWithFormat:@"%d", latePeriodSecs] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:SecondaryReminderPeriodSecsKey value:[NSString stringWithFormat:@"%d", secondaryPeriodSecs] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:Issued7daySubscriptionTrialKey value:[NSString stringWithFormat:@"%d", issued7daySubscriptionTrial] perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:DebugLoggingEnabledKey value:[NSString stringWithFormat:@"%d", (debugLoggingEnabled ? 1 : 0)] perDevice:NO persistLocally:YES persistOnServer:NO sendAfterCompletedFirstSync:NO];
        
        [globalPrefs addPreference:PurchasedPremiumKey value:(purchasedPremium ? @"1" : @"0") perDevice:YES persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];
        [globalPrefs addPreference:ProductStatusKey value:@"" perDevice:NO persistLocally:YES persistOnServer:NO sendAfterCompletedFirstSync:NO];
        
        if (!premiumReceipt)
            premiumReceipt = @"";
        [globalPrefs addPreference:PremiumReceiptKey value:premiumReceipt perDevice:NO persistLocally:YES persistOnServer:YES sendAfterCompletedFirstSync:YES];

        customDrugDosageNames = dosageNames;
        personNames = persons;
        delegate = del;
	}
	
    return self;
}

- (void)dealloc
{
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[GlobalSettings alloc] init:self.purchasedPremium
           purchasedSubscriptionExpires:[[self purchasedSubscriptionExpires] copyWithZone:zone]
              manualSubscriptionExpires:[[self manualSubscriptionExpires] copyWithZone:zone]
                           bedtimeStart:self.bedtimeStart
                             bedtimeEnd:self.bedtimeEnd
                  lastTimezoneGMTOffset:[self.lastTimezoneGMTOffset copyWithZone:zone]
                       lastTimezoneName:[self.lastTimezoneName mutableCopyWithZone:zone]
          lastDaylightSavingsTimeOffset:[self.lastDaylightSavingsTimeOffset copyWithZone:zone]
                  reminderSoundFilename:[self.reminderSoundFilename mutableCopyWithZone:zone]
                        doseHistoryDays:self.doseHistoryDays
                  preventEarlyDrugDoses:self.preventEarlyDrugDoses
                     postponesDisplayed:self.postponesDisplayed
                 archivedDrugsDisplayed:self.archivedDrugsDisplayed
                    drugImagesDisplayed:self.drugImagesDisplayed
      drugNamesDisplayedInNotifications:self.drugNamesDisplayedInNotifications
                     lateDosePeriodSecs:self.lateDosePeriodSecs
            secondaryReminderPeriodSecs:self.secondaryReminderPeriodSecs
                          drugSortOrder:self.drugSortOrder
                               userData:[self.userData mutableCopyWithZone:zone]
                  customDrugDosageNames:[self.customDrugDosageNames mutableCopyWithZone:zone]
                            personNames:[self.personNames mutableCopyWithZone:zone]
                      lastManagedUpdate:[self.lastManagedUpdate copyWithZone:zone]
                         premiumReceipt:[self.premiumReceipt mutableCopyWithZone:zone]
                   subscriptionReceipts:[subscriptionReceipts mutableCopyWithZone:zone]
            issued7daySubscriptionTrial:self.issued7daySubscriptionTrial
            lastTZChangeTime:[self.lastTimeZoneChangeTime copyWithZone:zone]
                 lastScheduledDSTChange:[self.lastScheduledDaylightSavingsTimeChange copyWithZone:zone]
                       lastTZChangeCheckTime:[self.lastTimeZoneChangeCheckTime copyWithZone:zone]
                    debugLoggingEnabled:self.debugLoggingEnabled
                             apiVersion:[self.apiVersion copyWithZone:zone]
                               delegate:nil];
}

// Read all values from the given dictionary
- (void) readFromDictionary:(NSMutableDictionary*)dict
{
    [customDrugDosageNames readFromDictionary:dict];
    [personNames readFromDictionary:dict];
    [subscriptionReceipts readFromDictionary:dict];

    NSSet* readKeys = [globalPrefs readFromDictionary:dict];
    
    if (![readKeys member:PurchasedPremiumKey]) // legacy
    {
        NSString* accountTypeStr = [dict objectForKey:LegacySubscriptionTypeKey];
        if (accountTypeStr)
        {
            if ([accountTypeStr isEqualToString:LegacyDemoAccountTypeName])
                [globalPrefs setValue:@"0" forKey:PurchasedPremiumKey];
            else // if ([accountTypeStr isEqualToString:LegacyPremiumAccountTypeName])
                [globalPrefs setValue:@"1" forKey:PurchasedPremiumKey];
        }
    }
    
    // Read last API version & detect whether an upgrade occurred. If so, notify about it.
    NSString* lastAPIVersionString = [globalPrefs valueForKey:APIVersionKey];
    if (![readKeys member:APIVersionKey])
    {
        lastAPIVersionString = @"Version 6.0.9";
        [globalPrefs setValue:lastAPIVersionString forKey:APIVersionKey]; // Write this into our preferences so that we set the modifiedDate and override what the server gives us on a sync
    }
    VersionNumber* lastAPIVersionNumber = [VersionNumber versionNumberWithVersionString:lastAPIVersionString];
    VersionNumber* currAPIVersion = [VersionNumber versionNumberWithVersionString:CurrAPIVersionStr];
    if ([currAPIVersion compare:lastAPIVersionNumber] == NSOrderedDescending)
    {
        [globalPrefs setValue:CurrAPIVersionStr forKey:APIVersionKey];
        NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:lastAPIVersionNumber forKey:@"version"];
        [userInfo setObject:dict forKey:@"dict"];
        [userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"interactive"];
        [userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"fileUpgrade"];
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyAPIUpgrade:) userInfo:userInfo repeats:NO];
    }
}

-(void) notifyAndHandleUpgrade:(VersionNumber*)lastAPIVersionNumber dict:(NSMutableDictionary*)dict isFileUpgrade:(BOOL)isFileUpgrade
{
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:dict forKey:GlobalSettingsAPIVersionUpgradeUserInfoDictionaryRead];
    [userInfo setObject:[NSNumber numberWithBool:isFileUpgrade] forKey:GlobalSettingsAPIVersionUpgradeUserInfoIsFileUpgrade];

    // Notify anyone who cares that we've upgraded from a past API version
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:GlobalSettingsAPIVersionUpgrade object:lastAPIVersionNumber userInfo:userInfo]];
    
    if ([lastAPIVersionNumber compareWithVersionString:@"Version 6.0.9"] == NSOrderedSame) // upgrade from v6.0.9
    {
        NSNumber* bedtimeStartNum = [dict objectForKey:BedtimeStartKey];
        NSString* bedtimeStartStr = @"-1";
        if (bedtimeStartNum)
            bedtimeStartStr = [NSString stringWithFormat:@"%d", [bedtimeStartNum intValue]];
        [globalPrefs setValue:bedtimeStartStr forKey:BedtimeStartKey];
        
        NSNumber* bedtimeEndNum = [dict objectForKey:BedtimeEndKey];
        NSString* bedtimeEndStr = @"-1";
        if (bedtimeEndNum)
            bedtimeEndStr = [NSString stringWithFormat:@"%d", [bedtimeEndNum intValue]];
        [globalPrefs setValue:bedtimeEndStr forKey:BedtimeEndKey];
    }
}

-(void) notifyAPIUpgrade:(NSTimer*)theTimer
{
    NSMutableDictionary* userInfo = theTimer.userInfo;
    VersionNumber* lastAPIVersionNumber = [userInfo objectForKey:@"version"];
    NSMutableDictionary* dict = [userInfo objectForKey:@"dict"];
    BOOL isInteractive = [((NSNumber*)[userInfo objectForKey:@"interactive"]) boolValue];
    BOOL isFileUpgrade = [((NSNumber*)[userInfo objectForKey:@"fileUpgrade"]) boolValue];
    
    // If the settings are updated interactively, perform the upgrade now while the user is waiting
    if (isInteractive)
        [self notifyAndHandleUpgrade:lastAPIVersionNumber dict:dict isFileUpgrade:isFileUpgrade];
    else
    {
        // If the settings are not updated interactively, display a spinner while we do the upgrade (and do it async so the user sees it)
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRefreshingDrugList", @"Dosecast", [DosecastUtil getResourceBundle], @"Refreshing drug list", @"The message appearing in the spinner view when refreshing the drug list"])];

        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyAPIUpgradeWithUI:) userInfo:userInfo repeats:NO];
    }
}

-(void) notifyAPIUpgradeWithUI:(NSTimer*)theTimer
{
    NSMutableDictionary* userInfo = theTimer.userInfo;
    VersionNumber* lastAPIVersionNumber = [userInfo objectForKey:@"version"];
    NSMutableDictionary* dict = [userInfo objectForKey:@"dict"];
    BOOL isFileUpgrade = [((NSNumber*)[userInfo objectForKey:@"fileUpgrade"]) boolValue];

    [self notifyAndHandleUpgrade:lastAPIVersionNumber dict:dict isFileUpgrade:isFileUpgrade];

    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
}

// Write all drug info into dictionary
- (void)populateDictionary:(NSMutableDictionary*)dict forSyncRequest:(BOOL)forSyncRequest completedInitialSync:(BOOL)completedInitialSync
{
    [customDrugDosageNames populateDictionary:dict forSyncRequest:forSyncRequest];
    [personNames populateDictionary:dict forSyncRequest:forSyncRequest];
    [subscriptionReceipts populateDictionary:dict forSyncRequest:forSyncRequest];

    [globalPrefs populateDictionary:dict forSyncRequest:forSyncRequest];
    
    // Dynamically include upload-only prefs that don't need to be stored locally
    if (forSyncRequest)
    {
        if (completedInitialSync) // only send whether the subscription is active after we've completed a first sync
        {
            BOOL devicePurchasedActiveSubscription = ([self purchasedSubscriptionExpires] && [[self purchasedSubscriptionExpires] timeIntervalSinceNow] > 0);
            [Preferences populatePreferenceInDictionary:dict key:SubscriptionActiveKey value:(devicePurchasedActiveSubscription ? @"1" : @"0") modifiedDate:[NSDate date] perDevice:YES];
        }
        
        NSString* deviceName = [DosecastUtil getDeviceName];
        if (!deviceName)
        {
            NSMutableString* newDeviceName = [NSMutableString stringWithString:@""];
            NSString* model = nil;
            int generation = 0;
            int version = 0;
            [DosecastUtil getPlatformDetails:&model generationNum:&generation versionNum:&version];
            [newDeviceName appendString:model];
            if (generation > 0)
                [newDeviceName appendFormat:@" %d", generation];
            deviceName = newDeviceName;
        }
        [Preferences populatePreferenceInDictionary:dict key:FriendlyNameKey value:deviceName modifiedDate:[NSDate date] perDevice:YES];

        [Preferences populatePreferenceInDictionary:dict key:OSVersionKey value:[DosecastUtil getOSVersionString] modifiedDate:[NSDate date] perDevice:YES];
        [Preferences populatePreferenceInDictionary:dict key:DeviceNameKey value:[DosecastUtil getPlatformName] modifiedDate:[NSDate date] perDevice:YES];
        [Preferences populatePreferenceInDictionary:dict key:LanguageKey value:[DosecastUtil getLanguageCountryCode] modifiedDate:[NSDate date] perDevice:YES];
        if (delegate && [delegate respondsToSelector:@selector(deviceToken)])
            [Preferences populatePreferenceInDictionary:dict key:DeviceTokenKey value:[delegate deviceToken] modifiedDate:[NSDate date] perDevice:YES];
        if (delegate && [delegate respondsToSelector:@selector(clientVersion)])
            [Preferences populatePreferenceInDictionary:dict key:ClientVersionKey value:[delegate clientVersion] modifiedDate:[NSDate date] perDevice:YES];
    }
}

// Update from provided server dictionary. Returns whether all notifications should be refreshed.
- (BOOL) updateFromServerDictionary:(NSMutableDictionary*)dict isInteractive:(BOOL)isInteractive currentServerTime:(NSDate*)currentServerTime limitToProductStatusOnly:(BOOL)limitToProductStatusOnly
{
    BOOL shouldRefreshAllNotifications = NO;
    
    if (limitToProductStatusOnly)
    {
        [globalPrefs updateFromServerDictionary:dict
                              currentServerTime:currentServerTime
                                    limitToKeys:[NSSet setWithObjects:ProductStatusKey, PurchasedSubscriptionExpiresKey, PurchasedPremiumKey, ManualSubscriptionExpiresKey, Issued7daySubscriptionTrialKey, nil]];
    }
    else
    {
        [customDrugDosageNames updateFromServerDictionary:dict currentServerTime:currentServerTime];
        [personNames updateFromServerDictionary:dict currentServerTime:currentServerTime];
        [subscriptionReceipts updateFromServerDictionary:dict currentServerTime:currentServerTime];

        NSSet* changedKeys = [globalPrefs updateFromServerDictionary:dict
                                                   currentServerTime:currentServerTime
                                                         limitToKeys:nil];
        
        if ([changedKeys member:ReminderSoundFilenameKey] ||
            [changedKeys member:SecondaryReminderPeriodSecsKey])
        {
            shouldRefreshAllNotifications = YES;
        }
        
        if ([changedKeys member:DebugLoggingEnabledKey] && !self.debugLoggingEnabled)
        {
            [[HistoryManager getInstance] deleteAllDebugLogEvents];
        }
        
        // Check whether the API version was changed. If so, detect whether an upgrade occurred, and if so, notify about it.
        if ([changedKeys member:APIVersionKey])
        {
            VersionNumber* lastAPIVersionNumber = [VersionNumber versionNumberWithVersionString:[globalPrefs valueForKey:APIVersionKey]];
            VersionNumber* currAPIVersion = [VersionNumber versionNumberWithVersionString:CurrAPIVersionStr];
            if ([currAPIVersion compare:lastAPIVersionNumber] == NSOrderedDescending)
            {
                [globalPrefs setValue:CurrAPIVersionStr forKey:APIVersionKey]; // update the API version with the current value
                NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
                [userInfo setObject:lastAPIVersionNumber forKey:@"version"];
                [userInfo setObject:dict forKey:@"dict"];
                [userInfo setObject:[NSNumber numberWithBool:isInteractive] forKey:@"interactive"];
                [userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"fileUpgrade"];
                [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyAPIUpgrade:) userInfo:userInfo repeats:NO];
            }
        }
    }

    return shouldRefreshAllNotifications;
}

- (BOOL) wasPremiumPurchasedOrGrantedByServer
{
    BOOL serverProvidesPremium = ([globalPrefs valueForKey:ProductStatusKey] && [[globalPrefs valueForKey:ProductStatusKey] isEqualToString:ProductStatusPremiumName]);
    BOOL devicePurchasedPremium = self.purchasedPremium;
    return (devicePurchasedPremium || serverProvidesPremium);
}

- (BOOL) wasSubscriptionPurchasedOrGrantedByServer
{
    BOOL serverProvidesSubcription = ([globalPrefs valueForKey:ProductStatusKey] && [[globalPrefs valueForKey:ProductStatusKey] isEqualToString:ProductStatusSubscriptionName]);
    NSDate* subscriptionExpiresDate = self.subscriptionExpires;
    BOOL devicePurchasedActiveSubscription = (subscriptionExpiresDate && [subscriptionExpiresDate timeIntervalSinceNow] > 0);
    return (serverProvidesSubcription || devicePurchasedActiveSubscription);
}

-(AccountType)accountType
{
    BOOL groupProvidesSubscription = delegate && [delegate respondsToSelector:@selector(doesAnyGroupGiveSubscription)] && [delegate doesAnyGroupGiveSubscription];
    BOOL serverProvidesSubcription = ([globalPrefs valueForKey:ProductStatusKey] && [[globalPrefs valueForKey:ProductStatusKey] isEqualToString:ProductStatusSubscriptionName]);
    NSDate* subscriptionExpiresDate = self.subscriptionExpires;
    BOOL devicePurchasedActiveSubscription = (subscriptionExpiresDate && [subscriptionExpiresDate timeIntervalSinceNow] > 0);

    if (groupProvidesSubscription || serverProvidesSubcription || devicePurchasedActiveSubscription)
        return AccountTypeSubscription;

    BOOL groupProvidesPremium = delegate && [delegate respondsToSelector:@selector(doesAnyGroupGivePremium)] && [delegate doesAnyGroupGivePremium];
    BOOL serverProvidesPremium = ([globalPrefs valueForKey:ProductStatusKey] && [[globalPrefs valueForKey:ProductStatusKey] isEqualToString:ProductStatusPremiumName]);
    BOOL devicePurchasedPremium = self.purchasedPremium;

    if (groupProvidesPremium || serverProvidesPremium || devicePurchasedPremium)
        return AccountTypePremium;
    else
        return AccountTypeDemo;
}

- (NSDate*) lastTimeZoneChangeTime
{
    NSString* lastTZChangeTimeStr = [globalPrefs valueForKey:LastTZChangeTimeKey];
    if (lastTZChangeTimeStr && [lastTZChangeTimeStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[lastTZChangeTimeStr longLongValue]];
    else
        return nil;
}

- (void) setLastTimeZoneChangeTime:(NSDate *)lastTZChangeTime
{
    NSString* lastTZChangeTimeStr = @"";
    if (lastTZChangeTime)
        lastTZChangeTimeStr = [NSString stringWithFormat:@"%lld", (long long)[lastTZChangeTime timeIntervalSince1970]];
    [globalPrefs setValue:lastTZChangeTimeStr forKey:LastTZChangeTimeKey];
}

- (NSDate*) lastTimeZoneChangeCheckTime
{
    NSString* lastTZChangeCheckTimeStr = [globalPrefs valueForKey:LastTZChangeCheckTimeKey];
    if (lastTZChangeCheckTimeStr && [lastTZChangeCheckTimeStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[lastTZChangeCheckTimeStr longLongValue]];
    else
        return nil;
}

- (void) setLastTimeZoneChangeCheckTime:(NSDate *)lastTZChangeCheckTime
{
    NSString* lastTZChangeCheckTimeStr = @"";
    if (lastTZChangeCheckTime)
        lastTZChangeCheckTimeStr = [NSString stringWithFormat:@"%lld", (long long)[lastTZChangeCheckTime timeIntervalSince1970]];
    [globalPrefs setValue:lastTZChangeCheckTimeStr forKey:LastTZChangeCheckTimeKey];
}

- (NSDate*) lastScheduledDaylightSavingsTimeChange
{
    NSString* lastScheduledDSTChangeStr = [globalPrefs valueForKey:LastScheduledDSTChangeKey];
    if (lastScheduledDSTChangeStr && [lastScheduledDSTChangeStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[lastScheduledDSTChangeStr longLongValue]];
    else
        return nil;
}

- (void) setLastScheduledDaylightSavingsTimeChange:(NSDate *)lastScheduledDSTChange
{
    NSString* lastScheduledDSTChangeStr = @"";
    if (lastScheduledDSTChange)
        lastScheduledDSTChangeStr = [NSString stringWithFormat:@"%lld", (long long)[lastScheduledDSTChange timeIntervalSince1970]];
    [globalPrefs setValue:lastScheduledDSTChangeStr forKey:LastScheduledDSTChangeKey];
}

- (NSDate*) purchasedSubscriptionExpires
{
    NSString* purchasedSubscriptionExpiresStr = [globalPrefs valueForKey:PurchasedSubscriptionExpiresKey];
    if (purchasedSubscriptionExpiresStr && [purchasedSubscriptionExpiresStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[purchasedSubscriptionExpiresStr longLongValue]];
    else
        return nil;
}

- (void) setPurchasedSubscriptionExpires:(NSDate *)purchasedSubscriptionExpires
{
    NSString* purchasedSubscriptionExpiresStr = @"";
    if (purchasedSubscriptionExpires)
        purchasedSubscriptionExpiresStr = [NSString stringWithFormat:@"%lld", (long long)[purchasedSubscriptionExpires timeIntervalSince1970]];
    [globalPrefs setValue:purchasedSubscriptionExpiresStr forKey:PurchasedSubscriptionExpiresKey];
}

- (NSDate*) manualSubscriptionExpires
{
    NSString* manualSubscriptionExpiresStr = [globalPrefs valueForKey:ManualSubscriptionExpiresKey];
    if (manualSubscriptionExpiresStr && [manualSubscriptionExpiresStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[manualSubscriptionExpiresStr longLongValue]];
    else
        return nil;
}

- (NSDate*) subscriptionExpires
{
    NSDate* purchSubscriptionExpires = [self purchasedSubscriptionExpires];
    NSDate* manualSubscriptionExpires = [self manualSubscriptionExpires];
    if (!purchSubscriptionExpires)
        return manualSubscriptionExpires;
    else if (!manualSubscriptionExpires)
        return purchSubscriptionExpires;
    else if ([purchSubscriptionExpires timeIntervalSinceDate:manualSubscriptionExpires] > 0)
        return purchSubscriptionExpires;
    else
        return manualSubscriptionExpires;
}

- (void) setSubscriptionExpires:(NSDate *)subscriptionExpires
{
    [self setPurchasedSubscriptionExpires:subscriptionExpires];
}

- (BOOL) purchasedPremium
{
    NSString* purchasedPremiumVal = [globalPrefs valueForKey:PurchasedPremiumKey];
    if (purchasedPremiumVal && [purchasedPremiumVal intValue] == 1)
        return YES;
    else
        return NO;
}

- (void) setPurchasedPremium:(BOOL)purchasedPremium
{
    [globalPrefs setValue:(purchasedPremium ? @"1" : @"0") forKey:PurchasedPremiumKey];
}

- (NSString*) premiumReceipt
{
    return [globalPrefs valueForKey:PremiumReceiptKey];
}

- (void) setPremiumReceipt:(NSString *)premiumReceipt
{
    if (!premiumReceipt)
        premiumReceipt = @"";
    [globalPrefs setValue:premiumReceipt forKey:PremiumReceiptKey];
}

- (NSNumber*) lastDaylightSavingsTimeOffset
{
    NSString* lastDaylightSavingsTimeOffsetStr = [globalPrefs valueForKey:LastDaylightSavingsTimeOffsetKey];
    if (lastDaylightSavingsTimeOffsetStr && [lastDaylightSavingsTimeOffsetStr length] > 0)
        return [NSNumber numberWithLongLong:(long long)[lastDaylightSavingsTimeOffsetStr longLongValue]];
    else
        return nil;
}

- (void) setLastDaylightSavingsTimeOffset:(NSNumber *)lastDaylightSavingsTimeOffset
{
    NSString* lastDaylightSavingsTimeOffsetStr = @"";
    if (lastDaylightSavingsTimeOffset)
        lastDaylightSavingsTimeOffsetStr = [NSString stringWithFormat:@"%lld", [lastDaylightSavingsTimeOffset longLongValue]];
    [globalPrefs setValue:lastDaylightSavingsTimeOffsetStr forKey:LastDaylightSavingsTimeOffsetKey];
}

- (NSNumber*) lastTimezoneGMTOffset
{
    NSString* lastTimezoneGMTOffsetStr = [globalPrefs valueForKey:LastTimezoneGMTOffsetKey];
    if (lastTimezoneGMTOffsetStr && [lastTimezoneGMTOffsetStr length] > 0)
        return [NSNumber numberWithLong:[lastTimezoneGMTOffsetStr longLongValue]];
    else
        return nil;
}

- (void) setLastTimezoneGMTOffset:(NSNumber *)lastTimezoneGMTOffset
{
    NSString* lastTimezoneGMTOffsetStr = @"";
    if (lastTimezoneGMTOffset)
        lastTimezoneGMTOffsetStr = [NSString stringWithFormat:@"%lld", [lastTimezoneGMTOffset longLongValue]];
    [globalPrefs setValue:lastTimezoneGMTOffsetStr forKey:LastTimezoneGMTOffsetKey];
}

- (NSString*) lastTimezoneName
{
    return [globalPrefs valueForKey:LastTimezoneNameKey];
}

- (void) setLastTimezoneName:(NSString *)lastTimezoneName
{
    if (!lastTimezoneName)
        lastTimezoneName = @"";
    [globalPrefs setValue:lastTimezoneName forKey:LastTimezoneNameKey];
}

- (NSDate*) lastManagedUpdate
{
    NSString* lastManagedUpdateStr = [globalPrefs valueForKey:LastManagedUpdateKey];
    if (lastManagedUpdateStr && [lastManagedUpdateStr longLongValue] > 0)
        return [NSDate dateWithTimeIntervalSince1970:[lastManagedUpdateStr longLongValue]];
    else
        return nil;
}

- (void) setLastManagedUpdate:(NSDate *)lastManagedUpdate
{
    NSString* lastManagedUpdateStr = @"";
    if (lastManagedUpdate)
        lastManagedUpdateStr = [NSString stringWithFormat:@"%lld", (long long)[lastManagedUpdate timeIntervalSince1970]];
    [globalPrefs setValue:lastManagedUpdateStr forKey:LastManagedUpdateKey];
}

- (NSString*) reminderSoundFilename
{
    return [globalPrefs valueForKey:ReminderSoundFilenameKey];
}

- (void) setReminderSoundFilename:(NSString *)reminderSoundFilename
{
    if (!reminderSoundFilename)
        reminderSoundFilename = @"";
    [globalPrefs setValue:reminderSoundFilename forKey:ReminderSoundFilenameKey];
}

- (NSString*) userData
{
    return [globalPrefs valueForKey:UserDataKey];
}

- (void) setUserData:(NSString *)userData
{
    if (!userData)
        userData = @"";
    [globalPrefs setValue:userData forKey:UserDataKey];
}

- (int) doseHistoryDays
{
    NSString* doseHistoryDaysStr = [globalPrefs valueForKey:DoseHistoryDaysKey];
    if (doseHistoryDaysStr)
        return [doseHistoryDaysStr intValue];
    else
        return DEFAULT_DOSE_HISTORY_DAYS;
}

- (void) setDoseHistoryDays:(int)doseHistoryDays
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", doseHistoryDays] forKey:DoseHistoryDaysKey];   
}

- (BOOL) postponesDisplayed
{
    NSString* postponesDisplayedStr = [globalPrefs valueForKey:PostponesDisplayedKey];
    if (postponesDisplayedStr)
        return ([postponesDisplayedStr intValue] == 1 ? YES : NO);
   else
       return DEFAULT_POSTPONES_DISPLAYED;
}

-(void) setPostponesDisplayed:(BOOL)postponesDisplayed
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (postponesDisplayed ? 1 : 0)] forKey:PostponesDisplayedKey];
}

- (BOOL) debugLoggingEnabled
{
    NSString* debugLoggingEnabledStr = [globalPrefs valueForKey:DebugLoggingEnabledKey];
    if (debugLoggingEnabledStr)
        return ([debugLoggingEnabledStr intValue] == 1 ? YES : NO);
    else
        return NO;
}

-(void) setDebugLoggingEnabled:(BOOL)debugLoggingEnabled
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (debugLoggingEnabled ? 1 : 0)] forKey:DebugLoggingEnabledKey];
}

- (BOOL) archivedDrugsDisplayed
{
    NSString* archivedDrugsDisplayedStr = [globalPrefs valueForKey:ArchivedDrugsDisplayedKey];
    if (archivedDrugsDisplayedStr)
        return ([archivedDrugsDisplayedStr intValue] == 1 ? YES : NO);
    else
        return NO;
}

- (void) setArchivedDrugsDisplayed:(BOOL)archivedDrugsDisplayed
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (archivedDrugsDisplayed ? 1 : 0)] forKey:ArchivedDrugsDisplayedKey];
}

- (BOOL)drugImagesDisplayed
{
    NSString* drugImagesDisplayedStr = [globalPrefs valueForKey:DrugImagesDisplayedKey];
    if (drugImagesDisplayedStr)
        return ([drugImagesDisplayedStr intValue] == 1 ? YES : NO);
    else
        return DEFAULT_DRUG_IMAGES_DISPLAYED;
}

- (void) setDrugImagesDisplayed:(BOOL)drugImagesDisplayed
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (drugImagesDisplayed ? 1 : 0)] forKey:DrugImagesDisplayedKey];
}

- (BOOL) drugNamesDisplayedInNotifications
{
    NSString* drugNamesDisplayedInNotificationsStr = [globalPrefs valueForKey:DrugNamesDisplayedInNotificationsKey];
    if (drugNamesDisplayedInNotificationsStr)
        return ([drugNamesDisplayedInNotificationsStr intValue] == 0 ? YES : NO);
    else
        return NO;
}

- (void) setDrugNamesDisplayedInNotifications:(BOOL)drugNamesDisplayedInNotifications
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (drugNamesDisplayedInNotifications ? 0 : 1)] forKey:DrugNamesDisplayedInNotificationsKey];
}

- (BOOL) preventEarlyDrugDoses
{
    NSString* preventEarlyDrugDosesStr = [globalPrefs valueForKey:PreventEarlyDrugDosesKey];
    if (preventEarlyDrugDosesStr)
        return ([preventEarlyDrugDosesStr intValue] == 1 ? YES : NO);
    else
        return DEFAULT_PREVENT_EARLY_DRUG_DOSES;
}

- (void) setPreventEarlyDrugDoses:(BOOL)preventEarlyDrugDoses
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (preventEarlyDrugDoses ? 1 : 0)] forKey:PreventEarlyDrugDosesKey];
}

- (DrugSortOrder) drugSortOrder
{
    NSString* drugSortOrderStr = [globalPrefs valueForKey:DrugSortOrderKey];
    if (drugSortOrderStr)
        return (DrugSortOrder)([drugSortOrderStr intValue]);
    else
        return DrugSortOrderByNextDoseTime;
}

- (void) setDrugSortOrder:(DrugSortOrder)drugSortOrder
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (int)drugSortOrder] forKey:DrugSortOrderKey];
}

- (int) lateDosePeriodSecs
{
    NSString* lateDosePeriodSecsStr = [globalPrefs valueForKey:LateDosePeriodSecsKey];
    if (lateDosePeriodSecsStr)
        return [lateDosePeriodSecsStr intValue];
    else
        return DEFAULT_LATE_DOSE_PERIOD_SECS;
}

- (void) setLateDosePeriodSecs:(int)lateDosePeriodSecs
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", lateDosePeriodSecs] forKey:LateDosePeriodSecsKey];
}

- (int) secondaryReminderPeriodSecs
{
    NSString* secondaryReminderPeriodSecsStr = [globalPrefs valueForKey:SecondaryReminderPeriodSecsKey];
    if (secondaryReminderPeriodSecsStr)
        return [secondaryReminderPeriodSecsStr intValue];
    else
        return DEFAULT_SECONDARY_REMINDER_PERIOD_SECS;
}

- (void) setSecondaryReminderPeriodSecs:(int)secondaryReminderPeriodSecs
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", secondaryReminderPeriodSecs] forKey:SecondaryReminderPeriodSecsKey];
}

- (BOOL) issued7daySubscriptionTrial
{
    NSString* issued7daySubscriptionTrialStr = [globalPrefs valueForKey:Issued7daySubscriptionTrialKey];
    if (issued7daySubscriptionTrialStr)
        return ([issued7daySubscriptionTrialStr intValue] == 1 ? YES : NO);
    else
        return NO;
}

- (void) setIssued7daySubscriptionTrial:(BOOL)issued7daySubscriptionTrial
{
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", (issued7daySubscriptionTrial ? 1 : 0)] forKey:Issued7daySubscriptionTrialKey];
}

- (int) bedtimeStart
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
    NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];
    
    NSString* bedtimeStartStr = [globalPrefs valueForKey:BedtimeStartKey];
    if (!bedtimeStartStr || [bedtimeStartStr length] == 0)
        bedtimeStartStr = @"-1";

    // Convert from GMT
    int bedtimeStartLocal = [bedtimeStartStr intValue];
    if (bedtimeStartLocal >= 0)
    {
        NSDate* timeLocal = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeStartLocal] timeInterval:secondsFromGMT];
        bedtimeStartLocal = [DosecastUtil getDateAs24hrTime:timeLocal];
    }
    return bedtimeStartLocal;
}

- (void) setBedtimeStart:(int)bedtimeStart
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
    NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];

    // Convert to GMT
    int bedtimeStartGMTNum = -1;
    if (bedtimeStart >= 0)
    {
        NSDate* bedtimeStartLocalGMT = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeStart] timeInterval:-secondsFromGMT];
        bedtimeStartGMTNum = [DosecastUtil getDateAs24hrTime:bedtimeStartLocalGMT];
    }
    
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", bedtimeStartGMTNum] forKey:BedtimeStartKey];
}

- (int) bedtimeEnd
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
    NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];
    
    NSString* bedtimeEndStr = [globalPrefs valueForKey:BedtimeEndKey];
    if (!bedtimeEndStr || [bedtimeEndStr length] == 0)
        bedtimeEndStr = @"-1";
    
    // Convert from GMT
    int bedtimeEndLocal = [bedtimeEndStr intValue];
    if (bedtimeEndLocal >= 0)
    {
        NSDate* timeLocal = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeEndLocal] timeInterval:secondsFromGMT];
        bedtimeEndLocal = [DosecastUtil getDateAs24hrTime:timeLocal];
    }
    return bedtimeEndLocal;
}

- (void) setBedtimeEnd:(int)bedtimeEnd
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
    NSInteger secondsFromGMT = [localTimeZone secondsFromGMT];

    // Convert to GMT
    int bedtimeEndGMTNum = -1;
    if (bedtimeEnd >= 0)
    {
        NSDate* bedtimeEndLocalGMT = [DosecastUtil addTimeIntervalToDate:[DosecastUtil get24hrTimeAsDate:bedtimeEnd] timeInterval:-secondsFromGMT];
        bedtimeEndGMTNum = [DosecastUtil getDateAs24hrTime:bedtimeEndLocalGMT];
    }
    
    [globalPrefs setValue:[NSString stringWithFormat:@"%d", bedtimeEndGMTNum] forKey:BedtimeEndKey];
}

- (NSArray*) allSubscriptionReceipts
{
    NSMutableArray* allReceipts = [[NSMutableArray alloc] init];

    NSArray* allReceiptKeys = [subscriptionReceipts allKeys];
    for (NSString* key in allReceiptKeys)
    {
        [allReceipts addObject:[subscriptionReceipts valueForKey:key]];
    }
    
    return allReceipts;
}

- (void) addSubscriptionReceipt:(NSString *)receipt
{
    [subscriptionReceipts setValue:receipt forKey:nil];
}

- (VersionNumber*) apiVersion
{
    NSString* apiVersionStr = [globalPrefs valueForKey:APIVersionKey];
    if (apiVersionStr && [apiVersionStr length] > 0)
        return [VersionNumber versionNumberWithVersionString:apiVersionStr];
    else
        return nil;
}

@end
