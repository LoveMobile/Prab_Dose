//
//  SkipPillHandler.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "SkipPillHandler.h"
#import "LocalNotificationManager.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "Drug.h"
#import "SkipPillsViewController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

@implementation SkipPillHandler

- (id)init
{
    return [self init:nil displayActions:YES sourceButton:nil delegate:nil];
}

    - (id)init:(NSArray*)drugIds // drug IDs of available drugs to skip
displayActions:(BOOL)actions // whether to show the possible action choices
  sourceButton:(UIButton*)button
      delegate:(NSObject<SkipPillHandlerDelegate>*)del
{
    if ((self = [super init]))
    {
        delegate = del;
        displayActions = actions;

        unskippedDrugIds = [[NSMutableArray alloc] initWithArray:drugIds];
		skippedDrugIds = [[NSMutableArray alloc] init];
        sourceButton = button;
        
        if (displayActions)
            [self displaySkipPillActions];
        else 
        {
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
         
            LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
            
            // Begin a batch update if we haven't already
            if (![localNotificationManager batchUpdatesInProgress])
                [localNotificationManager beginBatchUpdates];

            [self handleSkipPill];
        }
    }
	
    return self;
    
}

- (void) handleSimpleSkipPill
{
    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
    
    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    
    // Begin a batch update if we haven't already
    if (![localNotificationManager batchUpdatesInProgress])
        [localNotificationManager beginBatchUpdates];
    
    [self handleSkipPill];
}

- (void) displaySkipPillActions
{
    DosecastAlertController* skipPillController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [skipPillController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      [delegate handleSkipPillHandlerDone:skippedDrugIds]; // Return by notifying delegate
                                  }]];
    
    if ([unskippedDrugIds count] == 1)
    {
        [skipPillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertSkipDoseConfirmationButtonSkip", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip dose", @"The Skip Dose button on the alert confirming whether the user wants to skip a dose"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleSimpleSkipPill];
                                      }]];
    }
    else {
        
        [skipPillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertSkipMultiDoseConfirmationButtonMultiSkip", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip all doses", @"The Skip Doses button on the alert confirming whether the user wants to skip multiple doses"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          [self handleSimpleSkipPill];
                                      }]];
        
        [skipPillController addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonMore", @"Dosecast", [DosecastUtil getResourceBundle], @"More...", @"The text on the More button in an alert"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction *action) {
                                          UINavigationController* mainNavigationController = [delegate getUINavigationController];
                                          UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
                                          
                                          // Display SkipPillsViewController in new view
                                          SkipPillsViewController* skipPillsController = [[SkipPillsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"SkipPillsViewController"]
                                                                                                                                   bundle:[DosecastUtil getResourceBundle]
                                                                                                                                  drugIds:unskippedDrugIds
                                                                                                                                 delegate:self];
                                          [topNavController pushViewController:skipPillsController animated:YES];
                                      }]];
    }
    
    UINavigationController* mainNavigationController = [delegate getUINavigationController];
    UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    [skipPillController showInViewController:topNavController.topViewController sourceView:sourceButton];
}

- (void) handleSkipPill
{
    if ([unskippedDrugIds count] > 0)
    {
        NSString* drugId = (NSString*)[unskippedDrugIds objectAtIndex:0];
        
        // Make a skipPill request
        [[LocalNotificationManager getInstance] skipPill:drugId
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
        
        [delegate handleSkipPillHandlerDone:skippedDrugIds]; // Return by notifying delegate
    }
}

- (void)skipPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    if (result)
	{
        if ([unskippedDrugIds count] > 0)
        {
            // Mark this pill as being skipped
            [skippedDrugIds addObject:[unskippedDrugIds objectAtIndex:0]];
            [unskippedDrugIds removeObjectAtIndex:0];
        }
        
        [self handleSkipPill];
	}
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        if ([unskippedDrugIds count] > 0)
        {
            NSString* drugId = (NSString*)[unskippedDrugIds objectAtIndex:0];
            Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
            
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugSkipTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Skip %@ Dose", @"The title of the alert appearing when the user can't skip a dose because an error occurs"]), d.name]
                                                                                                    message:errorMessage
                                                                                                      style:DosecastAlertControllerStyleAlert];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction *action) {
                                              [delegate handleSkipPillHandlerDone:skippedDrugIds]; // Return by notifying delegate
                                          }]];
            
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            [alert showInViewController:topNavController.topViewController];
        }
        else
        {
            [delegate handleSkipPillHandlerDone:skippedDrugIds]; // Return by notifying delegate
        }
    }
}

- (void)handleSkipPillsDone:(NSArray*)skippedIDs
{
    [skippedDrugIds addObjectsFromArray:skippedIDs];
    for (NSString* drugId in skippedIDs)
    {
        [unskippedDrugIds removeObject:drugId];
    }

    [delegate handleSkipPillHandlerDone:skippedDrugIds]; // Return by notifying delegate
}

- (void)handleSkipPillsCancel
{
    if (displayActions)
        [self displaySkipPillActions];
    else 
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
     
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];

        [self handleSkipPill];
    }
}

@end
