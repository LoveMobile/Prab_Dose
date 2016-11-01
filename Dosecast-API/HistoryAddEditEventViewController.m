//
//  HistoryAddEditEventViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "HistoryAddEditEventViewController.h"
#import "DataModel.h"
#import "Drug.h"
#import "DosecastUtil.h"
#import "PicklistViewController.h"
#import "DateTimePickerViewController.h"
#import "HistoryManager.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "TimePeriodViewController.h"
#import "GlobalSettings.h"
#import "NumericPickerViewController.h"
#import "DrugDosage.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

// The different UI sections & rows
typedef enum {
	HistoryAddEditEventViewControllerSectionsDrugName        = 0,
	HistoryAddEditEventViewControllerSectionsAction          = 1,
	HistoryAddEditEventViewControllerSectionsPostponePeriod  = 2,
    HistoryAddEditEventViewControllerSectionsEventTime       = 3,
    HistoryAddEditEventViewControllerSectionsScheduledTime   = 4,
    HistoryAddEditEventViewControllerSectionsRefillAmount    = 5
} HistoryAddEditEventViewControllerSections;

static NSString *ActionPicklistId = @"action";
static NSString *DrugNamesPicklistId = @"drugNames";

static const int MAX_POSTPONE_HOURS = 24;
static const int POSTPONE_INCREMENT_MINS = 5;
static const CGFloat LABEL_BASE_HEIGHT = 19.0f;
static const CGFloat CELL_MIN_HEIGHT = 44.0f;
static float epsilon = 0.0001;

@implementation HistoryAddEditEventViewController

