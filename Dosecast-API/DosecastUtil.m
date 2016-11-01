//
//  DosecastUtil.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/22/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DosecastUtil.h"
#import "UIButton+Glossy.h"
#import "DataModel.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "AdSupport/ASIdentifierManager.h"
#import "DosecastKeychainItemWrapper.h"
#import "UIDeviceHardware.h"
#import "HistoryManager.h"
#import <Security/SecItem.h>

static double SEC_PER_DAY = 60*60*24;

static DosecastKeychainItemWrapper *gHardwareIDKeychainItem = nil;

@implementation DosecastUtil

// Set a background color for the given button
+ (void)setBackgroundColorForButton:(UIButton*)button color:(UIColor*)color
{
    [button setBackgroundToRectOfColor:color forState:UIControlStateNormal];
    
    CGFloat hue, sat, val, alpha;
    [color getHue:&hue saturation:&sat brightness:&val alpha:&alpha];
    UIColor* selectColor = [UIColor colorWithHue:hue saturation:sat brightness:val*0.5 alpha:alpha];
    [button setBackgroundToRectOfColor:selectColor forState:UIControlStateHighlighted];
    [button setBackgroundToRectOfColor:selectColor forState:UIControlStateSelected];
}

// Set a glossy background for the given button
+ (void)setGlossyBackgroundForButton:(UIButton*)button color:(UIColor*)color
{
	// Configure background image(s)
	[button setBackgroundToGlossyRectOfColor:color withBorder:YES forState:UIControlStateNormal];
    
    CGFloat hue, sat, val, alpha;
    [color getHue:&hue saturation:&sat brightness:&val alpha:&alpha];
    UIColor* selectColor = [UIColor colorWithHue:hue saturation:sat brightness:val*0.5 alpha:alpha];
    [button setBackgroundToGlossyRectOfColor:selectColor withBorder:YES forState:UIControlStateHighlighted];
    [button setBackgroundToGlossyRectOfColor:selectColor withBorder:YES forState:UIControlStateSelected];
}

// Device model
+ (NSString*)getDeviceModel
{
	return [[UIDevice currentDevice] model];
}

// Device name
+ (NSString*)getDeviceName
{
    return [[UIDevice currentDevice] name];
}

// Returns current OS version
+ (NSString*)getOSVersionString {
	return [[UIDevice currentDevice] systemVersion];
}

