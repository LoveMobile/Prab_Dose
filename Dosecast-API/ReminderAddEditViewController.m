//
//  ReminderAddEditViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/22/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ReminderAddEditViewController.h"
#import "IntervalPeriodViewController.h"
#import "DateTimePickerViewController.h"
#import "TSQMonthPickerViewController.h"
#import "Drug.h"
#import "ScheduleRepeatPeriodViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "DoseLimitViewController.h"
#import "ChecklistViewController.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int WEEKDAY_LABEL_HEIGHT = 21;
static const int WEEKDAY_LABEL_MARGIN = 11;
static const int MAX_REMINDER_SCHEDULE_TIMES = 8;
static double SEC_PER_DAY = 60*60*24;

typedef enum {
	ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug   = 0,
	ReminderAddEditViewControllerScheduledReminderSectionsFrequency  = 1,
	ReminderAddEditViewControllerScheduledReminderSectionsWeekdays   = 2,
    ReminderAddEditViewControllerScheduledReminderSectionsStartDate  = 3,
    ReminderAddEditViewControllerScheduledReminderSectionsEndDate    = 4,
    ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay  = 5
} ReminderAddEditViewControllerScheduledReminderSections;

typedef enum {
	ReminderAddEditViewControllerScheduledFrequencyRowsDaily   = 0,
	ReminderAddEditViewControllerScheduledFrequencyRowsWeekly  = 1,
    ReminderAddEditViewControllerScheduledFrequencyRowsMonthly = 2,
    ReminderAddEditViewControllerScheduledFrequencyRowsCustom  = 3
} ReminderAddEditViewControllerScheduledFrequencyRows;

typedef enum {
	ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug   = 0,
	ReminderAddEditViewControllerIntervalReminderSectionsInterval   = 1,
	ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit  = 2,
    ReminderAddEditViewControllerIntervalReminderSectionsStartDate  = 3,
    ReminderAddEditViewControllerIntervalReminderSectionsEndDate    = 4
} ReminderAddEditViewControllerIntervalReminderSections;

typedef enum {
	ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug   = 0,
	ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit  = 1,
    ReminderAddEditViewControllerAsNeededReminderSectionsStartDate  = 2,
    ReminderAddEditViewControllerAsNeededReminderSectionsEndDate    = 3
} ReminderAddEditViewControllerAsNeededReminderSections;

@implementation ReminderAddEditViewController

@synthesize tableView;
@synthesize intervalCheckboxCell;
@synthesize scheduleCheckboxCell;
@synthesize asNeededCheckboxCell;
@synthesize intervalCell;
@synthesize addTimeCell;
@synthesize timeCell;
@synthesize dailyCheckboxCell;
@synthesize weeklyCheckboxCell;
@synthesize monthlyCheckboxCell;
@synthesize customPeriodCheckboxCell;
@synthesize treatmentStartsCell;
@synthesize treatmentEndsCell;
@synthesize doseLimitCell;
@synthesize weekdayCell;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil drugId:nil drugReminder:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			   drugId:(NSString*)d
		 drugReminder:(DrugReminder*)reminder
			 delegate:(NSObject<ReminderAddEditViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		drugId = d;
		controllerDelegate = delegate;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

		if (!reminder)
			reminder = [[ScheduledDrugReminder alloc] init];
						
		if ([reminder isKindOfClass:[IntervalDrugReminder class]])
		{
			intervalReminder = [reminder mutableCopy];
			currReminder = intervalReminder;
			scheduledReminder = [[ScheduledDrugReminder alloc] init];
			scheduledReminder.treatmentEndDate = intervalReminder.treatmentEndDate;
			scheduledReminder.treatmentStartDate = intervalReminder.treatmentStartDate;
            scheduledReminder.remindersEnabled = intervalReminder.remindersEnabled;
            scheduledReminder.secondaryRemindersEnabled = intervalReminder.secondaryRemindersEnabled;
            scheduledReminder.archived = intervalReminder.archived;
			asNeededReminder = [[AsNeededDrugReminder alloc] init];
			asNeededReminder.treatmentEndDate = intervalReminder.treatmentEndDate;
			asNeededReminder.treatmentStartDate = intervalReminder.treatmentStartDate;
            asNeededReminder.limitType = (AsNeededDrugReminderDrugLimitType)intervalReminder.limitType;
            asNeededReminder.maxNumDailyDoses = intervalReminder.maxNumDailyDoses;
            asNeededReminder.remindersEnabled = intervalReminder.remindersEnabled;
            asNeededReminder.secondaryRemindersEnabled = intervalReminder.secondaryRemindersEnabled;
            asNeededReminder.archived = intervalReminder.archived;
		}
		else if ([reminder isKindOfClass:[ScheduledDrugReminder class]])
		{
			scheduledReminder = [reminder mutableCopy];
			currReminder = scheduledReminder;
			intervalReminder = [[IntervalDrugReminder alloc] init];
			intervalReminder.interval = DEFAULT_REMINDER_INTERVAL_MINUTES*60;
			intervalReminder.treatmentEndDate = scheduledReminder.treatmentEndDate;
			intervalReminder.treatmentStartDate = scheduledReminder.treatmentStartDate;
            intervalReminder.remindersEnabled = scheduledReminder.remindersEnabled;
            intervalReminder.secondaryRemindersEnabled = scheduledReminder.secondaryRemindersEnabled;
            intervalReminder.archived = scheduledReminder.archived;
			asNeededReminder = [[AsNeededDrugReminder alloc] init];
			asNeededReminder.treatmentEndDate = scheduledReminder.treatmentEndDate;
			asNeededReminder.treatmentStartDate = scheduledReminder.treatmentStartDate;
            asNeededReminder.remindersEnabled = scheduledReminder.remindersEnabled;
            asNeededReminder.secondaryRemindersEnabled = scheduledReminder.secondaryRemindersEnabled;
            asNeededReminder.archived = scheduledReminder.archived;
		}
		else // AsNeededDrugReminder
		{
			asNeededReminder = [reminder mutableCopy];
			currReminder = asNeededReminder;
			intervalReminder = [[IntervalDrugReminder alloc] init];
			intervalReminder.interval = DEFAULT_REMINDER_INTERVAL_MINUTES*60;
			intervalReminder.treatmentEndDate = asNeededReminder.treatmentEndDate;
			intervalReminder.treatmentStartDate = asNeededReminder.treatmentStartDate;
            intervalReminder.limitType = (IntervalDrugReminderDrugLimitType)asNeededReminder.limitType;
            intervalReminder.maxNumDailyDoses = asNeededReminder.maxNumDailyDoses;
            intervalReminder.remindersEnabled = asNeededReminder.remindersEnabled;
            intervalReminder.secondaryRemindersEnabled = asNeededReminder.secondaryRemindersEnabled;
            intervalReminder.archived = asNeededReminder.archived;
			scheduledReminder = [[ScheduledDrugReminder alloc] init];
			scheduledReminder.treatmentEndDate = asNeededReminder.treatmentEndDate;
			scheduledReminder.treatmentStartDate = asNeededReminder.treatmentStartDate;
            scheduledReminder.remindersEnabled = asNeededReminder.remindersEnabled;
            scheduledReminder.secondaryRemindersEnabled = asNeededReminder.secondaryRemindersEnabled;
            scheduledReminder.archived = asNeededReminder.archived;
		}
        
        scheduledFrequencyRows = [[NSMutableArray alloc] init];
        intervalReminderSections = [[NSMutableArray alloc] init];
        asNeededReminderSections = [[NSMutableArray alloc] init];
        scheduledReminderSections = [[NSMutableArray alloc] init];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	

    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	
	
	[self.tableView setEditing:YES animated:NO];
	self.tableView.allowsSelectionDuringEditing = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}


