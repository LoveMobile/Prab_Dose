//
//  TakePillsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "TakePillsViewController.h"
#import "DataModel.h"
#import "Drug.h"
#import "CustomNameIDList.h"
#import "LocalNotificationManager.h"
#import "DateTimePickerViewController.h"
#import "GlobalSettings.h"
#import "DosecastUtil.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int SECTION_HEADER_HEIGHT = 32;
static const int SECTION_MID_FOOTER_HEIGHT = 8;
static const int SECTION_LAST_FOOTER_HEIGHT = 32;
static const CGFloat NAME_LABEL_BASE_HEIGHT = 19;
static const CGFloat DOSETIME_LABEL_BASE_HEIGHT = 18;

@implementation TakePillsViewController

@synthesize pillTableViewCell;
@synthesize tableView;
@synthesize takePillsDelegate;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
              drugIds:(NSArray*)ids
			 delegate:(NSObject<TakePillsViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		takePillsDict = [[NSMutableDictionary alloc] initWithCapacity:[ids count]];
		takePillsDelegate = delegate;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		takePillIndexPath = nil;
        drugIds = [[NSArray alloc] initWithArray:ids];
		doneButton = nil;
		takePillTime = nil;
		takenDrugIDs = [[NSMutableArray alloc] init];
        drugListGroupIndices = [[NSMutableArray alloc] init];
        examplePillTableViewCell = nil;
        
        // Populate the dictionary
        int numDrugs = (int)[drugIds count];
        for (int i = 0; i < numDrugs; i++)
        {
            // For this drug ID, set the bit to 0 (unchecked)
            [takePillsDict setValue:[NSNumber numberWithLongLong:0] forKey:[drugIds objectAtIndex:i]];
        }

        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil drugIds:[[NSArray alloc] init] delegate:nil];
}

- (void) recalcExampleCellWidth
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
    
    examplePillTableViewCell.frame = CGRectMake(examplePillTableViewCell.frame.origin.x, examplePillTableViewCell.frame.origin.y, screenWidth, examplePillTableViewCell.frame.size.height);
    
    [examplePillTableViewCell layoutIfNeeded];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDosePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Doses", @"The Take Doses button on the dose reminder alert"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	
	doneButton.enabled = NO;
	
	tableView.sectionHeaderHeight = 8;
	tableView.sectionFooterHeight = 8;
	
    // Load an example cell and size it
    [[DosecastUtil getResourceBundle] loadNibNamed:@"TakePillsTableViewCell" owner:self options:nil];
    examplePillTableViewCell = pillTableViewCell;
    pillTableViewCell = nil;
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


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

- (NSString*)nextDrugToTake // Returns the next drug to take
{
	NSArray* allKeys = [takePillsDict allKeys];
	NSString* nextDrug = nil;
	
	for (int i = 0; i < [allKeys count] && !nextDrug; i++)
	{
		NSString* drugId = [allKeys objectAtIndex:i];
		NSNumber* timeNum = [takePillsDict valueForKey:drugId];
		if ([timeNum longLongValue] != 0)
			nextDrug = drugId;
	}
	return nextDrug;
}

- (void)handleDelegateTakePillsCancel:(NSTimer*)theTimer
{
	if ([takePillsDelegate respondsToSelector:@selector(handleTakePillsCancel)])
	{
		[takePillsDelegate handleTakePillsCancel];
	}
}

- (IBAction)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];
	
    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegateTakePillsCancel:) userInfo:nil repeats:NO];
}

- (IBAction)handleDone:(id)sender
{
	NSString* nextDrugId = [self nextDrugToTake];
	if (nextDrugId)
	{
		[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
	
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];

		// Make a TakePill request
		
		takePillTime = [NSDate date];
		
		NSNumber* doseTimeNum = [takePillsDict valueForKey:nextDrugId];
		NSDate* doseTime = nil;
		if ([doseTimeNum longLongValue] > 0)
			doseTime = [NSDate dateWithTimeIntervalSince1970:[doseTimeNum longLongValue]];
		else
			doseTime = takePillTime;
		
		[localNotificationManager takePill:nextDrugId
                                  doseTime:doseTime
                                 respondTo:self
                                     async:YES];
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
		[alert showInViewController:self];
	}
	else
	{
		// Store new time in dictionary
        Drug* d = [self getDrugForCellAtIndexPath:takePillIndexPath];
		[takePillsDict setValue:[NSNumber numberWithLongLong:(long long)[dateTimeVal timeIntervalSince1970]] forKey:d.drugId];
		if (!doneButton.enabled)
			doneButton.enabled = YES;
		[tableView reloadData];
        takePillIndexPath = nil;
	}
	
	return !isFuture;
}