// Returns current OS version
+ (float)getOSVersionFloat {
    static float osVersionFloat = -1.0f;
    if (osVersionFloat < 0.0f)
    {
        NSString* osVersionString = [DosecastUtil getOSVersionString];
        NSRange range = [osVersionString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
        NSString* osVersionStringStripped = osVersionString;
        if (range.location != NSNotFound)
            osVersionStringStripped = [osVersionString substringToIndex:range.location+2];
        osVersionFloat = [osVersionStringStripped floatValue];
    }
    return osVersionFloat;
}

// Returns the decimal separator for the current locale
+ (NSString*) getDecimalSeparator
{
    return [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleDecimalSeparator];
}

// Returns current language code
+ (NSString*) getLanguageCode
{
    return [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
}

// Returns current country code
+ (NSString*) getCountryCode
{
    return [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
}

// Returns <language code>_<country code>
+ (NSString*) getLanguageCountryCode
{
    return [NSString stringWithFormat:@"%@_%@", [DosecastUtil getLanguageCode], [DosecastUtil getCountryCode]];
}

// Returns whether this device is an iPad
+ (BOOL)isIPad
{
	if (![[DataModel getInstance].apiFlags getFlag:DosecastAPIShowNativeUIOnIPad])
		return NO;
	
	NSString* devName = [DosecastUtil getDeviceModel];
	NSRange iPadRange = [devName rangeOfString:@"iPad" options:NSCaseInsensitiveSearch];
	return iPadRange.location != NSNotFound;
}

// Returns current hardware ID in the keychain
+ (NSString*)getHardwareIDInKeychain
{
    // Create our own identifier for this hardware and store it in the keychain so it persists across installs.
    @synchronized(self)
    {
        if (!gHardwareIDKeychainItem)
        {
            gHardwareIDKeychainItem = [[DosecastKeychainItemWrapper alloc] initWithIdentifier:@"HardwareID" accessGroup:nil];
        }
    }
    
    NSString* hardwareID = [gHardwareIDKeychainItem objectForKey:(__bridge id)(kSecValueData)];
    if (hardwareID && [hardwareID length] > 0)
    {
        id object = [gHardwareIDKeychainItem objectForKey:(__bridge id)kSecAttrAccessible];
        if (object)
        {
            CFTypeRef accessibility = (__bridge CFTypeRef)object;
            if (accessibility != kSecAttrAccessibleAlways)
                [gHardwareIDKeychainItem setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];
        }
        else
            [gHardwareIDKeychainItem setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];
    }
    
    return hardwareID;
}

// Sets the current hardware ID in the keychain
+ (void)setHardwareIDInKeychain:(NSString*)hardwareID
{
    // Create our own identifier for this hardware and store it in the keychain so it persists across installs.
    @synchronized(self)
    {
        if (!gHardwareIDKeychainItem)
        {
            gHardwareIDKeychainItem = [[DosecastKeychainItemWrapper alloc] initWithIdentifier:@"HardwareID" accessGroup:nil];
        }
    }
    
    [gHardwareIDKeychainItem setObject:hardwareID forKey:(__bridge id)(kSecValueData)];
    [gHardwareIDKeychainItem setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];
}

// Platform name
+ (NSString*)getPlatformName
{
    return [UIDeviceHardware platform];
}

// Returns the device platform details
+ (void) getPlatformDetails:(NSString**)model
              generationNum:(int*)generationNum
                 versionNum:(int*)versionNum
{
    [UIDeviceHardware platformDetails:model generationNum:generationNum versionNum:versionNum];
}

// Create a unique GUID
+ (NSString*) createGUID
{
	CFUUIDRef identifier = CFUUIDCreate(NULL);
    NSString* identifierString = (NSString*)CFBridgingRelease(CFUUIDCreateString(NULL, identifier));
    CFRelease(identifier);
	return identifierString;
}

+ (NSString*)getDeviceSpecificNibName:(NSString*)nibName
{
	NSMutableString* s = [NSMutableString stringWithString:nibName];
	if ([DosecastUtil isIPad])
		[s appendString:@"-iPad"];
	return s;
}

+ (NSString*)getDeviceSpecificFilename:(NSString*)filename
{
	NSRange range = [filename rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
	if (range.location != NSNotFound)
	{
		NSString* preDotFilename = [filename substringToIndex:range.location];
		NSString* postDotFilename = [filename substringFromIndex:(range.location+1)];
		NSMutableString* s = [NSMutableString stringWithString:preDotFilename];
		if ([DosecastUtil isIPad])
			[s appendString:@"-iPad"];
		[s appendFormat:@".%@", postDotFilename];
		return s;
	}
	else
		return filename;
}

+ (NSNumber*) getCurrTimezoneGMTOffset
{
	NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
	return [NSNumber numberWithLong:[localTimeZone secondsFromGMT]];	
}

+ (NSString*) getCurrTimezoneName
{
	NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
	return [NSString stringWithFormat:@"%@ (%@)", [localTimeZone name], [localTimeZone abbreviation]];	
}

+ (NSNumber*)getCurrDaylightSavingsTimeOffset
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
	return [NSNumber numberWithDouble:[localTimeZone daylightSavingTimeOffset]];
}

+ (NSDate*)getNextDaylightSavingsTimeTransition
{
    NSTimeZone* localTimeZone = [NSTimeZone localTimeZone];
    return [localTimeZone nextDaylightSavingTimeTransition];
}

// Product component name (appearing in view titles)
+ (NSString*)getProductComponentName
{
	return NSLocalizedStringWithDefaultValue(@"NameProductComponent", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The name of the component containing the reminder functionality"]);	
}

// Product app name (appearing in alert messages)
+ (NSString*)getProductAppName
{
	return NSLocalizedStringWithDefaultValue(@"NameProductApp", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosecast", @"The name of the app"]);	
}

// Return a new string with first letter capitalized
+ (NSString*)capitalizeFirstLetterOfString:(NSString*)s
{
	if (!s || [s length] == 0)
		return nil;
	
	NSString* firstLetter = [s substringToIndex:1];
	NSString* restOfString = [s substringFromIndex:1];
	return [NSString stringWithFormat:@"%@%@", [firstLetter capitalizedString], restOfString];
}

// Colors of UI components


// Returns a UIColor object from a string of the format R G B A using float values
+ (UIColor*)getColorFromString:(NSString*)colorStr
{
	NSMutableString* mutableColorStr = [NSMutableString stringWithString:colorStr];
	
	float array[] = {0,0,0,0};
	
	for (int i = 0; i < 4; i++)
	{
		if (i == 3)
			array[i] = [mutableColorStr floatValue];
		else
		{
			NSRange range = [mutableColorStr rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
			if (range.location != NSNotFound)
			{
				array[i] = [[mutableColorStr substringToIndex:range.location] floatValue];
				[mutableColorStr deleteCharactersInRange:NSMakeRange(0, range.location+1)];
			}
		}
	}	
	
	return [UIColor colorWithRed:array[0] green:array[1] blue:array[2] alpha:array[3]];
}

+ (UIColor*)getNavigationBarColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorNavigationBar", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the navigation bar"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getToolbarColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorToolbar", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the toolbar"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getDrugViewLabelColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugViewLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the labels in the drug view"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getDrugViewManagedDrugNotificationColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugViewManagedDrugNotification", @"Dosecast", [DosecastUtil getResourceBundle], @"1 1 1 1", @"Color of the notifications in the drug view"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getDrugViewManagedDrugNotificationBackgroundColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugViewManagedDrugNotificationBackground", @"Dosecast", [DosecastUtil getResourceBundle], @"0.35 0.35 0.35 1", @"Color of the notifications in the drug view"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getDrugWarningLabelColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugWarningLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"1 0 0 1", @"Color of the drug warning labels"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getProductPriceButtonColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorProductPriceButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the product price button"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getRestorePurchaseButtonColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorRestorePurchaseButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 0.65", @"Color of the restore purchase button"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getDeleteButtonColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugEditDeleteButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0.79 0 0 1", @"Color of the delete button in the drug edit view"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getArchiveButtonColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugEditArchiveButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the archive button in the drug edit view"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getMessagePanelBackgroundColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorMessagePanelBackground", @"Dosecast", [DosecastUtil getResourceBundle], @"0.99 0.97 0.97 1", @"Color of the message panel background"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getMessagePanelTextColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorMessagePanelText", @"Dosecast", [DosecastUtil getResourceBundle], @"0.92 0.36 0.34 1", @"Color of the message panel text"]);
	return [DosecastUtil getColorFromString:colorStr];	
}

+ (UIColor*)getHistoryLateDoseTextColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugHistoryLateDoseText", @"Dosecast", [DosecastUtil getResourceBundle], @"0.82 0.82 0 1", @"Color of the drug history late dose text"]);
	return [DosecastUtil getColorFromString:colorStr];	    
}

+ (UIColor*)getHistoryMissDoseLabelColor
{
	NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugHistoryMissDoseLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"1 0 0 1", @"Color of the drug history miss dose label"]);
	return [DosecastUtil getColorFromString:colorStr];	    
}

+ (UIColor*)getSpinnerLabelColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorSpinnerLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"1 1 1 1", @"Color of the main label in the spinner view"]);
	return [DosecastUtil getColorFromString:colorStr];	    
}