- (IBAction)handleDone:(id)sender
{
	if ([controllerDelegate respondsToSelector:@selector(handleSetReminder:)])
	{
		[controllerDelegate handleSetReminder:currReminder];
	}					
	[self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleCancel:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];
}

- (int)getMaxReminderScheduleTimes
{
    return MAX_REMINDER_SCHEDULE_TIMES;
}

- (void) handleUpdateTreatmentStartDate
{
    
    NSDate* newStartDate = [DosecastUtil getMidnightOnDate:currReminder.treatmentStartDate];
    
    // Copy the new start date into all reminder objects so the user doesn't have to reset it if switching (and this
    // way we don't have to update the start date cell
    scheduledReminder.treatmentStartDate = newStartDate;
    intervalReminder.treatmentStartDate = newStartDate;
    asNeededReminder.treatmentStartDate = newStartDate;
}

- (BOOL)handleSetDateTimeValue:(NSDate*)dateTimeVal forNibNamed:(NSString*)nibName identifier:(int)uniqueID
{	
	BOOL success = YES;

	if ([nibName caseInsensitiveCompare:@"TimeTableViewCell"] == NSOrderedSame)
	{
		int timeVal = [DosecastUtil getDateAs24hrTime:dateTimeVal];
		int numTimes = (int)[scheduledReminder.reminderTimes count];

		// Compare the given dateTime with all others we have and look for dupes
		BOOL isDup = NO;
		for (int i = 0; i < numTimes && isDup == NO; i++)
		{
			if (i != uniqueID)
			{
				NSNumber* thisTimeVal = [scheduledReminder.reminderTimes objectAtIndex:i];
				isDup = (timeVal == [thisTimeVal intValue]);
			}
		}	
		
		if (isDup)
		{
			DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorReminderTimeInvalidTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Invalid Time", @"The title of the alert appearing when an invalid reminder time was entered"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorReminderTimeInvalidMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"You have already created a reminder at this time. Please pick another time.", @"The message of the alert appearing when an invalid reminder time was entered"])];
			[alert showInViewController:self];
            success = NO;
		}
		else
		{
            BOOL weekdayCellVisible = (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly);
            int timeOfDaySectionNum = 4;
            if (weekdayCellVisible)
                timeOfDaySectionNum = 5;

            [self.tableView beginUpdates];
            
            // If we just added the last time, remove the add-time row
            if (uniqueID == numTimes && numTimes == [self getMaxReminderScheduleTimes]-1)
            {
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:uniqueID inSection:timeOfDaySectionNum]]
                                      withRowAnimation:UITableViewRowAnimationLeft];
            }
            
            // Delete a row we just edited - so that we can insert a new one at the right place next
            if (uniqueID < numTimes)
            {
                [scheduledReminder.reminderTimes removeObjectAtIndex:uniqueID];
                numTimes = numTimes - 1;
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:uniqueID inSection:timeOfDaySectionNum]]
                                      withRowAnimation:UITableViewRowAnimationLeft];
            }
            
            // Now insert a new time at the right place (in order)
            int insertIndex = -1;
            for (int i = 0; i < numTimes && insertIndex < 0; i++)
            {
                NSNumber* thisTimeVal = [scheduledReminder.reminderTimes objectAtIndex:i];
                if (timeVal < [thisTimeVal intValue])
                    insertIndex = i;
            }
            if (insertIndex < 0)
                insertIndex = numTimes;
            [scheduledReminder.reminderTimes insertObject:[NSNumber numberWithInt:timeVal] atIndex:insertIndex];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertIndex inSection:timeOfDaySectionNum]]
                                  withRowAnimation:UITableViewRowAnimationRight];	
            [self.tableView endUpdates];
                        
            // Update the treatment start date, if necessary, from the change of reminder times
            [self handleUpdateTreatmentStartDate];
		}
	}
		
	return success;
}

- (BOOL)handleSetDateValue:(NSDate*)dateVal uniqueIdentifier:(int)Id
{
    BOOL success = YES;
    
    if (Id == 0) // treatment starts date
    {
        if (currReminder.treatmentEndDate && [currReminder.treatmentEndDate timeIntervalSinceDate:dateVal] < 0)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditStartDateTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Set Start Date", @"The title of the alert appearing when the start date is disallowed on the Drug Edit view"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditStartDateMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The start date cannot occur after the end date. Please select an earlier start date.", @"The message in the alert appearing when the start date is disallowed on the Drug Edit view"])];
            [alert showInViewController:self];
            success = NO;
        }
        else
        {
            currReminder.treatmentStartDate = dateVal;
            
            [self handleUpdateTreatmentStartDate];
            
            [tableView reloadData];
        }
    }
    else if (Id == 1) // treatment ends date
    {
        NSDate* endDate = currReminder.treatmentEndDate;
        if (!dateVal)
            endDate = nil;
        else
        {
            // Get the components for the treatment end date and force the time to the last second
            NSDate* midnightEndDate = [DosecastUtil getLastSecondOnDate:dateVal];
            
            // Calculate the total notifications used if the end date is set
            currReminder.treatmentEndDate = midnightEndDate;
            currReminder.treatmentEndDate = endDate;
            
            if ([midnightEndDate timeIntervalSinceDate:currReminder.treatmentStartDate] < 0)
            {
                DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditEndDateTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Set End Date", @"The title of the alert appearing when the end date is disallowed on the Drug Edit view"])
                                                                                                   message:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditEndDateMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The end date cannot occur before the start date. Please select a later end date or 'never'.", @"The message in the alert appearing when the end date is disallowed on the Drug Edit view"])];
                [alert showInViewController:self];
                success = NO;
            }
            else
                endDate = midnightEndDate;
        }
        
        // Copy the new end date into all reminder objects so the user doesn't have to reset it if switching (and this
        // way we don't have to update the end date cell
        scheduledReminder.treatmentEndDate = endDate;
        intervalReminder.treatmentEndDate = endDate;
        asNeededReminder.treatmentEndDate = endDate;
        
        if (success)
        {
            // Update the treatment start date, if necessary, from the change of reminder times
            [self handleUpdateTreatmentStartDate];
            
            [tableView reloadData];
        }
    }
    
    return success;
}

