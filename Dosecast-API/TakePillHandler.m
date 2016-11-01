//
//  TakePillHandler.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "TakePillHandler.h"
#import "DateTimePickerViewController.h"
#import "LocalNotificationManager.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "Drug.h"
#import "TakePillsViewController.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

@implementation TakePillHandler

- (id)init
{
    return [self init:nil sourceButton:nil delegate:nil];
}

- (id)init:(NSArray*)drugIds // drug IDs of available drugs to take
sourceButton:(UIButton*)button
  delegate:(NSObject<TakePillHandlerDelegate>*)del
{
    if ((self = [super init]))
    {
        delegate = del;

        untakenDrugIds = [[NSMutableArray alloc] initWithArray:drugIds];
		takenDrugIds = [[NSMutableArray alloc] init];
		takePillTime = nil;
        sourceButton = button;
        [self displayTakePillActions];
    }
	
    return self;
    
}

- (void) handleTakePillNow
{
    takePillTime = [NSDate date];
    
    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
    
    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    
    // Begin a batch update if we haven't already
    if (![localNotificationManager batchUpdatesInProgress])
        [localNotificationManager beginBatchUpdates];
    
    [self handleTakePill];
}

- (void) handleTookPillEarlier
{
    UINavigationController* mainNavigationController = [delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    
    NSString* viewTitle = nil;
    NSString* cellHeader = nil;
    NSString* nibName = nil;
    if ([untakenDrugIds count] == 1)
    {
        viewTitle = NSLocalizedStringWithDefaultValue(@"ViewDoseTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Dose", @"The title of the Dose Time view"]);
        cellHeader = NSLocalizedStringWithDefaultValue(@"ViewDoseTimeDoseTakenLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose Taken", @"The Dose Taken label of the Dose Time view"]);
        nibName = @"TakePillTimeTableViewCell";
    }
    else {
        viewTitle = NSLocalizedStringWithDefaultValue(@"ViewMultiDoseTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Doses", @"The title of the Multi Dose Time view"]);
        cellHeader = NSLocalizedStringWithDefaultValue(@"ViewMultiDoseTimeDosesTakenLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Doses Taken", @"The Doses Taken label of the Multi Dose Time view"]);
        nibName = @"TakeMultiPillTimeTableViewCell";
    }
    
    
    // Ask user what time the pill was taken
    NSDate* dateTimeVal = [NSDate date];
    DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
                                                              initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                              bundle:[DosecastUtil getResourceBundle]
                                                              initialDateTimeVal:dateTimeVal
                                                              mode:DateTimePickerViewControllerModePickDateTime
                                                              minuteInterval:1
                                                              identifier:0
                                                              viewTitle:viewTitle
                                                              cellHeader:cellHeader
                                                              displayNever:NO
                                                              neverTitle:nil
                                                              nibName:nibName
                                                              delegate:self];
    [topNavController pushViewController:dateTimePickerController animated:YES];
}

- (void) displayTakePillActions
{
    DosecastAlertController* takePillController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];

    [takePillController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      [self handleRefillNotifications]; // See if we need to display any refill notifications before returning
                                  }]];

    if ([untakenDrugIds count] == 1)
    {
        [takePillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseConfirmationButtonTakeNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Take dose now", @"The Take Dose Now button on the alert confirming whether the user wants to take a dose"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleTakePillNow];
                                      }]];

        [takePillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseConfirmationButtonTookAlready", @"Dosecast", [DosecastUtil getResourceBundle], @"I already took this dose", @"The Took Already button on the alert confirming whether the user wants to take a dose"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleTookPillEarlier];
                                      }]];
    }
    else {
        
        [takePillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeMultiDoseConfirmationButtonTakeNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Take all doses now", @"The Take Doses Now button on the alert confirming whether the user wants to take multiple doses"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleTakePillNow];
                                      }]];
        
        [takePillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeMultiDoseConfirmationButtonTookAlready", @"Dosecast", [DosecastUtil getResourceBundle], @"I already took these doses", @"The Took Already button on the alert confirming whether the user wants to take multiple doses"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleTookPillEarlier];
                                      }]];

        [takePillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonMore", @"Dosecast", [DosecastUtil getResourceBundle], @"More...", @"The text on the More button in an alert"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          UINavigationController* mainNavigationController = [delegate getUINavigationController];
                                          UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
                                          
                                          // Display TakePillsViewController in new view
                                          TakePillsViewController* takePillsController = [[TakePillsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TakePillsViewController"]
                                                                                                                                   bundle:[DosecastUtil getResourceBundle]
                                                                                                                                  drugIds:untakenDrugIds
                                                                                                                                 delegate:self];
                                          [topNavController pushViewController:takePillsController animated:YES];
                                      }]];
    }

    UINavigationController* mainNavigationController = [delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    [takePillController showInViewController:topNavController.topViewController sourceView:sourceButton];
}

- (void) handleTakePill
{
    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    
    if ([untakenDrugIds count] > 0)
    {
        NSString* drugId = (NSString*)[untakenDrugIds objectAtIndex:0];
        
        // Make a takePill request
        [localNotificationManager takePill:drugId
                                  doseTime:takePillTime
                                 respondTo:self
                                     async:YES];
    }
    else
    {
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        [self handleRefillNotifications]; // See if we need to display any refill notifications before returning
    }
}