+ (UIColor*)getDrugCellButtonColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugCellButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the drug cell buttons"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getDrugImagePlaceholderColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDrugImagePlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"0.63 0.69 0.73 1", @"Color of the drug image placeholder"]);
	return [DosecastUtil getColorFromString:colorStr];    
}

+ (UIColor*)getDoseAlertButtonColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorDoseAlertButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0.26 0.34 0.55 1", @"Color of the dose alert button"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getJoinGroupButtonColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorJoinGroupButton", @"Dosecast", [DosecastUtil getResourceBundle], @"0 0.27 0.45 1", @"Color of the join group button"]);
	return [DosecastUtil getColorFromString:colorStr];
}

+ (UIColor*)getViewBackgroundColor
{
    NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorViewBackground", @"Dosecast", [DosecastUtil getResourceBundle], @"0.86 0.86 0.86 1", @"Color of the join group button"]);
    return [DosecastUtil getColorFromString:colorStr];    
}

// Returns the name of the day of the week corresponding to the given date
+ (NSString*)getDayOfWeekForDate:(NSDate*)date
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	unsigned unitFlags = NSWeekdayCalendarUnit;
	NSDateComponents* timeComponents = [cal components:unitFlags fromDate:date];
	int weekday = (int)[timeComponents weekday];
    int firstWeekday = (int)[cal firstWeekday];
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = cal;
	NSArray* weekdays = [dateFormatter weekdaySymbols];
	return [weekdays objectAtIndex:weekday-firstWeekday];
}

// Returns whether 2 dates are on the same day
+ (BOOL)areDatesOnSameDay:(NSDate*)date1 date2:(NSDate*)date2
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
    NSDateComponents* date1Components = [cal components:unitFlags fromDate:date1];
    NSDateComponents* date2Components = [cal components:unitFlags fromDate:date2];
    
    return ([date1Components day] == [date2Components day] &&
            [date1Components month] == [date2Components month] &&
            [date1Components year] == [date2Components year]);
}

