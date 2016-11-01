//
//  TSQMonthPickerViewControllerDelegate
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol TSQMonthPickerViewControllerDelegate

@required

// Callback for selected date value
// If val is nil, this corresponds to 'Never'. Returns whether the new value is accepted
- (BOOL)handleSetDateValue:(NSDate*)dateVal uniqueIdentifier:(int)Id;

@end
