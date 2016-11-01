//
//  DosecastAPIFlags.h
//  Dosecast
//
//  Created by Jonathan Levene on 6/23/12.
//  Copyright 2012 Montuno Software. All rights reserved.
//

//
// ---------------- Flags to pass-in at initialization time
//
extern NSString *DosecastAPIShowAccount;                             // Whether to show the Account type (demo or premium)
extern NSString *DosecastAPIShowNativeUIOnIPad;                      // Whether to show the full, native UI on iPad
extern NSString *DosecastAPIMultiPersonSupport;                      // Whether multi-person support should be enabled
extern NSString *DosecastAPITrackRemainingQuantities;                // Whether tracking of remaining quantities should be enabled
extern NSString *DosecastAPITrackRefillsRemaining;                   // Whether tracking of refills remaining should be enabled
extern NSString *DosecastAPIDoctorSupport;                           // Whether doctor support should be enabled
extern NSString *DosecastAPIPharmacySupport;                         // Whether pharmacy support should be enabled
extern NSString *DosecastAPIPrescriptionNumberSupport;               // Whether prescription number support should be enabled
extern NSString *DosecastAPIShowMainToolbar;                         // Whether to show the toolbar in the main screen
extern NSString *DosecastAPIShowDrugInfoToolbar;                     // Whether to show the toolbar in the drug info screen
extern NSString *DosecastAPIShowHistoryToolbar;                      // Whether to show the toolbar in the history screen
extern NSString *DosecastAPIEnableDebugLog;                          // Whether to capture debug log events
extern NSString *DosecastAPIEnablePasscodeSettings;                  // Whether to enable changing the passcode from the settings screen
extern NSString *DosecastAPIShowVersionInSettings;                   // Whether to show the version in the settings screen
extern NSString *DosecastAPIEnableUSDrugDatabaseSearch;              // Whether to enable the user to search the US drug database
extern NSString *DosecastAPIEnableUSDrugDatabaseTypes;               // Whether to enable the user to pick drug types from the US drug database
extern NSString *DosecastAPIEnableDeleteAllDataSettings;             // Whether to enable the user to delete all data from the settings screen
extern NSString *DosecastAPIIdentifyServerAccountByUserData;         // Whether the server should identify the user's account by the user data value
extern NSString *DosecastAPIEnableSecondaryRemindersByDefault;       // whether to enable secondary reminders by default
extern NSString *DosecastAPIEnableShowArchivedDrugs;                 // whether to enable showing archived drugs
extern NSString *DosecastAPIShowArchivedDrugsByDefault;              // whether to show archived drugs by default
extern NSString *DosecastAPIEnableShowDrugImages;                    // whether to enable showing drug images
extern NSString *DosecastAPIWarnOnEmailingDrugInfo;                  // whether to warn the user before sending emails containing drug info
extern NSString *DosecastAPIEnableShowDrugNamesInNotifications;      // whether to enable showing drug names in notifications
extern NSString *DosecastAPIShowDrugNamesInNotificationsByDefault;   // whether to show drug names in notifications by default
extern NSString *DosecastAPIDisplayUnarchivedDrugStatusInDrugInfo;   // whether to display the unarchived drug status in the drug info screen (as opposed to the archived drug status)
extern NSString *DosecastAPIEnableGroups;                            // whether to enable group support
extern NSString *DosecastAPIEnableSync;                              // whether to enable sync

//
// ---------------- Notifications to optionally subscribe to
//
extern NSString *DosecastAPIDisplayUserAlertsNotification;           // This notification is fired when it is safe to display user alerts