- (void)updateIntervalCellLabel:(int)minutes
{
	// Update the label
	UILabel* intervalLabel = (UILabel*)[intervalCell viewWithTag:1];
	intervalLabel.text = [IntervalDrugReminder intervalDescription:minutes];
}

- (void)handleSetIntervalPeriod:(int)minutes
{
    BOOL wasIntervalLessThan1Day = (intervalReminder.interval < SEC_PER_DAY);
    
	intervalReminder.interval = minutes*60;
	[self updateIntervalCellLabel:minutes];
    
    // Refresh the dose limit data from the as needed reminder, since changing the interval could change dose limit options
    intervalReminder.limitType = (IntervalDrugReminderDrugLimitType)asNeededReminder.limitType;
    intervalReminder.maxNumDailyDoses = asNeededReminder.maxNumDailyDoses;

    BOOL isIntervalLessThan1Day = (intervalReminder.interval < SEC_PER_DAY);

    // Show/hide the dose limit section
    if (wasIntervalLessThan1Day != isIntervalLessThan1Day)
    {
        if (isIntervalLessThan1Day)
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationRight];
        else // !isIntervalLessThan1Day
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationLeft];
    }
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void) handleScheduledCustomFrequencyPeriodTap
{
    int customFrequencyNum = scheduledReminder.customFrequencyNum;
    if (customFrequencyNum <= 0)
        customFrequencyNum = 30;
    ScheduleRepeatPeriod period = ScheduleRepeatPeriodDays;
    if (scheduledReminder.customFrequencyPeriod != ScheduledDrugFrequencyCustomPeriodNone)
        period = (ScheduleRepeatPeriod) scheduledReminder.customFrequencyPeriod;
    
    ScheduleRepeatPeriodViewController* scheduleRepeatPeriodController = [[ScheduleRepeatPeriodViewController alloc]
                                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ScheduleRepeatPeriodViewController"]
                                                                          bundle:[DosecastUtil getResourceBundle]
                                                                          initialScheduleRepeatPeriodNum:customFrequencyNum
                                                                          scheduleRepeatPeriod:period
                                                                          identifier:0
                                                                          viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequency", @"Dosecast", [DosecastUtil getResourceBundle], @"Frequency", @"The Frequency label for scheduled drugs in the Drug Edit view"])
                                                                          cellHeader:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequency", @"Dosecast", [DosecastUtil getResourceBundle], @"Frequency", @"The Frequency label for scheduled drugs in the Drug Edit view"])
                                                                          nibName:@"ScheduleRepeatPeriodTableViewCell"
                                                                          delegate:self];
    [self.navigationController pushViewController:scheduleRepeatPeriodController animated:YES];
}
	
// Callback for scheduleRepeatPeriodDays value
// Returns whether the new value is accepted.
- (BOOL)handleSetScheduleRepeatPeriodValue:(int)scheduleRepeatPeriodNum
                      scheduleRepeatPeriod:(int)scheduleRepeatPeriod
				               forNibNamed:(NSString*)nibName
					            identifier:(int)uniqueID // a unique identifier for the current picker
{
    scheduledReminder.frequency = ScheduledDrugFrequencyCustom;
    scheduledReminder.customFrequencyPeriod = (ScheduledDrugFrequencyCustomPeriod)scheduleRepeatPeriod;
    scheduledReminder.customFrequencyNum = scheduleRepeatPeriodNum;
        
    [tableView reloadData];
    
    return YES;
}

- (void)handleSetDoseLimit:(int)limitType // for enum representing none, per day, per 24 hrs
               maxNumDoses:(int)maxNumDoses // -1 if none
{
    // Copy the new dose limit into all reminder objects so the user doesn't have to reset it if switching (and this
    // way we don't have to update the dose limit cell)

    asNeededReminder.limitType = (AsNeededDrugReminderDrugLimitType)limitType;
    asNeededReminder.maxNumDailyDoses = maxNumDoses;
    
    intervalReminder.limitType = (IntervalDrugReminderDrugLimitType)limitType;
    intervalReminder.maxNumDailyDoses = maxNumDoses;        
        
    // Update dose limit section
    if (currReminder == asNeededReminder)
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    else if (currReminder == intervalReminder)
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
}

// Delegate for weekday checklist
- (BOOL)handleDoneCheckingItemsInList:(NSArray*)checkedItems identifier:(NSString*)Id subIdentifier:(NSString*)subId
{    
    BOOL result = YES;
    
    // Create a new array of checked items by adding 1 to each. This is because weekdays are 1-based, but the incoming indexes are 0-based.
    NSMutableArray* checkedWeekdayArray = [[NSMutableArray alloc] init];
    for (NSNumber* index in checkedItems)
    {
        [checkedWeekdayArray addObject:[NSNumber numberWithInt:([index intValue]+1)]];
    }

    scheduledReminder.weekdays = checkedWeekdayArray;
            
    [tableView reloadData];
    
    return result;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [scheduledReminderSections removeAllObjects];
    [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug]];
    [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsFrequency]];
    if (currReminder == scheduledReminder && scheduledReminder.frequency == ScheduledDrugFrequencyWeekly)
        [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsWeekdays]];
    [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsStartDate]];
    [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsEndDate]];
    [scheduledReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay]];

    [scheduledFrequencyRows removeAllObjects];
    [scheduledFrequencyRows addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledFrequencyRowsDaily]];
    [scheduledFrequencyRows addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledFrequencyRowsWeekly]];
    [scheduledFrequencyRows addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledFrequencyRowsMonthly]];
    [scheduledFrequencyRows addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerScheduledFrequencyRowsCustom]];
    
    [intervalReminderSections removeAllObjects];
    [intervalReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug]];
    [intervalReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerIntervalReminderSectionsInterval]];
    if (intervalReminder.interval < SEC_PER_DAY)
        [intervalReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit]];
    [intervalReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerIntervalReminderSectionsStartDate]];
    [intervalReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerIntervalReminderSectionsEndDate]];
        
    [asNeededReminderSections removeAllObjects];
    [asNeededReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug]];
    [asNeededReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit]];
    [asNeededReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerAsNeededReminderSectionsStartDate]];
    [asNeededReminderSections addObject:[NSNumber numberWithInt:ReminderAddEditViewControllerAsNeededReminderSectionsEndDate]];

	if (currReminder == asNeededReminder) // AsNeededDrugReminder
		return [asNeededReminderSections count];
	else if (currReminder == intervalReminder) // IntervalDrugReminder
		return [intervalReminderSections count];
	else // ScheduledDrugReminder
		return [scheduledReminderSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (currReminder == asNeededReminder)
    {
        ReminderAddEditViewControllerAsNeededReminderSections asNeededSection = (ReminderAddEditViewControllerAsNeededReminderSections)[[asNeededReminderSections objectAtIndex:section] intValue];

        if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug)
            return 3;
        else if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit)
            return 1;
        else if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsStartDate)
            return 1;
        else // asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsEndDate
            return 1;
    }
    else if (currReminder == intervalReminder)
    {
        ReminderAddEditViewControllerIntervalReminderSections intervalSection = (ReminderAddEditViewControllerIntervalReminderSections)[[intervalReminderSections objectAtIndex:section] intValue];

        if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug)
            return 3;
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsInterval)
            return 1;
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit)
            return 1;
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsStartDate)
            return 1;
        else // intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsEndDate
            return 1;
    }
    else // scheduledReminder
    {
        ReminderAddEditViewControllerScheduledReminderSections scheduledSection = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:section] intValue];

        if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug)
            return 3;
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsFrequency)
            return [scheduledFrequencyRows count];
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsWeekdays)
            return 1;
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsStartDate)
            return 1;
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsEndDate)
            return 1;
        else // scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay
        {
            int numTimes = (int)[scheduledReminder.reminderTimes count];
            int maxNumTimes = [self getMaxReminderScheduleTimes];
            if (numTimes >= maxNumTimes)
                return maxNumTimes;
            else
                return numTimes+1;
        }
    }    
}