@synthesize tableView;
@synthesize drugNameCell;
@synthesize actionCell;
@synthesize eventTimeCell;
@synthesize scheduledTimeCell;
@synthesize postponePeriodCell;
@synthesize refillAmountCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
                          bundle:nibBundleOrNil
                       viewTitle:nil
                          drugId:nil
                 possibleDrugIds:nil
                      actionName:nil
                       eventTime:nil
                   scheduledTime:nil
              postponePeriodSecs:-1
                    refillAmount:0.0f
                        delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            viewTitle:(NSString*)title
               drugId:(NSString*)Id
      possibleDrugIds:(NSArray*)possibleIds
           actionName:(NSString*)action
            eventTime:(NSDate*)event
        scheduledTime:(NSDate*)scheduled
   postponePeriodSecs:(int)postponePeriod
         refillAmount:(float)refAmount
			 delegate:(NSObject<HistoryAddEditEventViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{
        DataModel* dataModel = [DataModel getInstance];
        
		drugId = Id;
        
        // If we weren't given any possible drug IDs, use them all
        if (!possibleIds || [possibleIds count] == 0)
        {
            NSMutableArray* newPossibleIds = [[NSMutableArray alloc] init];
            for (Drug *d in dataModel.drugList)
            {
                if (!d.reminder.archived && !d.reminder.invisible)
                    [newPossibleIds addObject:d.drugId];
            }
            possibleIds = newPossibleIds;
        }
        possibleDrugIds = possibleIds;
        
        // If no drug was specified and there's only one possibility, choose it
        if (!drugId && [possibleDrugIds count] == 1)
        {
            drugId = [possibleDrugIds objectAtIndex:0];
        }
        
        refillAmount = refAmount;
        if (refillAmount < epsilon && drugId)
        {
            Drug* d = [dataModel findDrugWithId:drugId];
            if ([d.dosage isValidValueForRefillQuantity])
                [d.dosage getValueForRefillQuantity:&refillAmount];
        }

        tableViewSections = [[NSMutableArray alloc] init];

        viewTitle = title;
				
		controllerDelegate = del;
        if (!action)
            action = [NSString stringWithString:HistoryManagerTakePillOperationName];
        actionName = action;
        postponePeriodSecs = postponePeriod;
		eventTime = event;
        scheduledTime = scheduled;
		
		self.title = viewTitle;
		
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        self.hidesBottomBarWhenPushed = YES;
	}
    return self;	
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
		
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;		
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void) recalcDynamicCellWidths
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int screenWidth = 0;
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait ||
        self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        screenWidth = screenBounds.size.width;
    }
    else
        screenWidth = screenBounds.size.height;
    drugNameCell.frame = CGRectMake(drugNameCell.frame.origin.x, drugNameCell.frame.origin.y, screenWidth, drugNameCell.frame.size.height);
    [drugNameCell layoutIfNeeded];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
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


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (IBAction)handleDone:(id)sender
{
	if (!drugId || !eventTime ||
        (!scheduledTime && [actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame) ||
        (postponePeriodSecs < 0 && [actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame))
	{
		NSMutableString* message = [NSMutableString stringWithString:@""];
		if (!drugId)
			[message appendString:NSLocalizedStringWithDefaultValue(@"ErrorHistoryAddEditEventNoDrugTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a drug.", @"The message in the alert appearing in the History Add Event view when no drug has been selected"])];
		if (!eventTime)
		{
			if ([message length] > 0)
				[message appendString:@"\n"];
			[message appendString:NSLocalizedStringWithDefaultValue(@"ErrorHistoryAddEditEventNoEventTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select an event time.", @"The message in the alert appearing in the History Add Event view when no event time has been selected"])];
		}
        if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame &&
            postponePeriodSecs < 0)
        {
			if ([message length] > 0)
				[message appendString:@"\n"];
			[message appendString:NSLocalizedStringWithDefaultValue(@"ErrorHistoryAddEditEventNoPostponeDurationTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a postpone duration.", @"The message in the alert appearing in the History Add Event view when no postpone duration has been selected"])];
        }
		if (!scheduledTime && [actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
		{
			if ([message length] > 0)
				[message appendString:@"\n"];
			[message appendString:NSLocalizedStringWithDefaultValue(@"ErrorHistoryAddEditEventNoScheduledTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a scheduled time.", @"The message in the alert appearing in the History Add Event view when no scheduled time has been selected"])];
		}
		
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorHistoryAddEditEventMissingInfoTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Information Required", @"The title of the alert appearing in the History Add Event view when event information is missing"])
                                                                                           message:message];
		[alert showInViewController:self];
	}
	else
	{	
        BOOL allowPop = YES;
		if ([controllerDelegate respondsToSelector:@selector(handleAddEditEventComplete:actionName:postponePeriodSecs:eventTime:scheduledTime:refillAmount:)])
		{
			allowPop = [controllerDelegate handleAddEditEventComplete:drugId
                                                           actionName:actionName
                                                   postponePeriodSecs:postponePeriodSecs
                                                            eventTime:eventTime
                                                        scheduledTime:scheduledTime
                                                         refillAmount:refillAmount];
		}
        if (allowPop)
            [self.navigationController popViewControllerAnimated:YES];
	}
}

- (IBAction)handleCancel:(id)sender
{
    if ([controllerDelegate respondsToSelector:@selector(handleCancelAddEditEvent)])
    {
        [controllerDelegate handleCancelAddEditEvent];
    }
	[self.navigationController popViewControllerAnimated:YES];
}

// Function to compare two drugs by name
NSComparisonResult compareDrugsByName(Drug* d1, Drug* d2, void* context)
{
	return [d1.name compare:d2.name options:NSLiteralSearch];	
}

- (NSArray*) getSortedDrugListByName
{
    DataModel* dataModel = [DataModel getInstance];
	NSMutableArray* sortedDrugList = nil;

    sortedDrugList = [[NSMutableArray alloc] init];
    int numDrugs = (int)[possibleDrugIds count];
    for (int i = 0; i < numDrugs; i++)
    {
        Drug* d = [dataModel findDrugWithId:[possibleDrugIds objectAtIndex:i]];
        [sortedDrugList addObject:d];
    }
    
	[sortedDrugList sortUsingFunction:compareDrugsByName context:NULL];
	return sortedDrugList;
}

