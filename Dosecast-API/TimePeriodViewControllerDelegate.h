//
//  TimePeriodViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol TimePeriodViewControllerDelegate

@required

// Callback for seconds value
// If value < 0, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetTimePeriodValue:(int)timePeriodSecs
				   forNibNamed:(NSString*)nibName
					identifier:(int)uniqueID; // a unique identifier for the current picker

@optional

// Callback for when user hits cancel
- (void)handleCancelTimePeriod:(int)uniqueID;

@end