- (UITableViewCell *) getScheduledDrugTypeCell
{
    if (currReminder == scheduledReminder) // ScheduledDrugReminder
    {				
        scheduleCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        scheduleCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        scheduleCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        scheduleCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }			
    UILabel* scheduleLabel = (UILabel*)[scheduleCheckboxCell viewWithTag:1];
    scheduleLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduled", @"Dosecast", [DosecastUtil getResourceBundle], @"On a schedule", @"The Take Drug value for scheduled drugs in the Drug Edit view"]);
    return scheduleCheckboxCell;
}

- (UITableViewCell *) getIntervalDrugTypeCell
{
    if (currReminder == intervalReminder) // IntervalDrugReminder
    {
        intervalCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        intervalCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        intervalCheckboxCell.accessoryType = UITableViewCellAccessoryNone;	
        intervalCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;	
    }
    
    DataModel *dataModel = [DataModel getInstance];
    UILabel* intervalCheckboxLabel = (UILabel*)[intervalCheckboxCell viewWithTag:1];
    if (dataModel.globalSettings.bedtimeStart != -1 && dataModel.globalSettings.bedtimeEnd != -1)
        intervalCheckboxLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalBedtime", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals until bedtime", @"The Take Drug value for interval drugs in the Drug Edit view when bedtime is defined"]);
    else
        intervalCheckboxLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugInterval", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals", @"The Take Drug value for interval drugs in the Drug Edit view"]);
    return intervalCheckboxCell;
}

- (UITableViewCell *) getAsNeededDrugTypeCell
{
    if (currReminder == asNeededReminder) // AsNeededDrugReminder
    {				
        asNeededCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        asNeededCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        asNeededCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        asNeededCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }			
    UILabel* asNeededLabel = (UILabel*)[asNeededCheckboxCell viewWithTag:1];
    asNeededLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugAsNeeded", @"Dosecast", [DosecastUtil getResourceBundle], @"As needed", @"The Take Drug value for as-needed drugs in the Drug Edit view"]);
    return asNeededCheckboxCell;			
}

- (UITableViewCell *) getDoseLimitCell
{
    UILabel* label = (UILabel*)[doseLimitCell viewWithTag:1];

    if (currReminder == asNeededReminder)
        label.text = [asNeededReminder getDoseLimitDescription];
    else // intervalReminder
        label.text = [intervalReminder getDoseLimitDescription];
    
    return doseLimitCell;			   
}

- (UITableViewCell *) getStartDateCell
{
    UILabel* treatmentStartsLabel = (UILabel*)[treatmentStartsCell viewWithTag:1];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    treatmentStartsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:currReminder.treatmentStartDate], [dateFormatter stringFromDate:currReminder.treatmentStartDate]];
    return treatmentStartsCell;			   
}

- (UITableViewCell *) getEndDateCell
{
    UILabel* treatmentEndsLabel = (UILabel*)[treatmentEndsCell viewWithTag:1];
    if (currReminder.treatmentEndDate == nil)
        treatmentEndsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
    else
    {
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        treatmentEndsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:currReminder.treatmentEndDate], [dateFormatter stringFromDate:currReminder.treatmentEndDate]];
    }
    return treatmentEndsCell;		
}