- (BOOL)handleDonePickingItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId // Returns whether to allow the controller to be popped
{
	if (item < 0)
		return NO;
	
	// Pick a different drug dosage type
	if ([Id caseInsensitiveCompare:ActionPicklistId] == NSOrderedSame)
	{
		if (item == 0)
		{
			actionName = [NSString stringWithString:HistoryManagerTakePillOperationName];
		}
		else if (item == 1)
		{
			actionName = [NSString stringWithString:HistoryManagerSkipPillOperationName];
		}
		else if (item == 2)
		{
			actionName = [NSString stringWithString:HistoryManagerPostponePillOperationName];
		}
        else if (item == 3)
        {
			actionName = [NSString stringWithString:HistoryManagerMissPillOperationName];
        }
        else if (item == 4)
        {
			actionName = [NSString stringWithString:HistoryManagerRefillOperationName];
        }
        postponePeriodSecs = -1; // Reset postpone period
	}
	else if ([Id caseInsensitiveCompare:DrugNamesPicklistId] == NSOrderedSame)
	{
		NSArray* sortedDrugList = [self getSortedDrugListByName];
		Drug* d = [sortedDrugList objectAtIndex:item];
		drugId = d.drugId;
        
        if (refillAmount < epsilon)
        {
            Drug* d = [[DataModel getInstance] findDrugWithId:drugId];
            if ([d.dosage isValidValueForRefillQuantity])
                [d.dosage getValueForRefillQuantity:&refillAmount];
        }
	}
	
	[tableView reloadData];
	return YES;
}

// Callback for date/time value
// If val is nil, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetDateTimeValue:(NSDate*)dateTimeVal
				   forNibNamed:(NSString*)nibName
					identifier:(int)uniqueID // a unique identifier for the current picker
{
    if (uniqueID == 0) // event time
    {
        BOOL isFuture = [dateTimeVal timeIntervalSinceNow] > 0;
        
        if (isFuture)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Invalid Time", @"The title to display in alert appearing when the user selects an invalid dose time"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a time in the past.", @"The message to display in alert appearing when the user selects an invalid dose time"])];
            [alert showInViewController:self];
        }
        else
        {
            eventTime = [DosecastUtil removeSecondsFromDate:dateTimeVal];
            [tableView reloadData];		
        }
        
        return !isFuture;
    }
    else // scheduled time
    {
        scheduledTime = [DosecastUtil removeSecondsFromDate:dateTimeVal];
                
        [tableView reloadData];
        return YES;
    }
}

// Returns the string label to display for the given number of hours
-(NSString*)timePeriodStringLabelForHours:(int)numHours
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
-(NSString*)timePeriodStringLabelForMinutes:(int)numMins
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