// Returns the abbreviated name of the day of the week corresponding to the given date
+ (NSString*)getAbbrevDayOfWeekForDate:(NSDate*)date
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	unsigned unitFlags = NSWeekdayCalendarUnit;
	NSDateComponents* timeComponents = [cal components:unitFlags fromDate:date];
	int weekday = (int)[timeComponents weekday];
    int firstWeekday = (int)[cal firstWeekday];
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.calendar = cal;
	NSArray* weekdays = [dateFormatter shortWeekdaySymbols];
	return [weekdays objectAtIndex:weekday-firstWeekday];
}

// Method to get top navigation controller from the window
+ (UINavigationController*)getTopNavigationController:(UINavigationController*)mainNavigationController
{
	if (!mainNavigationController)
		return nil;
	
	UINavigationController* topNavController = mainNavigationController;
	UINavigationController* nextNavController = nil;
	
    UIViewController* modalController = nil;
    modalController = topNavController.presentedViewController;

	// Look for the top view controller in the current stack that is a nav controller.
	// If none, look for a modal view controller that is a nav controller.
	if ([topNavController.topViewController isKindOfClass:[UINavigationController class]])
		nextNavController = (UINavigationController*)topNavController.topViewController;
	if (!nextNavController &&
		[modalController isKindOfClass:[UINavigationController class]])
		nextNavController = (UINavigationController*)modalController;
	while (nextNavController)
	{
		topNavController = nextNavController;
		nextNavController = nil;
        
        modalController = topNavController.presentedViewController;

		if ([topNavController.topViewController isKindOfClass:[UINavigationController class]])
			nextNavController = (UINavigationController*)topNavController.topViewController;
		if (!nextNavController &&
			[modalController isKindOfClass:[UINavigationController class]])
			nextNavController = (UINavigationController*)modalController;
	}
	
	return topNavController;
}

+ (NSBundle*) getResourceBundle
{
	NSString* bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[DosecastUtil getResourceBundleName]];
	return [NSBundle bundleWithPath:bundlePath];
}

+ (NSString*) getResourceBundleName
{
	return @"Dosecast-resources.bundle";
}

// Method to get a day which isn't on a daylight savings boundary
+ (NSDate*)getNonDaylightSavingsBoundaryDay
{
	NSDate* now = [NSDate date];
	NSTimeZone* timeZone = [NSTimeZone localTimeZone];

    NSDate* yesterday = [DosecastUtil addDaysToDate:now numDays:-2];
    NSDate* tomorrow = [DosecastUtil addDaysToDate:now numDays:2];

    // See if we're within + or - 2 days of a daylight savings transition
	if ([timeZone isDaylightSavingTimeForDate:yesterday] != [timeZone isDaylightSavingTimeForDate:tomorrow])
	{
		NSDate* nextDaylightSavingsTransition = [timeZone nextDaylightSavingTimeTransition];
		
        // If so, return a day at least 2 days beyond the transition
		if ([nextDaylightSavingsTransition timeIntervalSinceDate:now] < SEC_PER_DAY*2)
			return [DosecastUtil addDaysToDate:now numDays:-4];
		else
			return [DosecastUtil addDaysToDate:now numDays:4];
	}
	else
		return now;
}

// Returns the current time on a day in which no daylight savings boundary exists
+ (NSDate*)getCurrentTimeOnNonDaylightSavingsBoundaryDay
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDate* now = [NSDate date];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
						 NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;

	NSDate* nonDaylightSavingsBoundaryDay = [DosecastUtil getNonDaylightSavingsBoundaryDay];
	NSDateComponents* nonDaylightSavingsBoundaryDayComponents = [cal components:unitFlags fromDate:nonDaylightSavingsBoundaryDay];
	NSDateComponents* nowComponents = [cal components:unitFlags fromDate:now];
	[nonDaylightSavingsBoundaryDayComponents setHour:[nowComponents hour]];
	[nonDaylightSavingsBoundaryDayComponents setMinute:[nowComponents minute]];
	[nonDaylightSavingsBoundaryDayComponents setSecond:[nowComponents second]];
	return [cal dateFromComponents:nonDaylightSavingsBoundaryDayComponents];
}

// Returns a device token as a string
+ (NSString*)getDeviceTokenAsString:(NSData*)devToken
{
	NSMutableString* encodedDevToken = nil;
	if (devToken != nil)
	{
		// Encode device token in a string
		int len = (int)[devToken length];
		if (len > 0)
		{
			unsigned char *buffer = (unsigned char *) malloc(sizeof(unsigned char) * len); 
			[devToken getBytes:buffer length:len];
			encodedDevToken = [[NSMutableString alloc] initWithCapacity:len*2+5];
            [encodedDevToken appendString:@"APNS:"];
			for(int i = 0; i < len; i++)
			{
				[encodedDevToken appendFormat:@"%02X", buffer[i]];
			}
			free(buffer);
		}
	}
	
	return encodedDevToken;
}