- (void) updateScheduledFrequencyCells
{
    // Update checkbox cells
    if (scheduledReminder.frequency == ScheduledDrugFrequencyDaily)
    {
        dailyCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        dailyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        dailyCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        dailyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }

    if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly)
    {
        weeklyCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        weeklyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        weeklyCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        weeklyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }

    if (scheduledReminder.frequency == ScheduledDrugFrequencyMonthly)
    {
        monthlyCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        monthlyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        monthlyCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        monthlyCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }

    if (scheduledReminder.frequency == ScheduledDrugFrequencyCustom)
    {
        customPeriodCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        customPeriodCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        customPeriodCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        customPeriodCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
    }
    
    // Update custom period label
    
    UILabel* customPeriodLabel = (UILabel*)[customPeriodCheckboxCell viewWithTag:1];
    if (scheduledReminder.frequency == ScheduledDrugFrequencyCustom)
    {
        NSString* daysPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
        NSString* daysSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
        NSString* weeksPlural = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"weeks", @"The plural name for week in scheduled drug descriptions"]);
        NSString* weeksSingular = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"week", @"The singular name for week in scheduled drug descriptions"]);
        
        NSString* unitName = nil;
        if (scheduledReminder.customFrequencyPeriod == ScheduleRepeatPeriodDays)
        {
            if ([DosecastUtil shouldUseSingularForInteger:scheduledReminder.customFrequencyNum])
                unitName = daysSingular;
            else
                unitName = daysPlural;
        }
        else // ScheduleRepeatPeriodWeeks
        {
            if ([DosecastUtil shouldUseSingularForInteger:scheduledReminder.customFrequencyNum])
                unitName = weeksSingular;
            else
                unitName = weeksPlural;
        }
        
        customPeriodLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ScheduleRepeatPeriodPhraseDetail", @"Dosecast", [DosecastUtil getResourceBundle], @"Every %d %@", @"The detailed phrase for describing schedule repeat periods for scheduled drugs"]),
                      scheduledReminder.customFrequencyNum, unitName];
    }
    else
    {
        customPeriodLabel.text = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ScheduleRepeatPeriodPhraseGeneric", @"Dosecast", [DosecastUtil getResourceBundle], @"Every X days", @"The generic phrase for describing schedule repeat periods for scheduled drugs"])];
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (currReminder == asNeededReminder)
    {
        ReminderAddEditViewControllerAsNeededReminderSections section = (ReminderAddEditViewControllerAsNeededReminderSections)[[asNeededReminderSections objectAtIndex:indexPath.section] intValue];

    	if (section == ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug)
        {
            if (indexPath.row == 0)
            {
                return [self getScheduledDrugTypeCell];
            }
            else if (indexPath.row == 1)
            {
                return [self getIntervalDrugTypeCell];
            }
            else // indexPath.row == 2
            {
                return [self getAsNeededDrugTypeCell];
            }
        }
    	else if (section == ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit)
        {
            return [self getDoseLimitCell];
        }
    	else if (section == ReminderAddEditViewControllerAsNeededReminderSectionsStartDate)
        {
            return [self getStartDateCell];
        }
        else // section == ReminderAddEditViewControllerAsNeededReminderSectionsEndDate
        {
            return [self getEndDateCell];
        }
    }
    else if (currReminder == intervalReminder)
    {
        ReminderAddEditViewControllerIntervalReminderSections section = (ReminderAddEditViewControllerIntervalReminderSections)[[intervalReminderSections objectAtIndex:indexPath.section] intValue];

    	if (section == ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug)
        {
            if (indexPath.row == 0)
            {
                return [self getScheduledDrugTypeCell];
            }
            else if (indexPath.row == 1)
            {
                return [self getIntervalDrugTypeCell];
            }
            else // indexPath.row == 2
            {
                return [self getAsNeededDrugTypeCell];
            }
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsInterval)
        {
            int numMinutes = intervalReminder.interval/60;
            [self updateIntervalCellLabel:numMinutes];
            
            return intervalCell;
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit)
        {
            return [self getDoseLimitCell];
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsStartDate)
        {
            return [self getStartDateCell];
        }
        else // section == ReminderAddEditViewControllerIntervalReminderSectionsEndDate
        {
            return [self getEndDateCell];
        }
    }
    else // scheduledReminder
    {
        ReminderAddEditViewControllerScheduledReminderSections scheduledSection = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:indexPath.section] intValue];

    	if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug)
        {
            if (indexPath.row == 0)
            {
                return [self getScheduledDrugTypeCell];
            }
            else if (indexPath.row == 1)
            {
                return [self getIntervalDrugTypeCell];
            }
            else // indexPath.row == 2
            {
                return [self getAsNeededDrugTypeCell];
            }
        }
    	else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsFrequency)
        {
            ReminderAddEditViewControllerScheduledFrequencyRows row = (ReminderAddEditViewControllerScheduledFrequencyRows)[[scheduledFrequencyRows objectAtIndex:indexPath.row] intValue];

            if (row == ReminderAddEditViewControllerScheduledFrequencyRowsDaily)
            {
                [self updateScheduledFrequencyCells];
                
                UILabel* label = (UILabel*)[dailyCheckboxCell viewWithTag:1];
                label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyDaily", @"Dosecast", [DosecastUtil getResourceBundle], @"Daily", @"The Frequency value for daily scheduled drugs in the Drug Edit view"]);
                return dailyCheckboxCell;
            }
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsWeekly)
            {                
                [self updateScheduledFrequencyCells];

                UILabel* label = (UILabel*)[weeklyCheckboxCell viewWithTag:1];
                label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeeklyLocal", @"Dosecast", [DosecastUtil getResourceBundle], @"Weekly", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]);
             
                return weeklyCheckboxCell;				
            }
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsMonthly)
            {
                [self updateScheduledFrequencyCells];
                
                UILabel* label = (UILabel*)[monthlyCheckboxCell viewWithTag:1];
                label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyMonthly", @"Dosecast", [DosecastUtil getResourceBundle], @"Monthly", @"The Frequency value for monthly scheduled drugs in the Drug Edit view"]);
                return monthlyCheckboxCell;								
            }
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsCustom)
            {
                [self updateScheduledFrequencyCells];
                               
                return customPeriodCheckboxCell;
            }
            else
                return nil;
        }
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsWeekdays)
        {                                     
            // Set the weekday labels
            int numWeekdays = 0;
            if (scheduledReminder.weekdays)
                numWeekdays = (int)[scheduledReminder.weekdays count];
            
            NSArray* weekdayNames = [dateFormatter weekdaySymbols];
            NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            int firstWeekday = (int)[cal firstWeekday];

            for (int i = 0; i < 7; i++)
            {
                UILabel* weekdayLabel = (UILabel*)[weekdayCell viewWithTag:1+i];
                
                if (i+1 <= numWeekdays)
                {
                    weekdayLabel.hidden = NO;
                    int weekday = [[scheduledReminder.weekdays objectAtIndex:i] intValue];
                    weekdayLabel.text = [weekdayNames objectAtIndex:weekday-firstWeekday];
                }
                else
                    weekdayLabel.hidden = YES;
            }

            return weekdayCell;
        }
    	else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsStartDate)
        {
            return [self getStartDateCell];
        }
    	else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsEndDate)
        {
            return [self getEndDateCell];
        }
    	else // scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay
        {
            if (indexPath.row == [scheduledReminder.reminderTimes count])
            {
                UILabel* label = (UILabel*)[addTimeCell viewWithTag:1];
                label.text = NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditButtonAddTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Time", @"The Add Time button on the Reminder Add Edit view"]);
                return addTimeCell;
            }
            else
            {
                static NSString *MyIdentifier = @"TimeCellIdentifier";
                
                UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
                if (cell == nil) {
                    [[DosecastUtil getResourceBundle] loadNibNamed:@"ScheduleTimeTableViewCell" owner:self options:nil];
                    cell = timeCell;
                    timeCell = nil;
                }
                
                UILabel* timeLabel = (UILabel*)[cell viewWithTag:1];
                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                timeLabel.text = [dateFormatter stringFromDate:[scheduledReminder getReminderTime:(int)indexPath.row]];
                
                return cell;
            }		
        }
    }  
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (currReminder == scheduledReminder)
	{
        ReminderAddEditViewControllerScheduledReminderSections section = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:indexPath.section] intValue];

        if (section == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay)
        {
            if (indexPath.row == [scheduledReminder.reminderTimes count])
                return UITableViewCellEditingStyleInsert;
            else
                return UITableViewCellEditingStyleDelete;
        }
        else
            return UITableViewCellEditingStyleNone;
	}
	else
		return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleInsert)
	{
		NSDate* dateTimeVal = [DosecastUtil getCurrentTimeOnNonDaylightSavingsBoundaryDay];
		DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
																  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  initialDateTimeVal:dateTimeVal
																  mode:DateTimePickerViewControllerModePickTime
                                                                  minuteInterval:5
														    identifier:(int)indexPath.row
															 viewTitle:NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time", @"The title of the Reminder Add Edit view for a particular reminder time"])
															cellHeader:NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminder Time", @"The label text of the Reminder Add Edit view for a particular reminder time"])
														  displayNever:NO
                                                            neverTitle:nil
															   nibName:@"TimeTableViewCell"
															  delegate:self];
		[self.navigationController pushViewController:dateTimePickerController animated:YES];
	}
	else if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        BOOL weekdayCellVisible = (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly);
        int timeOfDaySectionNum = 4;
        if (weekdayCellVisible)
            timeOfDaySectionNum = 5;

		[self.tableView beginUpdates];
		[scheduledReminder.reminderTimes removeObjectAtIndex:indexPath.row];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
							  withRowAnimation:UITableViewRowAnimationLeft];
		
		int numTimes = (int)[scheduledReminder.reminderTimes count];
		// If we just deleted the last time, add a new insert time row
		if (numTimes == [self getMaxReminderScheduleTimes]-1)
		{
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:numTimes inSection:timeOfDaySectionNum]]
								  withRowAnimation:UITableViewRowAnimationRight];	
		}
		[self.tableView endUpdates];
		
		// Update the treatment start date, if necessary, from the change of reminder times
		[self handleUpdateTreatmentStartDate];		
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (currReminder == scheduledReminder)
    {
        ReminderAddEditViewControllerScheduledReminderSections section = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:indexPath.section] intValue];

        if (section == ReminderAddEditViewControllerScheduledReminderSectionsWeekdays)
        {
            int numWeekdays = 1;
            if (scheduledReminder.weekdays)
                numWeekdays = (int)[scheduledReminder.weekdays count];
            return (WEEKDAY_LABEL_HEIGHT*numWeekdays + 2*WEEKDAY_LABEL_MARGIN);
        }
        else
            return 44;
    }
    else
        return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (currReminder == asNeededReminder)
    {
        ReminderAddEditViewControllerAsNeededReminderSections asNeededSection = (ReminderAddEditViewControllerAsNeededReminderSections)[[asNeededReminderSections objectAtIndex:section] intValue];

        if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
        else if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit)
            return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
        else if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsStartDate)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
        else // asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsEndDate
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
    }
    else if (currReminder == intervalReminder)
    {
        ReminderAddEditViewControllerIntervalReminderSections intervalSection = (ReminderAddEditViewControllerIntervalReminderSections)[[intervalReminderSections objectAtIndex:section] intValue];

        if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsInterval)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalPeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval", @"The Interval label for interval drugs in the Drug Edit view"]);
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit)
            return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsStartDate)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);	
        else // intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsEndDate
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
    }
    else // scheduledReminder
    {
        ReminderAddEditViewControllerScheduledReminderSections scheduledSection = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:section] intValue];

        if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsFrequency)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequency", @"Dosecast", [DosecastUtil getResourceBundle], @"Frequency", @"The Frequency label for scheduled drugs in the Drug Edit view"]);
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsWeekdays)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeekdayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Every", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]);
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsStartDate)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsEndDate)
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
        else // scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay
            return NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduleTimes", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Day", @"The Time of Day label for scheduled drugs in the Drug Edit view"]);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (currReminder == asNeededReminder)
    {
        ReminderAddEditViewControllerAsNeededReminderSections asNeededSection = (ReminderAddEditViewControllerAsNeededReminderSections)[[asNeededReminderSections objectAtIndex:section] intValue];

        if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditReminderFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Drugs taken on a schedule will have dose reminders sent at specific times regardless of whether prior doses were taken. Drugs taken at intervals will have dose reminders sent when a fixed period elapses after a prior dose is taken.", @"The reminder footer message appearing at the bottom of the Reminder Add Edit view"]);        
        else if (asNeededSection == ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditDoseLimitFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Tap this option to set a maximum number of doses per day or per 24 hrs.", @"The reminder footer message appearing at the bottom of the Reminder Add Edit view"]);
        else
            return nil;

    }
    else if (currReminder == intervalReminder)
    {
        ReminderAddEditViewControllerIntervalReminderSections intervalSection = (ReminderAddEditViewControllerIntervalReminderSections)[[intervalReminderSections objectAtIndex:section] intValue];

        if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditReminderFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Drugs taken on a schedule will have dose reminders sent at specific times regardless of whether prior doses were taken. Drugs taken at intervals will have dose reminders sent when a fixed period elapses after a prior dose is taken.", @"The reminder footer message appearing at the bottom of the Reminder Add Edit view"]);        
        else if (intervalSection == ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditDoseLimitFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Tap this option to set a maximum number of doses per day or per 24 hrs.", @"The reminder footer message appearing at the bottom of the Reminder Add Edit view"]);
        else
            return nil;
    }
    else // scheduledReminder
    {
        ReminderAddEditViewControllerScheduledReminderSections scheduledSection = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:section] intValue];

        if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditReminderFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Drugs taken on a schedule will have dose reminders sent at specific times regardless of whether prior doses were taken. Drugs taken at intervals will have dose reminders sent when a fixed period elapses after a prior dose is taken.", @"The reminder footer message appearing at the bottom of the Reminder Add Edit view"]);
        else if (scheduledSection == ReminderAddEditViewControllerScheduledReminderSectionsFrequency)
            return NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditScheduledFrequencyFooterLocal", @"Dosecast", [DosecastUtil getResourceBundle], @"To view additional frequency options, tap the last option above.", @"The scheduled frequency footer message appearing at the bottom of the Reminder Add Edit view"]);
        else
            return nil;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[tableView reloadData];
}