// Called to handle a request for the time a drug was taken
- (void)requestTakePillTime:(NSIndexPath*)indexPath
{
    takePillIndexPath = indexPath;
    NSString* takePillDrugId = [self getDrugForCellAtIndexPath:takePillIndexPath].drugId;
	
	// Construct a new action sheet and use it to confirm the user wants to take the pill
	
    DosecastAlertController* requestTakePillTimeController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [requestTakePillTimeController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction* action) {
                                      takePillIndexPath = nil;
                                  }]];

    [requestTakePillTimeController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseConfirmationButtonTakeNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Take dose now", @"The Take Dose Now button on the alert confirming whether the user wants to take a dose"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      if (takePillDrugId)
                                          [takePillsDict setValue:[NSNumber numberWithLongLong:-1] forKey:takePillDrugId];
                                      if (!doneButton.enabled)
                                          doneButton.enabled = YES;
                                      [self.tableView reloadData];

                                      takePillIndexPath = nil;
                                  }]];
    
    [requestTakePillTimeController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseConfirmationButtonTookAlready", @"Dosecast", [DosecastUtil getResourceBundle], @"I already took this dose", @"The Took Already button on the alert confirming whether the user wants to take a dose"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      
                                      // Ask user what time the pill was taken
                                      NSDate* dateTimeVal = [NSDate date];
                                      DateTimePickerViewController* dateTimePickerController = [[DateTimePickerViewController alloc]
                                                                                                initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DateTimePickerViewController"]
                                                                                                bundle:[DosecastUtil getResourceBundle]
                                                                                                initialDateTimeVal:dateTimeVal
                                                                                                mode:DateTimePickerViewControllerModePickDateTime
                                                                                                minuteInterval:1
                                                                                                identifier:0
                                                                                                viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDoseTimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Dose", @"The title of the Dose Time view"])
                                                                                                cellHeader:NSLocalizedStringWithDefaultValue(@"ViewDoseTimeDoseTakenLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose Taken", @"The Dose Taken label of the Dose Time view"])
                                                                                                displayNever:NO
                                                                                                neverTitle:nil
                                                                                                nibName:@"TakePillTimeTableViewCell"
                                                                                                delegate:self];
                                      [self.navigationController pushViewController:dateTimePickerController animated:YES];
                                  }]];

    [requestTakePillTimeController showInViewController:self sourceView:[self.tableView cellForRowAtIndexPath:takePillIndexPath]];
}

// Callback for when user hits cancel
- (void)handleCancelDateTime:(int)uniqueID
{
	// Display the action sheet again to force the user to decide
	[self requestTakePillTime:takePillIndexPath];
}

- (void)takePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
    
    if (result)
	{
		// Mark this pill as being taken
		NSString* takenDrugId = [self nextDrugToTake];
		[takePillsDict setValue:[NSNumber numberWithLongLong:0] forKey:takenDrugId];
		[takenDrugIDs addObject:takenDrugId];
				
		NSString* nextDrugId = [self nextDrugToTake];
		if (nextDrugId)
		{
			// Make a TakePill request
			NSNumber* doseTimeNum = [takePillsDict valueForKey:nextDrugId];
			NSDate* doseTime = nil;
			if ([doseTimeNum longLongValue] > 0)
				doseTime = [NSDate dateWithTimeIntervalSince1970:[doseTimeNum longLongValue]];
			else
				doseTime = takePillTime;

            [localNotificationManager takePill:nextDrugId
                                      doseTime:doseTime
                                     respondTo:self
                                         async:YES];
		}
		else
		{
            // End a batch update if we started one
            if ([localNotificationManager batchUpdatesInProgress])
                [localNotificationManager endBatchUpdates:NO];

			doneButton.enabled = NO;
			[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
			
			[self.navigationController popViewControllerAnimated:YES];			
			if ([takePillsDelegate respondsToSelector:@selector(handleTakePillsDone:)])
			{
				[takePillsDelegate handleTakePillsDone:takenDrugIDs];
			}
		}
        
        [self.tableView reloadData];
	}
    else
    {
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
		NSString* nextDrugId = [self nextDrugToTake];
		Drug* d = [[DataModel getInstance] findDrugWithId:nextDrugId];
		
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugTakeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Take %@ Dose", @"The title of the alert appearing when the user can't take a dose because an error occurs"]), d.name]
                                                                                           message:errorMessage];
		[alert showInViewController:self];
    }
}

// Returns whether to display group names
- (BOOL) displayGroupNames
{
    DataModel* dataModel = [DataModel getInstance];
    
    // See if any archived drugs exist
    for (Drug* d in dataModel.drugList)
    {
        if (d.reminder.archived)
            return YES;
    }
    
    if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByDrugType)
        return YES;
    else // for all other sort orders, use person names
        return ([[dataModel.globalSettings.personNames allGuids] count] > 0);
}

