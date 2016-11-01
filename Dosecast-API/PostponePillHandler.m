//
//  PostponePillHandler.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "PostponePillHandler.h"
#import "LocalNotificationManager.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "Drug.h"
#import "PostponePillsViewController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int DEFAULT_POSTPONE_DURATION_MIN_1 = 5;
static const int DEFAULT_POSTPONE_DURATION_MIN_2 = 15;
static const int DEFAULT_POSTPONE_DURATION_MIN_3 = 30;
static const int DEFAULT_POSTPONE_DURATION_HOUR_1 = 1;

@implementation PostponePillHandler

- (id)init
{
    return [self init:nil sourceButton:nil delegate:nil];
}

- (id)init:(NSArray*)drugIds // drug IDs of available drugs to postpone
sourceButton:(UIButton*)button
  delegate:(NSObject<PostponePillHandlerDelegate>*)del
{
    if ((self = [super init]))
    {
        delegate = del;
        unpostponedDrugIds = [[NSMutableArray alloc] initWithArray:drugIds];
		postponedDrugIds = [[NSMutableArray alloc] init];
        postponeDurationMin = 0;
        sourceButton = button;
        [self displayPostponePillActions:YES];
    }
	
    return self;
    
}


// Returns the earliest and latest maxPostponeTime in the given drug list
- (void) getEarliestLatestPostponeTimes:(NSDate**)earliestMaxPostponeTime
			   earliestBasePostponeTime:(NSDate**)earliestBasePostponeTime
				  latestMaxPostponeTime:(NSDate**)latestMaxPostponeTime
				 latestBasePostponeTime:(NSDate**)latestBasePostponeTime
{
	*earliestMaxPostponeTime = nil;
	*latestMaxPostponeTime = nil;
	*earliestBasePostponeTime = nil;
	*latestBasePostponeTime = nil;
	for (int i = 0; i < [unpostponedDrugIds count]; i++)
	{
		NSString* drugId = (NSString*)[unpostponedDrugIds objectAtIndex:i];
		Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
		if (d.reminder.maxPostponeTime != nil)
		{
			NSDate* basePostponeTime = [d.reminder getBasePostponeTime];
			if (*earliestMaxPostponeTime == nil ||
				[d.reminder.maxPostponeTime timeIntervalSinceDate:*earliestMaxPostponeTime] < 0)
			{
				*earliestMaxPostponeTime = d.reminder.maxPostponeTime;
			}
			if (*earliestBasePostponeTime == nil ||
				(basePostponeTime != nil &&
                 [basePostponeTime timeIntervalSinceDate:*earliestBasePostponeTime] < 0))
			{
				*earliestBasePostponeTime = basePostponeTime;
			}			
			if (*latestMaxPostponeTime == nil ||
				[d.reminder.maxPostponeTime timeIntervalSinceDate:*latestMaxPostponeTime] > 0)
			{
				*latestMaxPostponeTime = d.reminder.maxPostponeTime;
			}			
			if (*latestBasePostponeTime == nil ||
				(basePostponeTime != nil &&
                 [basePostponeTime timeIntervalSinceDate:*latestBasePostponeTime] > 0))
			{
				*latestBasePostponeTime = basePostponeTime;
			}						
		}
	}
}

// Returns the string label to display for the given number of hours
-(NSString*)postponeStringLabelForHours:(int)numHours
{
	NSString* hourSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"hour", @"The singular name for hour in interval drug descriptions"]);
	NSString* hourPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"hours", @"The plural name for hour in interval drug descriptions"]);
	
	NSString* unit = nil;
	if (![DosecastUtil shouldUseSingularForInteger:numHours])
		unit = hourPlural;
	else
		unit = hourSingular;
	
	return [NSString stringWithFormat:@"%d %@", numHours, unit];	
}

// Returns the string label to display for the given number of minutes
-(NSString*)postponeStringLabelForMinutes:(int)numMins
{
	NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
	NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);
	
	NSString* unit = nil;
	if (![DosecastUtil shouldUseSingularForInteger:numMins])
		unit = minPlural;
	else
		unit = minSingular;
	
	return [NSString stringWithFormat:@"%d %@", numMins, unit];
}