- (void) handleSelectDrugTypeSection:(NSIndexPath *)indexPath
{
    BOOL weekdayCellVisible = (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly);

    [self.tableView beginUpdates];
    if (indexPath.row == 0 && currReminder != scheduledReminder) // If user picked scheduled
    {				
        // Toggle the checkmarks
        scheduleCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        scheduleCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
        intervalCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        intervalCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
        asNeededCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        asNeededCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
                                
        if (currReminder == intervalReminder)
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            [deletedSections addIndex:1];
            if (intervalReminder.interval < SEC_PER_DAY)
                [deletedSections addIndex:2];
            [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];

            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            if (weekdayCellVisible)
            {
                [insertSections addIndex:1];
                [insertSections addIndex:2];
                [insertSections addIndex:5];
            }
            else
            {
                [insertSections addIndex:1];
                [insertSections addIndex:4];
            }
            [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
        }
        else // currReminder == asNeededReminder
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            [deletedSections addIndex:1];
            [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
            
            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            if (weekdayCellVisible)
            {
                [insertSections addIndex:1];
                [insertSections addIndex:2];
                [insertSections addIndex:5];
            }
            else
            {
                [insertSections addIndex:1];
                [insertSections addIndex:4];
            }
            [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
        }
        
        currReminder = scheduledReminder;
    }
    else if (indexPath.row == 1 && currReminder != intervalReminder) // If user picked interval
    {				
        // Toggle the checkmarks
        scheduleCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        scheduleCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
        intervalCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        intervalCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
        asNeededCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        asNeededCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
                    
        if (currReminder == scheduledReminder)
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            if (weekdayCellVisible)
            {
                [deletedSections addIndex:1];
                [deletedSections addIndex:2];
                [deletedSections addIndex:5];
            }
            else
            {
                [deletedSections addIndex:1];
                [deletedSections addIndex:4];
            }
            [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];

            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            [insertSections addIndex:1];
            if (intervalReminder.interval < SEC_PER_DAY)
                [insertSections addIndex:2];
            [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];	
        }
        else // currReminder == asNeededReminder
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            if (intervalReminder.interval >= SEC_PER_DAY)
                [deletedSections addIndex:1];
            if ([deletedSections count] > 0)
                [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
            
            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            [insertSections addIndex:1];
            [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
        }
        
        currReminder = intervalReminder;
    }
    else if (indexPath.row == 2 && currReminder != asNeededReminder) // If user picked as needed
    {
        // Toggle the checkmarks
        scheduleCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        scheduleCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
        asNeededCheckboxCell.accessoryType = UITableViewCellAccessoryCheckmark;
        asNeededCheckboxCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
        intervalCheckboxCell.accessoryType = UITableViewCellAccessoryNone;
        intervalCheckboxCell.editingAccessoryType = UITableViewCellAccessoryNone;
                    
        if (currReminder == scheduledReminder)
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            if (weekdayCellVisible)
            {
                [deletedSections addIndex:1];
                [deletedSections addIndex:2];
                [deletedSections addIndex:5];
            }
            else
            {
                [deletedSections addIndex:1];
                [deletedSections addIndex:4];
            }
            [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
            
            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            [insertSections addIndex:1];
            [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
        }
        else // intervalReminder
        {
            // Delete sections
            NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
            [deletedSections addIndex:1];
            [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];

            // Insert sections
            NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
            if (intervalReminder.interval >= SEC_PER_DAY)
                [insertSections addIndex:1];
            if ([insertSections count] > 0)
                [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
        }

        currReminder = asNeededReminder;				
    }
    
    [self.tableView endUpdates];
    
    // Update the treatment start date, if necessary, from the change of reminder type
    [self handleUpdateTreatmentStartDate];
}

- (void) handleSelectStartDateSection
{
    TSQMonthPickerViewController* monthPickerController = [[TSQMonthPickerViewController alloc]
                                                        init:NSLocalizedStringWithDefaultValue(@"ViewDrugEditStartingTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Start Date", @"The Start Date abbreviated title in the Drug Edit view"])
                                                        initialDate:currReminder.treatmentStartDate
                                                        displayNever:NO
                                                        uniqueIdentifier:0
                                                        delegate:self];
    [self.navigationController pushViewController:monthPickerController animated:YES];
}

- (void) handleSelectEndDateSection
{
    // No need to test for the number of local notifications available and disallow this action. Whether an end date is set
    // won't affect the sum of recurring + per-day local notifications, which is what we use to see if we're over the allowed limit.
    NSDate* endDate = currReminder.treatmentEndDate;
    if (!endDate)
        endDate = currReminder.treatmentStartDate;
    TSQMonthPickerViewController* monthPickerController = [[TSQMonthPickerViewController alloc]
                                                        init:NSLocalizedStringWithDefaultValue(@"ViewDrugEditEndingTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"End Date", @"The End Date abbreviated title in the Drug Edit view"])
                                                        initialDate:endDate
                                                        displayNever:YES
                                                        uniqueIdentifier:1
                                                        delegate:self];
    [self.navigationController pushViewController:monthPickerController animated:YES];
}

- (void) handleSelectDoseLimitSection
{
    int limitType = 0;
    int maxNumDailyDoses = 0;
    
    if (currReminder == asNeededReminder)
    {
        limitType = (int)asNeededReminder.limitType;
        maxNumDailyDoses = asNeededReminder.maxNumDailyDoses;
    }
    else // currReminder == intervalReminder
    {
        limitType = (int)intervalReminder.limitType;
        maxNumDailyDoses = intervalReminder.maxNumDailyDoses;        
    }

    DoseLimitViewController* doseLimitController = [[DoseLimitViewController alloc]
                                                    initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DoseLimitViewController"]
                                                    bundle:[DosecastUtil getResourceBundle]
                                                    limitType:limitType
                                                    maxNumDoses:maxNumDailyDoses
                                                    delegate:self];
    [self.navigationController pushViewController:doseLimitController animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

    if (currReminder == asNeededReminder)
    {
        ReminderAddEditViewControllerAsNeededReminderSections section = (ReminderAddEditViewControllerAsNeededReminderSections)[[asNeededReminderSections objectAtIndex:indexPath.section] intValue];

        if (section == ReminderAddEditViewControllerAsNeededReminderSectionsTakeDrug)
        {
            [self handleSelectDrugTypeSection:indexPath];
        }
        else if (section == ReminderAddEditViewControllerAsNeededReminderSectionsDoseLimit)
        {
            [self handleSelectDoseLimitSection];
        }
        else if (section == ReminderAddEditViewControllerAsNeededReminderSectionsStartDate)
        {
            [self handleSelectStartDateSection];
        }
        else if (section == ReminderAddEditViewControllerAsNeededReminderSectionsEndDate)
        {
            [self handleSelectEndDateSection];
        }
    }
    else if (currReminder == intervalReminder)
    {
        ReminderAddEditViewControllerIntervalReminderSections section = (ReminderAddEditViewControllerIntervalReminderSections)[[intervalReminderSections objectAtIndex:indexPath.section] intValue];

        if (section == ReminderAddEditViewControllerIntervalReminderSectionsTakeDrug)
        {		
            [self handleSelectDrugTypeSection:indexPath];
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsInterval)
        {
            float numMinutes = intervalReminder.interval/60;
			IntervalPeriodViewController* intervalController = [[IntervalPeriodViewController alloc]
                                                                initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"IntervalPeriodViewController"]
                                                                bundle:[DosecastUtil getResourceBundle]
                                                                initialMinutes:numMinutes
                                                                delegate:self];
			[self.navigationController pushViewController:intervalController animated:YES];
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsDoseLimit)
        {
            [self handleSelectDoseLimitSection];
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsStartDate)
        {
            [self handleSelectStartDateSection];
        }
        else if (section == ReminderAddEditViewControllerIntervalReminderSectionsEndDate)
        {
            [self handleSelectEndDateSection];
        }
    }
    else // scheduledReminder
    {
        ReminderAddEditViewControllerScheduledReminderSections section = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:indexPath.section] intValue];

        if (section == ReminderAddEditViewControllerScheduledReminderSectionsTakeDrug)
        {
            [self handleSelectDrugTypeSection:indexPath];
        }
        else if (section == ReminderAddEditViewControllerScheduledReminderSectionsFrequency)
        {
            ReminderAddEditViewControllerScheduledFrequencyRows row = (ReminderAddEditViewControllerScheduledFrequencyRows)[[scheduledFrequencyRows objectAtIndex:indexPath.row] intValue];

            ScheduledDrugFrequency newFrequency = scheduledReminder.frequency;
            if (row == ReminderAddEditViewControllerScheduledFrequencyRowsDaily)
                newFrequency = ScheduledDrugFrequencyDaily;
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsWeekly)
                newFrequency = ScheduledDrugFrequencyWeekly;
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsMonthly)
                newFrequency = ScheduledDrugFrequencyMonthly;
            else if (row == ReminderAddEditViewControllerScheduledFrequencyRowsCustom)
                newFrequency = ScheduledDrugFrequencyCustom;
            
            if (newFrequency == ScheduledDrugFrequencyDaily && scheduledReminder.frequency != ScheduledDrugFrequencyDaily)
			{
                ScheduledDrugFrequency origFrequency = scheduledReminder.frequency;
				scheduledReminder.frequency = ScheduledDrugFrequencyDaily;

                [self updateScheduledFrequencyCells];
                
                if (origFrequency == ScheduledDrugFrequencyWeekly)
                {
                    [self.tableView beginUpdates];
                    
                    // Delete sections
                    NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
                    [deletedSections addIndex:2];
                    [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
                    
                    [self.tableView endUpdates];
                }
			}
			else if (newFrequency == ScheduledDrugFrequencyWeekly && scheduledReminder.frequency != ScheduledDrugFrequencyWeekly)
			{
                scheduledReminder.frequency = ScheduledDrugFrequencyWeekly;
                
                [self updateScheduledFrequencyCells];
                
                [self.tableView beginUpdates];
                
                // Insert sections
                NSMutableIndexSet* insertSections = [NSMutableIndexSet indexSet];
                [insertSections addIndex:2];
                [self.tableView insertSections:insertSections withRowAnimation:UITableViewRowAnimationRight];
                
                [self.tableView endUpdates];
			}
			else if (newFrequency == ScheduledDrugFrequencyMonthly && scheduledReminder.frequency != ScheduledDrugFrequencyMonthly)
			{
                ScheduledDrugFrequency origFrequency = scheduledReminder.frequency;

                scheduledReminder.frequency = ScheduledDrugFrequencyMonthly;
                
                [self updateScheduledFrequencyCells];
                
                if (origFrequency == ScheduledDrugFrequencyWeekly)
                {
                    [self.tableView beginUpdates];
                    
                    // Delete sections
                    NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
                    [deletedSections addIndex:2];
                    [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
                    
                    [self.tableView endUpdates];
                }
			}
            else if (newFrequency == ScheduledDrugFrequencyCustom)
            {
                [self handleScheduledCustomFrequencyPeriodTap];
            }
            
            // Update the treatment start date, if necessary, from the change of reminder type
            [self handleUpdateTreatmentStartDate];
        }
        else if (section == ReminderAddEditViewControllerScheduledReminderSectionsWeekdays)
        {
            // Create a new array of checked indexes by subtracting 1 from each weekday. This is because weekdays are 1-based, but the indexes are 0-based.
            NSMutableArray* checkedIndexArray = [[NSMutableArray alloc] init];
            if (scheduledReminder.weekdays)
            {
                for (NSNumber* weekday in scheduledReminder.weekdays)
                {
                    [checkedIndexArray addObject:[NSNumber numberWithInt:([weekday intValue]-1)]];
                }
            }
            
            NSArray* weekdayNames = [dateFormatter weekdaySymbols];
            
            ChecklistViewController* checklistController = [[ChecklistViewController alloc]
                                                            initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ChecklistViewController"]
                                                            bundle:[DosecastUtil getResourceBundle]
                                                            items:weekdayNames
                                                            checkedItems:checkedIndexArray
                                                            viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeeklyLocal", @"Dosecast", [DosecastUtil getResourceBundle], @"Weekly", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"])
                                                            headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeekdayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Every", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"])
                                                            footerText:nil
                                                            allowNone:NO
                                                            identifier:nil
                                                            subIdentifier:nil
                                                            delegate:self];
            
            [self.navigationController pushViewController:checklistController animated:YES];
        }
        else if (section == ReminderAddEditViewControllerScheduledReminderSectionsStartDate)
        {
            [self handleSelectStartDateSection];
        }
        else if (section == ReminderAddEditViewControllerScheduledReminderSectionsEndDate)
        {
            [self handleSelectEndDateSection];
        }
        else if (section == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay)
        {
            BOOL isAddingNewTime = (indexPath.row == [scheduledReminder.reminderTimes count]);
            
            NSDate* dateTimeVal = nil;
            if (isAddingNewTime)
                dateTimeVal = [DosecastUtil getCurrentTimeOnNonDaylightSavingsBoundaryDay];
            else
                dateTimeVal = [scheduledReminder getReminderTime:(int)indexPath.row];
            DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
                                                                      initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                      initialDateTimeVal:dateTimeVal
                                                                      mode:DateTimePickerViewControllerModePickTime
                                                                      minuteInterval:5
                                                                      identifier:(int)indexPath.row
                                                                      viewTitle:NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time", @"The title of the Reminder Add Edit view for a particular reminder time"])
                                                                      cellHeader:NSLocalizedStringWithDefaultValue(@"ViewReminderAddEditTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminder Time", @"The label text of the Reminder Add Edit view for a particular reminder time"])
                                                                      displayNever:NO
                                                                      neverTitle:nil
                                                                      nibName:@"TimeTableViewCell"
                                                                      delegate:self];
            [self.navigationController pushViewController:dateTimePickerController animated:YES];
        }
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    
    if (currReminder == scheduledReminder)
	{
        ReminderAddEditViewControllerScheduledReminderSections section = (ReminderAddEditViewControllerScheduledReminderSections)[[scheduledReminderSections objectAtIndex:indexPath.section] intValue];
        
        if (section == ReminderAddEditViewControllerScheduledReminderSectionsTimeOfDay)
            return YES;
        else
            return NO;
    }
    else
		return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}



@end