// Returns the group name for the group containing the given drug
- (NSString*)getGroupNameForGroupContainingDrug:(Drug*)drug
{
    if (![self displayGroupNames])
        return nil;
    
    DataModel* dataModel = [DataModel getInstance];
    
    if (drug.reminder.archived)
        return NSLocalizedStringWithDefaultValue(@"ViewDrugsArchivedDrugsSectionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Archived", @"The title of the archived drugs section in the drugs view"]);
    
    if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByDrugType)
        return [drug.dosage getTypeName];
    else
    {
        NSString* personName = nil;
        if ([drug.personId length] == 0)
        {
            if ([[dataModel.globalSettings.personNames allGuids] count] > 0)
                personName = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]);
        }
        else
            personName = [dataModel.globalSettings.personNames nameForGuid:drug.personId];
        
        if (personName)
            return [NSString stringWithFormat:@"%@ %@", NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonTakenBy", @"Dosecast", [DosecastUtil getResourceBundle], @"For", @"The Person For label in the Drug Edit view"]), personName];
        else
            return nil;
    }
}

// Returns a list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
- (NSArray*)getGroupIndicesForDrugList:(NSArray*)drugs
{
    NSMutableArray* groupIndices = [[NSMutableArray alloc] init];
    
    if ([self displayGroupNames])
    {
        NSString* lastGroupName = nil;
        
        int numDrugs = (int)[drugs count];
        for (int i = 0; i < numDrugs; i++)
        {
            Drug* d = [drugs objectAtIndex:i];
            NSString* thisGroupName = [self getGroupNameForGroupContainingDrug:d];
            if ((!lastGroupName && thisGroupName) ||
                (lastGroupName && !thisGroupName) ||
                (lastGroupName  && thisGroupName && [lastGroupName compare:thisGroupName options:NSLiteralSearch] != NSOrderedSame))
            {
                [groupIndices addObject:[NSNumber numberWithInt:i]];
                lastGroupName = thisGroupName;
            }
            else if (i == 0)
                [groupIndices addObject:[NSNumber numberWithInt:0]];
        }
    }
    else if ([drugs count] > 0)
        [groupIndices addObject:[NSNumber numberWithInt:0]];
    
    return groupIndices;
}

// Returns a list of NSNumbers indicating the indices of drugs in the given drug ID list for distinct groups
- (NSArray*)getGroupIndicesForDrugIDList:(NSArray*)drugIDs
{
    NSMutableArray* drugList = [[NSMutableArray alloc] init];
    
    DataModel* dataModel = [DataModel getInstance];
    
    for (NSString* drugId in drugIDs)
    {
        [drugList addObject:[dataModel findDrugWithId:drugId]];
    }
    return [self getGroupIndicesForDrugList:drugList];
}

#pragma mark Table view methods

- (Drug*) getDrugForCellAtIndexPath:(NSIndexPath*)indexPath
{
    DataModel* dataModel = [DataModel getInstance];
    int drugIndex = [((NSNumber*)[drugListGroupIndices objectAtIndex:indexPath.section]) intValue] + (int)indexPath.row;
    return [dataModel findDrugWithId:[drugIds objectAtIndex:drugIndex]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];
    [drugListGroupIndices setArray:[self getGroupIndicesForDrugIDList:drugIds]];

    return [[self getGroupIndicesForDrugIDList:drugIds] count];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Calculate the start & end indixes for this section
    int drugIndexStart = [((NSNumber*)[drugListGroupIndices objectAtIndex:section]) intValue];
    int drugIndexEnd = -1;
    if (section == [drugListGroupIndices count]-1)
        drugIndexEnd = (int)[drugIds count]-1;
    else
        drugIndexEnd = [((NSNumber*)[drugListGroupIndices objectAtIndex:section+1]) intValue]-1;
    
    return drugIndexEnd-drugIndexStart+1;
}

- (CGFloat) getHeightForCellLabelTag:(int)tag labelBaseHeight:(CGFloat)labelBaseHeight withString:(NSString*)value
{
    UILabel* label = (UILabel*)[examplePillTableViewCell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, labelBaseHeight * (float)label.numberOfLines);
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName: label.font}
                                      context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    if (labelSize.height > labelBaseHeight)
        return labelSize.height+2.0f;
    else
        return labelBaseHeight;
}

