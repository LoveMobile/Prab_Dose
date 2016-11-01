//
//  DateTimePickerViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol DateTimePickerViewControllerDelegate

@required

// Callback for date/time value
// If val is nil, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetDateTimeValue:(NSDate*)dateTimeVal
				   forNibNamed:(NSString*)nibName
					identifier:(int)uniqueID; // a unique identifier for the current picker

@optional

// Callback for when user hits cancel
- (void)handleCancelDateTime:(int)uniqueID;

@end
