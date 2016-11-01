//
//  SkipPillsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "SkipPillsViewController.h"
#import "DataModel.h"
#import "Drug.h"
#import "LocalNotificationManager.h"
#import "CustomNameIDList.h"
#import "DosecastUtil.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int SECTION_HEADER_HEIGHT = 32;
static const int SECTION_MID_FOOTER_HEIGHT = 8;
static const int SECTION_LAST_FOOTER_HEIGHT = 32;
static const CGFloat LABEL_BASE_HEIGHT = 19.0f;
static const CGFloat CELL_MIN_HEIGHT = 44.0f;

@implementation SkipPillsViewController

@synthesize pillTableViewCell;
@synthesize tableView;
@synthesize skipPillsDelegate;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
              drugIds:(NSArray*)ids
			 delegate:(NSObject<SkipPillsViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		skipPillsDict = [[NSMutableDictionary alloc] initWithCapacity:[ids count]];
		skipPillsDelegate = delegate;
        drugIds = [[NSArray alloc] initWithArray:ids];
		doneButton = nil;
        skippedDrugIDs = [[NSMutableArray alloc] init];
        drugListGroupIndices = [[NSMutableArray alloc] init];
        examplePillTableViewCell = nil;
        
        // Populate the dictionary
        int numDrugs = (int)[drugIds count];
        for (int i = 0; i < numDrugs; i++)
        {
            // For this drug ID, set the bit to 0 (unchecked)
            [skipPillsDict setValue:[NSNumber numberWithLongLong:0] forKey:[drugIds objectAtIndex:i]];
        }
        
        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil drugIds:[[NSArray alloc] init] delegate:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSkipDosesTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Doses", @"The title on the skip doses view"]);
	
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
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"SkipPillsTableViewCell" owner:self options:nil];
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

- (NSString*)nextDrugToSkip // Returns the next drug to skip
{
	NSArray* allKeys = [skipPillsDict allKeys];
	NSString* nextDrug = nil;
	
	for (int i = 0; i < [allKeys count] && !nextDrug; i++)
	{
		NSString* drugId = [allKeys objectAtIndex:i];
		NSNumber* skipFlag = [skipPillsDict valueForKey:drugId];
		if ([skipFlag intValue] != 0)
			nextDrug = drugId;
	}
	return nextDrug;
}

- (void)handleDelegateSkipPillsCancel:(NSTimer*)theTimer
{
	if ([skipPillsDelegate respondsToSelector:@selector(handleSkipPillsCancel)])
	{
		[skipPillsDelegate handleSkipPillsCancel];
	}
}

- (IBAction)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];
    
    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegateSkipPillsCancel:) userInfo:nil repeats:NO];
}

- (IBAction)handleDone:(id)sender
{
	NSString* nextDrugId = [self nextDrugToSkip];
	if (nextDrugId)
	{
		[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
	
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // Begin a batch update if we haven't already
        if (![localNotificationManager batchUpdatesInProgress])
            [localNotificationManager beginBatchUpdates];

		[[LocalNotificationManager getInstance] skipPill:nextDrugId
                                               respondTo:self
                                                   async:YES];
	}
}

- (void)skipPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{	
    if (result)
	{
		// Mark this pill as being skipped
		NSString* skippedDrugId = [self nextDrugToSkip];
		[skipPillsDict setValue:[NSNumber numberWithInt:0] forKey:skippedDrugId];
        [skippedDrugIDs addObject:skippedDrugId];

		NSString* nextDrugId = [self nextDrugToSkip];
		if (nextDrugId)
		{
            [[LocalNotificationManager getInstance] skipPill:nextDrugId
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
			if ([skipPillsDelegate respondsToSelector:@selector(handleSkipPillsDone:)])
			{
				[skipPillsDelegate handleSkipPillsDone:skippedDrugIDs];
			}						
		}
        
        [self.tableView reloadData];
	}
    else
    {
        LocalNotificationManager* localNotificationManager = [LocalNotificationManager getInstance];
        
        // End a batch update if we started one
        if ([localNotificationManager batchUpdatesInProgress])
            [localNotificationManager endBatchUpdates:NO];

        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
		
		NSString* nextDrugId = [self nextDrugToSkip];
		Drug* d = [[DataModel getInstance] findDrugWithId:nextDrugId];
		
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorDrugSkipTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Skip %@ Dose", @"The title of the alert appearing when the user can't skip a dose because an error occurs"]), d.name]
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


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"PillCellIdentifier";
	
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"SkipPillsTableViewCell" owner:self options:nil];
        cell = pillTableViewCell;
        pillTableViewCell = nil;
    }
    
	Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
	
	// Set main label
	UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
	mainLabel.text = drug.name;
	
	NSNumber* skipFlag = [skipPillsDict valueForKey:drug.drugId];
	
	// Determine whether checked
	if ([skipFlag intValue] == 0)
		cell.accessoryType = UITableViewCellAccessoryNone;	
	else
		cell.accessoryType = UITableViewCellAccessoryCheckmark;	
	
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
    
    return (int)ceilf([self getHeightForCellLabelTag:1 labelBaseHeight:LABEL_BASE_HEIGHT withString:d.name]);
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
        return NSLocalizedStringWithDefaultValue(@"ViewSkipDosesMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Select the doses to skip", @"The message appearing in the skip doses view"]);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

	// Flip the bit for the corresponding drug in the dictionary
	Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
	NSNumber* skipFlag = [skipPillsDict valueForKey:drug.drugId];
	
	// Toggle the drug
	[skipPillsDict setValue:[NSNumber numberWithInt:(1-[skipFlag intValue])] forKey:drug.drugId];
	doneButton.enabled = ([self nextDrugToSkip] != nil);
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



@end