- (NSString*) getSubLabelTextForDrug:(NSString*)drugId
{
    Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

    NSMutableString* subLabelText = nil;
	NSNumber* timeNum = [takePillsDict valueForKey:drugId];
	if ([timeNum longLongValue] < 0)
	{
		subLabelText = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewTakeDosesTakenNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Taken now", @"The taken now label appearing in the take doses view"])];
		
		if ([d.directions length] > 0)
			[subLabelText appendFormat:@" (%@)", d.directions];
	}
	else if ([timeNum longLongValue] > 0)
	{
		NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		NSDate* now = [NSDate date];
		NSDate* time = [NSDate dateWithTimeIntervalSince1970:[timeNum longLongValue]];
		unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
		
		// Get the day/month/year for today and for the date given
		NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
		NSDateComponents* timeComponents = [cal components:unitFlags fromDate:time];
		
		// If given date is today
		if ([todayComponents day] == [timeComponents day] &&
			[todayComponents month] == [timeComponents month] &&
			[todayComponents year] == [timeComponents year])
		{
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			subLabelText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewTakeDosesTakenToday", @"Dosecast", [DosecastUtil getResourceBundle], @"Taken today at %@", @"The taken today label appearing in the take doses view"]), [dateFormatter stringFromDate:time]];
		}
		else
		{
			[dateFormatter setDateStyle:NSDateFormatterShortStyle];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			NSString* date = [dateFormatter stringFromDate:time];
            
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			subLabelText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewTakeDosesTakenDate", @"Dosecast", [DosecastUtil getResourceBundle], @"Taken %@ at %@", @"The taken on date label appearing in the take doses view"]), date, [dateFormatter stringFromDate:time]];
		}		
	}
    
    return subLabelText;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"PillCellIdentifier";
	
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"TakePillsTableViewCell" owner:self options:nil];
        cell = pillTableViewCell;
        pillTableViewCell = nil;
    }
    
	Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
	
    NSString* mainLabelText = [drug.dosage getDescriptionForDrugDose:drug.name];
    NSString* subLabelText = [self getSubLabelTextForDrug:drug.drugId];
    
	// Set main label
	UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
	mainLabel.text = mainLabelText;
    CGFloat mainLabelHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:NAME_LABEL_BASE_HEIGHT withString:mainLabel.text];
    mainLabel.frame = CGRectMake(mainLabel.frame.origin.x, mainLabel.frame.origin.y, mainLabel.frame.size.width, (int)ceilf(mainLabelHeight));
    CGFloat shiftY = (mainLabelHeight - NAME_LABEL_BASE_HEIGHT);

	// Set sub label
	UILabel* subLabel = (UILabel *)[cell viewWithTag:2];
    CGFloat subLabelHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DOSETIME_LABEL_BASE_HEIGHT withString:subLabelText];
    subLabel.frame = CGRectMake(subLabel.frame.origin.x, (int)ceilf([examplePillTableViewCell viewWithTag:2].frame.origin.y + shiftY), subLabel.frame.size.width, (int)ceilf(subLabelHeight));
    subLabel.text = subLabelText;
    
	// Determine whether checked
    NSNumber* timeNum = [takePillsDict valueForKey:drug.drugId];
	if ([timeNum longLongValue] == 0)
		cell.accessoryType = UITableViewCellAccessoryNone;	
	else
		cell.accessoryType = UITableViewCellAccessoryCheckmark;	
		
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
    NSString* mainLabelText = [drug.dosage getDescriptionForDrugDose:drug.name];
    NSString* subLabelText = [self getSubLabelTextForDrug:drug.drugId];

    CGFloat cellHeight = examplePillTableViewCell.frame.size.height;
    
    CGFloat mainLabelHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:NAME_LABEL_BASE_HEIGHT withString:mainLabelText];
    cellHeight += (mainLabelHeight - NAME_LABEL_BASE_HEIGHT);
    
    CGFloat subLabelHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DOSETIME_LABEL_BASE_HEIGHT withString:subLabelText];
    cellHeight += (subLabelHeight - DOSETIME_LABEL_BASE_HEIGHT);
    
    return cellHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    Drug* d = [self getDrugForCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
    
    return [self getGroupNameForGroupContainingDrug:d];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    int numSections = (int)[drugListGroupIndices count];

    if (section == numSections-1)
        return NSLocalizedStringWithDefaultValue(@"ViewTakeDosesMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Select the doses to take", @"The message appearing in the take doses view"]);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	
	// Flip the bit for the corresponding drug in the dictionary
	Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
	NSNumber* timeNum = [takePillsDict valueForKey:drug.drugId];
	if ([timeNum longLongValue] != 0)
	{
		// Uncheck the drug
		[takePillsDict setValue:[NSNumber numberWithLongLong:0] forKey:drug.drugId];
		if ([self nextDrugToTake] == nil)
			doneButton.enabled = NO;
		[self.tableView reloadData];
	}
	else // Ask the user what time the drug was taken
        [self requestTakePillTime:indexPath];
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return SECTION_HEADER_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    int numSections = (int)[drugListGroupIndices count];
    
    if (section == numSections-1)
        return SECTION_LAST_FOOTER_HEIGHT;
    else
        return SECTION_MID_FOOTER_HEIGHT;
}



@end

