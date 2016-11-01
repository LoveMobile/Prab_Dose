//
//  DrugReminderDelegate.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 1/3/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

@protocol DrugReminderDelegate

@required

- (BOOL)allowReminders;
- (BOOL)allowUserActions;
- (NSString*)getDrugId;
- (NSDate*)created;

@end