// Callback for date/time value
// If val is nil, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetDateTimeValue:(NSDate*)dateTimeVal
				   forNibNamed:(NSString*)nibName
					identifier:(int)uniqueID // a unique identifier for the current picker
{	
	BOOL isFuture = [dateTimeVal timeIntervalSinceNow] > 0;
	
	if (isFuture)
	{
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Invalid Time", @"The title to display in alert appearing when the user selects an invalid dose time"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a time in the past.", @"The message to display in alert appearing when the user selects an invalid dose time"])];
        UINavigationController* mainNavigationController = [delegate getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        [alert showInViewController:topNavController.topViewController];
	}
	else
	{
		takePillTime = dateTimeVal;
		
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];

        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];

        [self handleTakePill];
	}
	
	return !isFuture;
}

// Callback for when user hits cancel
- (void)handleCancelDateTime:(int)uniqueID
{
    [self displayTakePillActions];
}

- (void)takePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{	
    if (result)
	{
        if ([untakenDrugIds count] > 0)
        {
            // Mark this pill as being taken
            [takenDrugIds addObject:[untakenDrugIds objectAtIndex:0]];
            [untakenDrugIds removeObjectAtIndex:0];
        }
        
        [self handleTakePill];
	}
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        if ([untakenDrugIds count] > 0)
        {
            NSString* drugId = (NSString*)[untakenDrugIds objectAtIndex:0];
            Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
            
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugTakeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Take %@ Dose", @"The title of the alert appearing when the user can't take a dose because an error occurs"]), d.name]
                                                                                       message:errorMessage
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction *action) {
                                              [self handleRefillNotifications]; // See if we need to display any refill notifications before returning
                                          }]];
            
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            [alert showInViewController:topNavController.topViewController];
        }
        else
            [self handleRefillNotifications]; // See if we need to display any refill notifications before returning
    }
}

- (void)handleTakePillsDone:(NSArray*)takenIDs
{
    [takenDrugIds addObjectsFromArray:takenIDs];
    for (NSString* drugId in takenIDs)
    {
        [untakenDrugIds removeObject:drugId];
    }
	[self handleRefillNotifications]; // See if we need to display any refill notifications before returning
}

- (void)handleTakePillsCancel
{
    [self displayTakePillActions];
}

// Called to search for any refill notifications to display
- (void)handleRefillNotifications
{
	// Find the subset of taken drugs which have refill notifications to be displayed, if any
	DataModel* dataModel = [DataModel getInstance];
	NSMutableArray* runningLowDrugIDs = [[NSMutableArray alloc] init];
	NSMutableArray* emptyDrugIDs = [[NSMutableArray alloc] init];
    
	int numDrugsTaken = (int)[takenDrugIds count];
	for (int i = 0; i < numDrugsTaken; i++)
	{
		Drug* d = [dataModel findDrugWithId:[takenDrugIds objectAtIndex:i]];
		// If this drug needs to have a refill notification shown, store whether this is because
		// it is empty or simply running low
		if ([d needsRefillNotification])
		{
			if ([d isEmpty])
				[emptyDrugIDs addObject:d.drugId];				
			else
				[runningLowDrugIDs addObject:d.drugId];			
		}
	}
	
	// Bail if we have no refill notifications to display
	if (![dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] || ([runningLowDrugIDs count] + [emptyDrugIDs count] == 0))
	{
        [delegate handleTakePillHandlerDone:takenDrugIds]; // Return by notifying delegate
		return;
	}
	
	NSMutableString* alertMessage = [NSMutableString stringWithString:@""];
    
	// List the empty drugs
    
	int numEmpty = (int)[emptyDrugIDs count];
	if (numEmpty == 1)
	{
		Drug* d = [dataModel findDrugWithId:[emptyDrugIDs objectAtIndex:0]];
		[alertMessage appendFormat:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillEmptySingleMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your supply of %@ has run out.", @"The message on the refill alert that a single drug's supply has run out"]), d.name];
	}
	else if (numEmpty > 1)
	{
		[alertMessage appendString:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillEmptyMultipleMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your supply of the following drugs has run out:", @"The message on the refill alert that multiple drugs' supply has run out"])];
		[alertMessage appendString:@"\n\n"];
		for (int i = 0; i < numEmpty; i++)
		{
			Drug* d = [dataModel findDrugWithId:[emptyDrugIDs objectAtIndex:i]];
			[alertMessage appendString:d.name];
			if (i < numEmpty-1)
				[alertMessage appendString:@"\n"];
		}
	}
	
	// List the drugs running low
    
	int numRunningLow = (int)[runningLowDrugIDs count];
	if (numRunningLow == 1)
	{
		if ([alertMessage length] > 0)
			[alertMessage appendString:@"\n\n"];
		
		Drug* d = [dataModel findDrugWithId:[runningLowDrugIDs objectAtIndex:0]];
		[alertMessage appendFormat:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillRunningLowSingleMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your supply of %@ is running low.", @"The message on the refill alert that a single drug's supply is running low"]), d.name];
	}
	else if (numRunningLow > 1)
	{
		if ([alertMessage length] > 0)
			[alertMessage appendString:@"\n\n"];
        
		[alertMessage appendString:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillRunningLowMultipleMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your supply of the following drugs is running low:", @"The message on the refill alert that multiple drugs' supply is running low"])];
		[alertMessage appendString:@"\n\n"];
		for (int i = 0; i < numRunningLow; i++)
		{
			Drug* d = [dataModel findDrugWithId:[runningLowDrugIDs objectAtIndex:i]];
			[alertMessage appendString:d.name];
			if (i < numRunningLow-1)
				[alertMessage appendString:@"\n"];
		}
	}
	
    DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The title on the refill alert"])
                                                                               message:alertMessage
                                                                                 style:DosecastAlertControllerStyleAlert];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      [delegate handleTakePillHandlerDone:takenDrugIds]; // Return by notifying delegate
                                  }]];
    
    UINavigationController* mainNavigationController = [delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    [alert showInViewController:topNavController.topViewController];
}

@end