- (void) handleMultiPostponeSelection
{
    UINavigationController* mainNavigationController = [delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    
    // See if any drugs are overdue
    BOOL anyDrugsOverdue = NO;
    for (int i = 0; i < [unpostponedDrugIds count] && !anyDrugsOverdue; i++)
    {
        NSString* drugId = (NSString*)[unpostponedDrugIds objectAtIndex:i];
        Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
        anyDrugsOverdue = (d.reminder.overdueReminder != nil);
    }
    
    // If no drugs are overdue, we will display a special message in the footer of the postpone view
    NSString* footerMessage = nil;
    if (!anyDrugsOverdue)
        footerMessage = NSLocalizedStringWithDefaultValue(@"ViewPostponeDrugWarningFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Note: this postponement will apply to the next dose.", @"The warning appearing at the bottom of the Postpone Drug view when a user tries to postpone an upcoming dose"]);
    
    // Display PostponePillsViewController in new view
    PostponePillsViewController* postponePillsController = [[PostponePillsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PostponePillsViewController"]
                                                                                                         bundle:[DosecastUtil getResourceBundle]
                                                                                                drugsToPostpone:unpostponedDrugIds
                                                                                                  footerMessage:footerMessage
                                                                                                       delegate:self];
    [topNavController pushViewController:postponePillsController animated:YES];
}

- (BOOL)checkPostponePillsAllowed:(int)desiredPostponeDurationMin
			   treatAllDrugsAsOne:(BOOL)treatAllDrugsAsOne
	  allowMultiPostponeSelection:(BOOL)allowMultiPostponeSelection
{
	BOOL allow = YES;
	
	// See if we can handle this postpone
	NSDate* earliestMaxPostponeTime = nil;
	NSDate* latestMaxPostponeTime = nil;
	NSDate* earliestBasePostponeTime = nil;
	NSDate* latestBasePostponeTime = nil;
	[self getEarliestLatestPostponeTimes:&earliestMaxPostponeTime
				earliestBasePostponeTime:&earliestBasePostponeTime
				   latestMaxPostponeTime:&latestMaxPostponeTime
				  latestBasePostponeTime:&latestBasePostponeTime];
	// Find allowable postpone duration, rounded to nearest postpone increment
	BOOL cannotPostponeAtLeastOneDrug = NO;
	int minimumPostponePeriod = [PostponePillHandler minimumPostponePeriodMin];
	if (earliestMaxPostponeTime != nil && earliestBasePostponeTime != nil)
	{
		int allowablePostponeDurationMin = [earliestMaxPostponeTime timeIntervalSinceDate:earliestBasePostponeTime]/60;
		allowablePostponeDurationMin = (allowablePostponeDurationMin / minimumPostponePeriod) * minimumPostponePeriod;
		cannotPostponeAtLeastOneDrug = (allowablePostponeDurationMin <= desiredPostponeDurationMin);		
	}	
	if (cannotPostponeAtLeastOneDrug)
	{
		allow = NO;
		
		if ([unpostponedDrugIds count] == 1)
		{
			int numMinutes = desiredPostponeDurationMin % 60;
			int numHours = desiredPostponeDurationMin / 60;			
			
            NSString* message = nil;
            if (numHours == 0)
                message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug cannot be postponed %@ because the next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone a drug past the limit"]), [self postponeStringLabelForMinutes:numMinutes]];
            else
                message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug cannot be postponed %@ because the next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone a drug past the limit"]), [self postponeStringLabelForHours:numHours]];

            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Postpone Drug", @"The title of the alert appearing when the user tries to postpone a drug past the limit"])
                                                                                       message:message
                                                                                         style:DosecastAlertControllerStyleAlert];
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction* action) {
                                              [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
                                          }]];
            
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];

            [alert showInViewController:topNavController.topViewController];
		}
		else
		{
			// Find allowable postpone duration, rounded to nearest postpone increment
			BOOL cannotPostponeAnyDrugs = NO;
			if (latestMaxPostponeTime != nil && latestBasePostponeTime != nil)
			{
				int allowablePostponeDurationMin = [latestMaxPostponeTime timeIntervalSinceDate:latestBasePostponeTime]/60;
				allowablePostponeDurationMin = (allowablePostponeDurationMin / minimumPostponePeriod) * minimumPostponePeriod;
				cannotPostponeAnyDrugs = (allowablePostponeDurationMin <= desiredPostponeDurationMin);				
			}
			if (cannotPostponeAnyDrugs || treatAllDrugsAsOne)
			{
				int numMinutes = desiredPostponeDurationMin % 60;
				int numHours = desiredPostponeDurationMin / 60;			

                NSString* message = nil;
                if (numHours == 0)
                    message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeMultiDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"These drugs cannot be postponed %@ because a next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone multiple drugs past the limit"]), [self postponeStringLabelForMinutes:numMinutes]];
                else
                    message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeMultiDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"These drugs cannot be postponed %@ because a next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone multiple drugs past the limit"]), [self postponeStringLabelForHours:numHours]];

                DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPostponeMultiDrugLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Postpone Drugs", @"The title of the alert appearing when the user tries to postpone multiple drugs past the limit"])
                                                                                           message:message
                                                                                             style:DosecastAlertControllerStyleAlert];
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                                style:DosecastAlertActionStyleCancel
                                              handler:^(DosecastAlertAction* action) {
                                                  [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
                                              }]];
                
                UINavigationController* mainNavigationController = [delegate getUINavigationController];
                UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
                
                [alert showInViewController:topNavController.topViewController];
			}
			else if (allowMultiPostponeSelection)
			{
                // At least one drug can be postponed...so let the user pick it
                [self handleMultiPostponeSelection];
			}
			else
			{
                [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
			}
		}
	}
	return allow;
}
- (void)handlePostponeMins:(int)numMins
{
    // See if we can handle this postpone
    NSDate* earliestMaxPostponeTime = nil;
    NSDate* latestMaxPostponeTime = nil;
    NSDate* earliestBasePostponeTime = nil;
    NSDate* latestBasePostponeTime = nil;
    [self getEarliestLatestPostponeTimes:&earliestMaxPostponeTime
                earliestBasePostponeTime:&earliestBasePostponeTime
                   latestMaxPostponeTime:&latestMaxPostponeTime
                  latestBasePostponeTime:&latestBasePostponeTime];
    
    BOOL allowPostpone = [self checkPostponePillsAllowed:numMins
                                      treatAllDrugsAsOne:YES
                             allowMultiPostponeSelection:NO];
    if (allowPostpone)
    {
        postponeDurationMin = numMins;
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];
        
        [self handlePostponePill];
    }
}

