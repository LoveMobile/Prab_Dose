//
//  PostponePillsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "PostponePillsViewController.h"
#import "Drug.h"
#import "LocalNotificationManager.h"
#import "CustomNameIDList.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int MAX_POSTPONE_HOURS = 24;
static const int POSTPONE_INCREMENT_MINS = 5;
static const int SECTION_HEADER_HEIGHT = 32;
static const int SECTION_MID_FOOTER_HEIGHT = 8;
static const int SECTION_LAST_FOOTER_HEIGHT = 66;
static const CGFloat LABEL_BASE_HEIGHT = 19.0f;
static const CGFloat CELL_MIN_HEIGHT = 44.0f;

@implementation PostponePillsViewController

@synthesize tableView;
@synthesize pickerView;
@synthesize pillTableViewCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil drugsToPostpone:[[NSArray alloc] init] footerMessage:nil delegate:nil];
}

// Initialize the controller to display numbers in the range [1..maxVal],
// optionally with a text suffix after each one
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
      drugsToPostpone:(NSArray*)drugsToPostpone
        footerMessage:(NSString*)footer
             delegate:(NSObject<PostponePillsViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		postponePillsDict = [[NSMutableDictionary alloc] initWithCapacity:[drugsToPostpone count]];
        
        controllerDelegate = delegate;
		footerMessage = footer;
        postponedDrugIDs = [[NSMutableArray alloc] init];
        examplePillTableViewCell = nil;
		drugIds = [[NSArray alloc] initWithArray:drugsToPostpone];
        drugListGroupIndices = [[NSMutableArray alloc] init];

		// Populate the dictionary
        int numDrugs = (int)[drugIds count];
		for (int i = 0; i < numDrugs; i++)
		{
			NSString* drugId = [drugIds objectAtIndex:i];
			// For this drug ID, set the postpone period to 0 (not postponed)
			[postponePillsDict setValue:[NSNumber numberWithInt:0] forKey:drugId];
		}
		// Set the active drug as the first one
		activeDrugId = [drugIds objectAtIndex:0];
        
        // Calculate the group indices indicating how these drugs should be grouped
        DataModel* dataModel = [DataModel getInstance];
        NSMutableArray* drugList = [[NSMutableArray alloc] init];
        for (int i = 0; i < numDrugs; i++)
        {
            NSString* drugId = [drugIds objectAtIndex:i];
            [drugList addObject:[dataModel findDrugWithId:drugId]];
        }
        
        self.title = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]);
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        
        // Set Cancel button
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        
        // Set Done button
        NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
        doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
        self.navigationItem.rightBarButtonItem = doneButton;
        doneButton.enabled = NO;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;	
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
	tableView.sectionHeaderHeight = 16;
	tableView.sectionFooterHeight = 16;
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"PostponePillTableViewCell" owner:self options:nil];
    examplePillTableViewCell = pillTableViewCell;
    pillTableViewCell = nil;
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

- (void)setPickerToActiveDrugPostponePeriod
{
	NSNumber* postponePeriod = [postponePillsDict valueForKey:activeDrugId];
	int numHours = [postponePeriod intValue]/60;
	int numMinutes = [postponePeriod intValue]%60;
	[pickerView selectRow:numHours inComponent:0 animated:YES];
	[pickerView selectRow:(numMinutes/POSTPONE_INCREMENT_MINS) inComponent:1 animated:YES];
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

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	// Initialize picker and table selections
	[self setPickerToActiveDrugPostponePeriod];
}

// Called prior to rotating the device orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	[tableView reloadData];
	[self setPickerToActiveDrugPostponePeriod];
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

- (void)handleDelegatePostponePillsCancel:(NSTimer*)theTimer
{
	if ([controllerDelegate respondsToSelector:@selector(handlePostponePillsCancel)])
	{
		[controllerDelegate handlePostponePillsCancel];
	}
}

- (void)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];

    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegatePostponePillsCancel:) userInfo:nil repeats:NO];
}

- (void)handleDone:(id)sender
{
	NSString* nextDrugId = [self nextDrugToPostpone];
	if (nextDrugId)
	{
		[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];

        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];

		// Make a PostponePill request
		NSNumber* postponePeriod = [postponePillsDict valueForKey:nextDrugId];
		[[LocalNotificationManager getInstance] postponePill:nextDrugId
                                                     seconds:([postponePeriod intValue]*60)
                                                   respondTo:self
                                                       async:YES];
	}
}