// Callback for seconds value
// If value < 0, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetTimePeriodValue:(int)timePeriodSecs
                     forNibNamed:(NSString*)nibName
                      identifier:(int)uniqueID // a unique identifier for the current picker
{
    postponePeriodSecs = timePeriodSecs;
    [tableView reloadData];
    return YES;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcDynamicCellWidths];
    
    [tableViewSections removeAllObjects];
    [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsDrugName]];
    [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsAction]];
    
    if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
        [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsPostponePeriod]];
    
    [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsEventTime]];

    if ([actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
        [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsRefillAmount]];
    else
        [tableViewSections addObject:[NSNumber numberWithInt:HistoryAddEditEventViewControllerSectionsScheduledTime]];
    
    return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HistoryAddEditEventViewControllerSections section = (HistoryAddEditEventViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (section == HistoryAddEditEventViewControllerSectionsDrugName)
	{
		UILabel* header = (UILabel *)[drugNameCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);
		UILabel* label = (UILabel *)[drugNameCell viewWithTag:2];
		DataModel* dataModel = [DataModel getInstance];
		if (drugId)
		{
			Drug *d = [dataModel findDrugWithId:drugId];
			if (d)
				label.text = d.name;
			else
				label.text = nil;
		}
		else
			label.text = nil;

		if ([possibleDrugIds count] > 1)
		{
            drugNameCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			drugNameCell.selectionStyle = UITableViewCellSelectionStyleGray;
		}
		else
		{
            drugNameCell.accessoryType = UITableViewCellAccessoryNone;
			drugNameCell.selectionStyle = UITableViewCellSelectionStyleNone;            
		}
		return drugNameCell;
	}
	else if (section == HistoryAddEditEventViewControllerSectionsAction)
	{
		UILabel* header = (UILabel *)[actionCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEditEventAction", @"Dosecast", [DosecastUtil getResourceBundle], @"Action", @"The Action label in the History Add Event view"]);
		UILabel* label = (UILabel *)[actionCell viewWithTag:2];
        
        NSString* actionLabel = nil;
        if ([actionName caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
            actionLabel = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Dose", @"The Take Dose button on the dose reminder alert"]);
        else if ([actionName caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
            actionLabel = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Dose", @"The Skip Dose button on the dose reminder alert"]);
        else if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
            actionLabel = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]);
        else if ([actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            actionLabel = NSLocalizedStringWithDefaultValue(@"DrugHistoryMissDoseAction", @"Dosecast", [DosecastUtil getResourceBundle], @"Miss Dose", @"The Miss Dose action label in the drug history"]);
        else if ([actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
            actionLabel = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill", @"The Refill label in the Drug Edit view"]);
        if (actionLabel)
            label.text = [DosecastUtil capitalizeFirstLetterOfString:[actionLabel lowercaseString]];
        else
            label.text = nil;
        
        actionCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        actionCell.selectionStyle = UITableViewCellSelectionStyleGray;			

		return actionCell;
	}	
	else if (section == HistoryAddEditEventViewControllerSectionsPostponePeriod)
	{
		UILabel* header = (UILabel *)[postponePeriodCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEditEventPostponeDuration", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone Duration", @"The Postpone Duration label in the History Add Event view"]);
		UILabel* label = (UILabel *)[postponePeriodCell viewWithTag:2];
        
        if (postponePeriodSecs >= 0)
        {
            int numMinutes = postponePeriodSecs/60;
            int numHours = numMinutes/60;
            int numMinutesLeft = numMinutes%60;
            NSMutableString* periodLabelText = [NSMutableString stringWithString:@""];
            if (numHours > 0)
                [periodLabelText appendString:[self timePeriodStringLabelForHours:numHours]];
            if (numMinutesLeft > 0 || numHours == 0)
            {
                if (numHours > 0)
                    [periodLabelText appendString:@" "];
                [periodLabelText appendString:[self timePeriodStringLabelForMinutes:numMinutesLeft]];
            }
            label.text = periodLabelText;
        }
        else
            label.text = @"";

        postponePeriodCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        postponePeriodCell.selectionStyle = UITableViewCellSelectionStyleGray;
        
		return postponePeriodCell;
	}	
	else if (section == HistoryAddEditEventViewControllerSectionsEventTime)
	{
		UILabel* header = (UILabel *)[eventTimeCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryEventTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Event Time", @"The Event Time label of the Drug History Event Time view"]);
		UILabel* label = (UILabel *)[eventTimeCell viewWithTag:2];
		
		NSMutableString* labelText = nil;
		if (eventTime)
		{
			NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDate* now = [NSDate date];
			unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
			
			// Get the day/month/year for today and for the date given
			NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
			NSDateComponents* dateValComponents = [cal components:unitFlags fromDate:eventTime];
			
			// If given date is today
			if ([todayComponents day] == [dateValComponents day] &&
				[todayComponents month] == [dateValComponents month] &&
				[todayComponents year] == [dateValComponents year])
			{
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerTodayTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Today at %@", @"The text in the main cell of the DateTimePicker view when the date is today"]);
				labelText = [NSMutableString stringWithFormat:dateFormatText, [dateFormatter stringFromDate:eventTime]];
			}
			else
			{
				
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				NSString* dateStr = [dateFormatter stringFromDate:eventTime];
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* timeStr = [dateFormatter stringFromDate:eventTime];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerFutureTime", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ at %@", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
				labelText = [NSMutableString stringWithFormat:dateFormatText, dateStr, timeStr];
			}
		}

		label.text = labelText;
		eventTimeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		return eventTimeCell;		
	}
    else if (section == HistoryAddEditEventViewControllerSectionsScheduledTime)
	{
		UILabel* header = (UILabel *)[scheduledTimeCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryScheduledTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Scheduled Time", @"The Scheduled Time label of the Drug History Event Time view"]);
		UILabel* label = (UILabel *)[scheduledTimeCell viewWithTag:2];
		
		NSMutableString* labelText = nil;
        
        // The schedule time is required for missed doses, optional for all others
        if ([actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] != NSOrderedSame)
            labelText = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditScheduleTimesNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The none value in the Take Drug cell for scheduled reminders of the Drug Edit view"])];

		if (scheduledTime)
		{
			NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDate* now = [NSDate date];
			unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
			
			// Get the day/month/year for today and for the date given
			NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
			NSDateComponents* dateValComponents = [cal components:unitFlags fromDate:scheduledTime];
			
			// If given date is today
			if ([todayComponents day] == [dateValComponents day] &&
				[todayComponents month] == [dateValComponents month] &&
				[todayComponents year] == [dateValComponents year])
			{
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerTodayTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Today at %@", @"The text in the main cell of the DateTimePicker view when the date is today"]);
				labelText = [NSMutableString stringWithFormat:dateFormatText, [dateFormatter stringFromDate:scheduledTime]];
			}
			else
			{
				
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				NSString* dateStr = [dateFormatter stringFromDate:scheduledTime];
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* timeStr = [dateFormatter stringFromDate:scheduledTime];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerFutureTime", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ at %@", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
				labelText = [NSMutableString stringWithFormat:dateFormatText, dateStr, timeStr];
			}
		}
        
		label.text = labelText;
		scheduledTimeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
		return scheduledTimeCell;		
	}
    else if (section == HistoryAddEditEventViewControllerSectionsRefillAmount)
    {
        UILabel* header = (UILabel *)[refillAmountCell viewWithTag:1];
        header.text = NSLocalizedStringWithDefaultValue(@"DrugHistoryRefillAmount", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Amount", @"The Scheduled Time label of the Drug History Event Time view"]);
        UILabel* label = (UILabel *)[refillAmountCell viewWithTag:2];
        label.text = [DrugDosage getDescriptionForQuantity:refillAmount unit:nil numDecimals:2];
        
        return refillAmountCell;
    }
	else
		return nil;
}

- (BOOL)handleSetNumericQuantity:(float)val unit:(NSString*)unit identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
    refillAmount = val;
    [self.tableView reloadData];
    return YES;
}

- (CGFloat) getHeightForCellLabel:(UITableViewCell*)cell tag:(int)tag withString:(NSString*)value
{
    UILabel* label = (UILabel*)[cell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, LABEL_BASE_HEIGHT * (float)label.numberOfLines);
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName: label.font}
                                      context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    if (labelSize.height <= CELL_MIN_HEIGHT)
        return CELL_MIN_HEIGHT;
    else
        return labelSize.height+2.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HistoryAddEditEventViewControllerSections section = (HistoryAddEditEventViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];
    
	if (section == HistoryAddEditEventViewControllerSectionsDrugName)
    {
        DataModel* dataModel = [DataModel getInstance];
        NSString* drugName = nil;
		if (drugId)
		{
			Drug *d = [dataModel findDrugWithId:drugId];
			if (d)
				drugName = d.name;
		}

        return (int)ceilf([self getHeightForCellLabel:drugNameCell tag:2 withString:drugName]);
    }
    else
        return CELL_MIN_HEIGHT;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    HistoryAddEditEventViewControllerSections controllerSection = (HistoryAddEditEventViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == HistoryAddEditEventViewControllerSectionsEventTime)
        return NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryEventTimeDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"The time that the event occurred.", @"The Event Time description of the Drug History Event Time view"]);
    else if (controllerSection == HistoryAddEditEventViewControllerSectionsScheduledTime)
        return NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryScheduledTimeDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"The time that the dose was scheduled to be taken.", @"The Scheduled Time description of the Drug History Event Time view"]);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    DataModel* dataModel = [DataModel getInstance];

    HistoryAddEditEventViewControllerSections section = (HistoryAddEditEventViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (section == HistoryAddEditEventViewControllerSectionsDrugName && [possibleDrugIds count] > 1)
	{
		NSArray* sortedDrugList = [self getSortedDrugListByName];
		NSMutableArray* sortedNames = [[NSMutableArray alloc] init];
		int numDrugs = (int)[sortedDrugList count];
		int selectedItem = -1;
		for (int i = 0; i < numDrugs; i++)
		{
			Drug *d = [sortedDrugList objectAtIndex:i];
			[sortedNames addObject:d.name];
			if (drugId && [drugId caseInsensitiveCompare:d.drugId] == NSOrderedSame)
				selectedItem = i;
		}
		
		PicklistViewController* picklistController = [[PicklistViewController alloc]
													  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
													  bundle:[DosecastUtil getResourceBundle]
													  nonEditableItems:sortedNames
                                                      editableItems:nil
													  selectedItem:selectedItem
                                                      allowEditing:NO
													  viewTitle:viewTitle
													  headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"])
													  footerText:nil
                                                      addItemCellText:nil
                                                      addItemPlaceholderText:nil
													  displayNone:NO
													  identifier:DrugNamesPicklistId
													  subIdentifier:nil
													  delegate:self];
		[self.navigationController pushViewController:picklistController animated:YES];
	}
	else if (section == HistoryAddEditEventViewControllerSectionsAction)
	{
        BOOL allowRefillEvent = [dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities];

		NSMutableArray* options = [[NSMutableArray alloc] init];
		[options addObject:
			[DosecastUtil capitalizeFirstLetterOfString:
			 [[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Dose", @"The Take Dose button on the dose reminder alert"])] lowercaseString]]];
		[options addObject:
		 [DosecastUtil capitalizeFirstLetterOfString:
		  [[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Dose", @"The Skip Dose button on the dose reminder alert"])] lowercaseString]]];
		[options addObject:
         [DosecastUtil capitalizeFirstLetterOfString:
          [[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"])] lowercaseString]]];
        [options addObject:
         [DosecastUtil capitalizeFirstLetterOfString:
          [[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"DrugHistoryMissDoseAction", @"Dosecast", [DosecastUtil getResourceBundle], @"Miss Dose", @"The Miss Dose action label in the drug history"])] lowercaseString]]];
        if (allowRefillEvent)
        {
            [options addObject:
             [DosecastUtil capitalizeFirstLetterOfString:
              [[NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill", @"The Refill label in the Drug Edit view"])] lowercaseString]]];            
        }
        
		int selectedItem = -1;
        if ([actionName caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
            selectedItem = 0;
        else if ([actionName caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
            selectedItem = 1;
        else if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
            selectedItem = 2;
        else if ([actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            selectedItem = 3;
        else if ([actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
            selectedItem = 4;
		
		PicklistViewController* picklistController = [[PicklistViewController alloc]
													  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
													  bundle:[DosecastUtil getResourceBundle]
													  nonEditableItems:options
                                                      editableItems:nil
													  selectedItem:selectedItem
                                                      allowEditing:NO
													  viewTitle:viewTitle
													  headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEditEventAction", @"Dosecast", [DosecastUtil getResourceBundle], @"Action", @"The Action label in the History Add Event view"])
													  footerText:nil
                                                      addItemCellText:nil
                                                      addItemPlaceholderText:nil
													  displayNone:NO
													  identifier:ActionPicklistId
													  subIdentifier:nil
													  delegate:self];
		[self.navigationController pushViewController:picklistController animated:YES];
	}
    else if (section == HistoryAddEditEventViewControllerSectionsPostponePeriod)
    {        
        // Display TimePeriodViewController in new view
        TimePeriodViewController* timePeriodController = [[TimePeriodViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TimePeriodViewController"]
                                                                                                    bundle:[DosecastUtil getResourceBundle]
                                                                                     initialTimePeriodSecs:(postponePeriodSecs >= 0 ? postponePeriodSecs : 0)
                                                                                            minuteInterval:POSTPONE_INCREMENT_MINS
                                                                                                  maxHours:MAX_POSTPONE_HOURS
                                                                                                identifier:0
                                                                                                 viewTitle:viewTitle
                                                                                                cellHeader:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEditEventPostponeDuration", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone Duration", @"The Postpone Duration label in the History Add Event view"])
                                                                                              displayNever:NO
                                                                                                neverTitle:nil
                                                                                                 allowZero:NO
                                                                                                   nibName:@"TimePeriodTableViewCell"
                                                                                                  delegate:self];
        
        [self.navigationController pushViewController:timePeriodController animated:YES];
    }
	else if (section == HistoryAddEditEventViewControllerSectionsEventTime)
	{
        // Use the event time as the initial time to display. If it hasn't been set, default to the scheduled time
        NSDate* initialTime = eventTime;
        if (!initialTime)
            initialTime = scheduledTime;

		DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
																  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  initialDateTimeVal:initialTime
																  mode:DateTimePickerViewControllerModePickDateTime
                                                                  minuteInterval:1
																  identifier:0
																  viewTitle:viewTitle
																  cellHeader:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryEventTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Event Time", @"The Event Time label of the Drug History Event Time view"])
																  displayNever:NO
                                                                  neverTitle:nil
																  nibName:@"HistoryEventTimeTableViewCell"
																  delegate:self];
		[self.navigationController pushViewController:dateTimePickerController animated:YES];
	}
    else if (section == HistoryAddEditEventViewControllerSectionsScheduledTime &&
             [actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] != NSOrderedSame)
    {
        // The schedule time is required for missed doses
        BOOL displayNever = ([actionName caseInsensitiveCompare:HistoryManagerMissPillOperationName] != NSOrderedSame);

        // Use the scheduled time as the initial time to display. If it hasn't been set, default to the event time
        NSDate* initialTime = scheduledTime;
        if (!initialTime)
            initialTime = eventTime;
        
        DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
																  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  initialDateTimeVal:initialTime
																  mode:DateTimePickerViewControllerModePickDateTime
                                                                  minuteInterval:1
																  identifier:1
																  viewTitle:viewTitle
																  cellHeader:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryScheduledTimeLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Scheduled Time", @"The Scheduled Time label of the Drug History Event Time view"])
																  displayNever:displayNever
                                                                  neverTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditScheduleTimesNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The none value in the Take Drug cell for scheduled reminders of the Drug Edit view"])
																  nibName:@"HistoryEventTimeTableViewCell"
																  delegate:self];
		[self.navigationController pushViewController:dateTimePickerController animated:YES];
    }
    else if (section == HistoryAddEditEventViewControllerSectionsRefillAmount &&
             [actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
    {
        // Display the picker
        NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                          bundle:[DosecastUtil getResourceBundle]
                                                          sigDigits:6
                                                          numDecimals:2
                                                          viewTitle:viewTitle
                                                          displayTitle:NSLocalizedStringWithDefaultValue(@"DrugHistoryRefillAmount", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Amount", @"The Scheduled Time label of the Drug History Event Time view"])
                                                          initialVal:refillAmount
                                                          initialUnit:nil
                                                          possibleUnits:nil
                                                          displayNone:NO
                                                          allowZeroVal:YES
                                                          identifier:nil
                                                          subIdentifier:nil
                                                          delegate:self];
        [self.navigationController pushViewController:numericController animated:YES];
    }
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}




@end