- (void)displayPostponePillActions:(BOOL)allowMultiPostponeSelection
{
	BOOL allowPostpone = [self checkPostponePillsAllowed:[PostponePillHandler minimumPostponePeriodMin]
									  treatAllDrugsAsOne:NO
							 allowMultiPostponeSelection:allowMultiPostponeSelection];
	if (!allowPostpone)
		return;
	
	UINavigationController* mainNavigationController = [delegate getUINavigationController];
	UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    
	// Construct a new action sheet and use it to confirm the user wants to postpone the pill(s)
    DosecastAlertController* postponeAlertController = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
                                  }]];

    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:[self postponeStringLabelForMinutes:DEFAULT_POSTPONE_DURATION_MIN_1]
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handlePostponeMins:DEFAULT_POSTPONE_DURATION_MIN_1];
                                  }]];

    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:[self postponeStringLabelForMinutes:DEFAULT_POSTPONE_DURATION_MIN_2]
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handlePostponeMins:DEFAULT_POSTPONE_DURATION_MIN_2];
                                  }]];

    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:[self postponeStringLabelForMinutes:DEFAULT_POSTPONE_DURATION_MIN_3]
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handlePostponeMins:DEFAULT_POSTPONE_DURATION_MIN_3];
                                  }]];

    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:[self postponeStringLabelForHours:DEFAULT_POSTPONE_DURATION_HOUR_1]
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handlePostponeMins:DEFAULT_POSTPONE_DURATION_HOUR_1*60];
                                  }]];

    [postponeAlertController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonMore", @"Dosecast", [DosecastUtil getResourceBundle], @"More...", @"The text on the More button in an alert"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handleMultiPostponeSelection];
                                  }]];

    [postponeAlertController showInViewController:topNavController.topViewController sourceView:sourceButton];
}

- (void) handlePostponePill
{
    if ([unpostponedDrugIds count] > 0)
    {
        NSString* drugId = (NSString*)[unpostponedDrugIds objectAtIndex:0];
        
        // Make a postponePill request
        [[LocalNotificationManager getInstance] postponePill:drugId
                                                     seconds:(postponeDurationMin*60)
                                                   respondTo:self
                                                       async:YES];
    }
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
    }
}

- (void)postponePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{	
    if (result)
	{
        if ([unpostponedDrugIds count] > 0)
        {
            // Mark this pill as being postponed
            [postponedDrugIds addObject:[unpostponedDrugIds objectAtIndex:0]];
            [unpostponedDrugIds removeObjectAtIndex:0];
        }
        
        [self handlePostponePill];
	}
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        if ([unpostponedDrugIds count] > 0)
        {
            NSString* drugId = (NSString*)[unpostponedDrugIds objectAtIndex:0];
            Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
            
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugPostponeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Postpone %@ Dose", @"The title of the alert appearing when the user can't postpone a dose because an error occurs"]), d.name]
                                                                                       message:errorMessage
                                                                                         style:DosecastAlertControllerStyleAlert];
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction* action) {
                                              [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
                                          }]];
            
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            
            [alert showInViewController:topNavController.topViewController];
        }
        else
        {
            [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
        }
    }
}

- (void)handlePostponePillsDone:(NSArray*)postponedIDs
{
    [postponedDrugIds addObjectsFromArray:postponedIDs];
    for (NSString* drugId in postponedIDs)
    {
        [unpostponedDrugIds removeObject:drugId];
    }

    [delegate handlePostponePillHandlerDone:postponedDrugIds]; // Return by notifying delegate
}

- (void)handlePostponePillsCancel
{
    [self displayPostponePillActions:NO];
}

// Returns the minimum postpone period in minutes
+ (int) minimumPostponePeriodMin
{
	return DEFAULT_POSTPONE_DURATION_MIN_1;
}

@end