// Returns the Id of the next drug to postpone
- (NSString*)nextDrugToPostpone
{
	NSString* nextDrug = nil;
	
	for (int i = 0; i < [drugIds count] && !nextDrug; i++)
	{
		NSString* drugId = [drugIds objectAtIndex:i];
		NSNumber* postponePeriod = [postponePillsDict valueForKey:drugId];
		if ([postponePeriod intValue] > 0)
			nextDrug = drugId;
	}
	return nextDrug;
}

- (void)postponePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{	
	if (result)
	{		
		// Mark this pill as being postponed
		NSString* postponedDrugId = [self nextDrugToPostpone];
		[postponePillsDict setValue:[NSNumber numberWithInt:0] forKey:postponedDrugId];
        [postponedDrugIDs addObject:postponedDrugId];

		NSString* nextDrugId = [self nextDrugToPostpone];
		if (nextDrugId)
		{
            NSNumber* postponePeriod = [postponePillsDict valueForKey:nextDrugId];
            [[LocalNotificationManager getInstance] postponePill:nextDrugId
                                                         seconds:([postponePeriod intValue]*60)
                                                       respondTo:self
                                                           async:YES];
		}
		else
		{
            LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
            
            // End a batch update if we started one
            if ([localNotificationManager batchUpdatesInProgress])
                [localNotificationManager endBatchUpdates:NO];

			doneButton.enabled = NO;
			[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
			
			[self.navigationController popViewControllerAnimated:YES];			
			if ([controllerDelegate respondsToSelector:@selector(handlePostponePillsDone:)])
			{
				[controllerDelegate handlePostponePillsDone:postponedDrugIDs];
			}						
		}
	}
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
		
		NSString* nextDrugId = [self nextDrugToPostpone];
		Drug* d = [[DataModel getInstance] findDrugWithId:nextDrugId];
		
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugPostponeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Postpone %@ Dose", @"The title of the alert appearing when the user can't postpone a dose because an error occurs"]), d.name]
                                                                                           message:errorMessage];
		[alert showInViewController:self];
    }
}

// Returns the maximum postpone duration in minutes for the active drug
- (int) getMaxPostponeDurationMinForActiveDrug
{
	Drug* activeDrug = [[DataModel getInstance] findDrugWithId:activeDrugId];
	NSDate* basePostponeTime = [activeDrug.reminder getBasePostponeTime];
	if (activeDrug.reminder.maxPostponeTime == nil || basePostponeTime == nil)
		return -1;
	else
	{
		int maxPostponeDurationMin = [activeDrug.reminder.maxPostponeTime timeIntervalSinceDate:basePostponeTime]/60;
		if (maxPostponeDurationMin < 0)
			maxPostponeDurationMin = 0;
		// Round to the nearest increment
		maxPostponeDurationMin = (maxPostponeDurationMin/POSTPONE_INCREMENT_MINS)*POSTPONE_INCREMENT_MINS;
		return maxPostponeDurationMin;
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
-(NSString*)postponeStringLabelForMinutes:(int)numMins padNum:(BOOL)padNum
{
	NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
	NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);

	NSString* unit = nil;
	if (![DosecastUtil shouldUseSingularForInteger:numMins])
		unit = minPlural;
	else
		unit = minSingular;
	
	if (padNum)
		return [NSString stringWithFormat:@"%02d %@", numMins, unit];
	else
		return [NSString stringWithFormat:@"%d %@", numMins, unit];
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

    return [drugListGroupIndices count];
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

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"PillCellIdentifier";
	
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"PostponePillTableViewCell" owner:self options:nil];
        cell = pillTableViewCell;
        pillTableViewCell = nil;
    }
	    
	Drug* d = [self getDrugForCellAtIndexPath:indexPath];

	// Determine when to change text color. Only do it for the active drug, if we are displaying
	// multiple drugs.
	BOOL isActiveDrug = ([d.drugId caseInsensitiveCompare:activeDrugId] == NSOrderedSame);
	BOOL drawSelected = [drugIds count] == 1 || isActiveDrug;
	
	// Set main label
	UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
	mainLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewPostponeDrugCellLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone %@ dose", @"The cell label in the Postpone Drug view"]), d.name];
	if (drawSelected)
		mainLabel.textColor = [UIColor blackColor];
	else
		mainLabel.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];	
	
	// Set picker label
	UILabel* pickerLabel = (UILabel *)[cell viewWithTag:2];
	NSNumber* postponePeriod = [postponePillsDict valueForKey:d.drugId];
	int numHours = [postponePeriod intValue]/60;
	int numMinutes = [postponePeriod intValue]%60;
	pickerLabel.text = [NSString stringWithFormat:@"%@\n%@", [self postponeStringLabelForHours:numHours], [self postponeStringLabelForMinutes:numMinutes padNum:NO]];

	if (drawSelected)
		pickerLabel.textColor = [UIColor blackColor];
	else
		pickerLabel.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
	
    return cell;
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
    if (labelSize.height <= CELL_MIN_HEIGHT)
        return CELL_MIN_HEIGHT;
    else
        return labelSize.height+2.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Drug* d = [self getDrugForCellAtIndexPath:indexPath];

    NSString* mainLabel = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewPostponeDrugCellLabel", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone %@ dose", @"The cell label in the Postpone Drug view"]), d.name];
    return (int)ceilf([self getHeightForCellLabelTag:1 labelBaseHeight:LABEL_BASE_HEIGHT withString:mainLabel]);
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
        return footerMessage;
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Update the active drug
    Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
	activeDrugId = drug.drugId;
	// Update the picker
	[self setPickerToActiveDrugPostponePeriod];
	[self.tableView reloadData];	
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

