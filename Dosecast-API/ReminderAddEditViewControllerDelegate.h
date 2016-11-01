//
//  ReminderAddEditViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 
#import "DosecastCoreTypes.h"

@class DrugReminder;

@protocol ReminderAddEditViewControllerDelegate

@required

- (void)handleSetReminder:(DrugReminder*)reminder;

@end