+ (NSDate*) get24hrTimeAsDate:(int)time
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

	NSMutableString* timeNumStr = [NSMutableString stringWithFormat:@"%d", time];
	while ([timeNumStr length] < 4)
		[timeNumStr insertString:@"0" atIndex:0];
	
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
						 NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;

	NSDateComponents* timeComponents = [cal components:unitFlags fromDate:[DosecastUtil getNonDaylightSavingsBoundaryDay]];
	[timeComponents setHour:[[timeNumStr substringToIndex:2] intValue]];
	[timeComponents setMinute:[[timeNumStr substringFromIndex:2] intValue]];
	[timeComponents setSecond:0];
	return [cal dateFromComponents:timeComponents];
}

+ (int) getDateAs24hrTime:(NSDate*)date
{
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
						 NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents* timeComponents = [cal components:unitFlags fromDate:date];
	NSMutableString* timeNumStr = [NSMutableString stringWithFormat:@"%d%02d", (int)[timeComponents hour], (int)[timeComponents minute]];
	return [timeNumStr intValue];	
}

// Returns midnight on the given day
+ (NSDate*)getMidnightOnDate:(NSDate*)date
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
                         NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	
	// Get the components for the date and force the time to midnight
	NSDateComponents* dateComponents = [cal components:unitFlags fromDate:date];
	[dateComponents setHour:0];
	[dateComponents setMinute:0];
	[dateComponents setSecond:0];
	
	return [cal dateFromComponents:dateComponents];	
}

// Adds the given number of days to the given date
+ (NSDate*)addDaysToDate:(NSDate*)date numDays:(int)numDays
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
    [offsetComponents setDay:numDays];
    return [cal dateByAddingComponents:offsetComponents toDate:date options:0];
}

// Removes the seconds from the given date
+ (NSDate*)removeSecondsFromDate:(NSDate*)date
{
    if (!date)
        return nil;
    
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
    NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    
    // Get the components for the date and force the time to midnight
    NSDateComponents* dateComponents = [cal components:unitFlags fromDate:date];
    [dateComponents setSecond:0];
    
    return [cal dateFromComponents:dateComponents];
}

// Adds the given number of months to the given date
+ (NSDate*)addMonthsToDate:(NSDate*)date numMonths:(int)numMonths
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
    [offsetComponents setMonth:numMonths];
    return [cal dateByAddingComponents:offsetComponents toDate:date options:0];
}

// Returns the time of the last second on the given day
+ (NSDate*)getLastSecondOnDate:(NSDate*)date
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
    NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	
	// Get the components for the date and force the time to midnight
	NSDateComponents* dateComponents = [cal components:unitFlags fromDate:date];
	[dateComponents setHour:23];
	[dateComponents setMinute:59];
	[dateComponents setSecond:59];
	
	return [cal dateFromComponents:dateComponents];	    
}

// Gets path to local file
+ (NSString *)getPathToLocalFile:(NSString*)filename
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:filename];	
}

// Returns a new NSDate object that is offset by the given time interval
+ (NSDate*)addTimeIntervalToDate:(NSDate*)date timeInterval:(NSTimeInterval)seconds
{
    return [date dateByAddingTimeInterval:seconds];
}

// Returns whether the singular form of a noun should be used for the given integer. If NO, then the plural form should be used.
+ (BOOL) shouldUseSingularForInteger:(int)i
{
    // In English and German, the singular form of a noun should be used with 1. In French, the singular form of a noun should be used with either 0 or 1.
    NSString* localeLanguage = [DosecastUtil getLanguageCode];
    if ([localeLanguage caseInsensitiveCompare:@"fr"] == NSOrderedSame)
        return (i == 0 || i == 1);
    else
        return (i == 1);
}

// Returns whether the singular form of a noun should be used for the given float. If NO, then the plural form should be used.
+ (BOOL) shouldUseSingularForFloat:(float)f
{
    const float epsilon = 0.0001;

    // In English and German, the singular form of a noun should be used with 1. In French, the singular form of a noun should be used with either 0 or 1.
    NSString* localeLanguage = [DosecastUtil getLanguageCode];
    if ([localeLanguage caseInsensitiveCompare:@"fr"] == NSOrderedSame)
    {
        return ((f >= 1.0-epsilon && f <= 1.0+epsilon) ||
                (f >= -epsilon && f <= epsilon));
    }
    else
        return (f >= 1.0-epsilon && f <= 1.0+epsilon);    
}

@end
