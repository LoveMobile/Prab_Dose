//
//  DosecastUtil.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/22/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AddressBook/AddressBook.h"

@interface DosecastUtil : NSObject {

}

// This notification is fired when address book access is granted
extern NSString *DosecastUtilAddressBookAccessGranted;

// Set a background color for the given button
+ (void)setBackgroundColorForButton:(UIButton*)button color:(UIColor*)color;

// Set a glossy background for the given button
+ (void)setGlossyBackgroundForButton:(UIButton*)button color:(UIColor*)color;

// Device name
+ (NSString*)getDeviceName;

// Returns current OS version
+ (NSString*)getOSVersionString;

// Returns current OS version
+ (float)getOSVersionFloat;

// Returns current language code
+ (NSString*) getLanguageCode;

// Returns current country code
+ (NSString*) getCountryCode;

// Returns <language code>_<country code>
+ (NSString*) getLanguageCountryCode;

// Returns the decimal separator for the current locale
+ (NSString*) getDecimalSeparator;

// Returns whether this device is an iPad
+ (BOOL)isIPad;

// Returns current hardware ID
+ (NSString*)getHardwareID;

// Platform name
+ (NSString*)getPlatformName;

// Returns the device platform details
+ (void) getPlatformDetails:(NSString**)model
              generationNum:(int*)generationNum
                 versionNum:(int*)versionNum;

// Create a unique GUID
+ (NSString*) createGUID;

// Returns whether to allow contacts access
+ (BOOL) allowContactsAccess;

// Returns a newly-created address book. Caller must release this by calling CFRelease if non-NULL.
+ (ABAddressBookRef) newAddressBook;

// Returns a device token as a string
+ (NSString*)getDeviceTokenAsString:(NSData*)devToken;

// Returns device-specific file or nib name
+ (NSString*)getDeviceSpecificNibName:(NSString*)nibName;
+ (NSString*)getDeviceSpecificFilename:(NSString*)filename;

// The current timezone GMT offset, name, daylight savings time offset
+ (NSNumber*)getCurrTimezoneGMTOffset;
+ (NSString*)getCurrTimezoneName;
+ (NSNumber*)getCurrDaylightSavingsTimeOffset;

// Product component name (appearing in view titles)
+ (NSString*)getProductComponentName;

// Product app name (appearing in alert messages)
+ (NSString*)getProductAppName;

// Return a new string with first letter capitalized
+ (NSString*)capitalizeFirstLetterOfString:(NSString*)s;

// Returns midnight on the given day
+ (NSDate*)getMidnightOnDate:(NSDate*)date;

// Adds the given number of days to the given date
+ (NSDate*)addDaysToDate:(NSDate*)date numDays:(int)numDays;

// Adds the given number of months to the given date
+ (NSDate*)addMonthsToDate:(NSDate*)date numMonths:(int)numMonths;

// Returns the time of the last second on the given day
+ (NSDate*)getLastSecondOnDate:(NSDate*)date;

// Returns the name of the day of the week corresponding to the given date
+ (NSString*)getDayOfWeekForDate:(NSDate*)date;

// Returns whether 2 dates are on the same day
+ (BOOL)areDatesOnSameDay:(NSDate*)date1 date2:(NSDate*)date2;

// Returns the abbreviated name of the day of the week corresponding to the given date
+ (NSString*)getAbbrevDayOfWeekForDate:(NSDate*)date;

// Returns a UIColor object from a string of the format R G B A using float values
+ (UIColor*)getColorFromString:(NSString*)colorStr;

// Colors of UI components
+ (UIColor*)getNavigationBarColor;
+ (UIColor*)getToolbarColor;
+ (UIColor*)getDrugViewLabelColor;
+ (UIColor*)getDrugViewManagedDrugNotificationColor;
+ (UIColor*)getDrugViewManagedDrugNotificationBackgroundColor;
+ (UIColor*)getDrugWarningLabelColor;
+ (UIColor*)getProductPriceButtonColor;
+ (UIColor*)getRestorePurchaseButtonColor;
+ (UIColor*)getDeleteButtonColor;
+ (UIColor*)getArchiveButtonColor;
+ (UIColor*)getMessagePanelBackgroundColor;
+ (UIColor*)getMessagePanelTextColor;
+ (UIColor*)getHistoryLateDoseTextColor;
+ (UIColor*)getHistoryMissDoseLabelColor;
+ (UIColor*)getSpinnerLabelColor;
+ (UIColor*)getDrugCellButtonColor;
+ (UIColor*)getDrugImagePlaceholderColor;
+ (UIColor*)getDoseAlertButtonColor;
+ (UIColor*)getJoinGroupButtonColor;

// Method to get top navigation controller from the window
+ (UINavigationController*)getTopNavigationController:(UINavigationController*)mainNavigationController;

+ (NSBundle*)getResourceBundle;
+ (NSString*)getResourceBundleName;

// Returns the current time on a day in which no daylight savings boundary exists
+ (NSDate*)getCurrentTimeOnNonDaylightSavingsBoundaryDay;

+ (NSDate*)get24hrTimeAsDate:(int)time;
+ (int)getDateAs24hrTime:(NSDate*)date;

// Gets path to local file
+ (NSString *)getPathToLocalFile:(NSString*)filename;

// Returns a new NSDate object that is offset by the given time interval
+ (NSDate*)addTimeIntervalToDate:(NSDate*)date timeInterval:(NSTimeInterval)seconds;

// Returns whether the singular form of a noun should be used for the given integer. If NO, then the plural form should be used.
+ (BOOL) shouldUseSingularForInteger:(int)i;

// Returns whether the singular form of a noun should be used for the given float. If NO, then the plural form should be used.
+ (BOOL) shouldUseSingularForFloat:(float)f;

@end