#pragma mark Picker view methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{	
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	if (component == 0)
		return MAX_POSTPONE_HOURS;
	else // component == 1
		return 60/POSTPONE_INCREMENT_MINS;
}

- (UIView *)pickerView:(UIPickerView *)pv viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
	UILabel* label = (UILabel*)view;
	if (!label)
	{
		CGSize size = [pv rowSizeForComponent:component];
		label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
	}

	label.textAlignment = NSTextAlignmentCenter;
	label.font = [UIFont boldSystemFontOfSize:24];
	label.backgroundColor = [UIColor clearColor];
	label.userInteractionEnabled = YES;

	if (component == 0)
	{
		label.text = [NSString stringWithFormat:@"%@", [self postponeStringLabelForHours:(int)row]];
	}
	else // component == 1
	{
		label.text = [NSString stringWithFormat:@"%@", [self postponeStringLabelForMinutes:(int)row*POSTPONE_INCREMENT_MINS padNum:YES]];
	}
	
	return label;		
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	int numHours = (int)[self.pickerView selectedRowInComponent:0];
	int numMins = (int)[self.pickerView selectedRowInComponent:1]*POSTPONE_INCREMENT_MINS;
	int selectedMin = numHours*60+numMins;
	int maxPostponeDurationMin = [self getMaxPostponeDurationMinForActiveDrug];
	if (maxPostponeDurationMin >= 0 && selectedMin >= maxPostponeDurationMin)
	{
        NSString* message = nil;
        if (numHours == 0)
            message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug cannot be postponed %@ because the next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone a drug past the limit"]), [self postponeStringLabelForMinutes:numMins padNum:NO]];
        else
            message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug cannot be postponed %@ because the next dose is due before or around then.", @"The message of the alert appearing when the user tries to postpone a drug past the limit"]), [NSString stringWithFormat:@"%@ %@", [self postponeStringLabelForHours:numHours], [self postponeStringLabelForMinutes:numMins padNum:NO]]];

        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorPostponeDrugLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Postpone Drug", @"The title of the alert appearing when the user tries to postpone a drug past the limit"])
                                                                                                message:message
                                                                                                  style:DosecastAlertControllerStyleAlert];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action) {
                                          int maxPostponeDurationMin = [self getMaxPostponeDurationMinForActiveDrug];
                                          if (maxPostponeDurationMin >= 0)
                                          {
                                              // Force the postpone duration for this drug to be just less than the max allowable pospone duration.
                                              maxPostponeDurationMin = maxPostponeDurationMin - POSTPONE_INCREMENT_MINS;
                                              if (maxPostponeDurationMin < 0)
                                                  maxPostponeDurationMin = 0;
                                              
                                              // Update the dictionary
                                              [postponePillsDict setValue:[NSNumber numberWithInt:maxPostponeDurationMin] forKey:activeDrugId];
                                              if (maxPostponeDurationMin == 0)
                                              {
                                                  NSString* nextDrugId = [self nextDrugToPostpone];
                                                  if (!nextDrugId)
                                                      doneButton.enabled = NO;
                                              }
                                              else
                                              {
                                                  if (!doneButton.enabled)
                                                      doneButton.enabled = YES;
                                              }
                                              [tableView reloadData];
                                              [self setPickerToActiveDrugPostponePeriod];
                                          }		
                                      }]];
        
        [alert showInViewController:self];
	}
	else
	{
		// Update the dictionary
		[postponePillsDict setValue:[NSNumber numberWithInt:selectedMin] forKey:activeDrugId];
		if (selectedMin == 0)
		{
			NSString* nextDrugId = [self nextDrugToPostpone];
			if (!nextDrugId)
				doneButton.enabled = NO;
		}
		else
		{
			if (!doneButton.enabled)
				doneButton.enabled = YES;
		}
		[tableView reloadData];
	}
}

@end
