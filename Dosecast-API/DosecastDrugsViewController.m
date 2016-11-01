//
//  DosecastDrugsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DosecastDrugsViewController.h"
#import "DataModel.h"
#import "DrugViewController.h"
#import "DrugAddEditViewController.h"
#import "PillNotificationManager.h"
#import "Drug.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "DosecastUtil.h"
#import "DrugHistoryViewController.h"
#import "LocalNotificationManager.h"
#import "HistoryManager.h"
#import "CustomNameIDList.h"
#import "DrugImageManager.h"
#import "ManagedDrugDosage.h"
#import "GlobalSettings.h"
#import "LogManager.h"
#import "AccountViewController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const double ASYNC_TIME_DELAY_ON_UNSWIPE = 0.01;
static const int SECTION_EMPTY_HEADER_HEIGHT = 8;
static const int SECTION_NONEMPTY_HEADER_HEIGHT = 32;
static const int SECTION_NONEMPTY_FOOTER_HEIGHT = 8;
static const int SECTION_EMPTY_FOOTER_HEIGHT = 100;
static const CGFloat DRUGNAME_LABEL_BASE_HEIGHT = 18.0f;
static const CGFloat DOSAGE_LABEL_BASE_HEIGHT = 16.0f;
static const CGFloat DIRECTIONS_LABEL_BASE_HEIGHT = 16.0f;
static const CGFloat WARNING_LABEL_BASE_HEIGHT = 16.0f;


static NSString *DeletePillMethodName = @"deletePill";

@implementation DosecastDrugsViewController

@synthesize pillTableViewCell;
@synthesize tableView;
@synthesize drugPlaceholderImageView;
@synthesize localNotificationWarningCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugsTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drugs", @"The title of the drugs view"]);

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        deletedIndexPath = nil;
        discontinuedDrugId = nil;
        examplePillTableViewCell = nil;
        self.hidesBottomBarWhenPushed = YES;
        isExceedingMaxLocalNotifications = NO;
        
        deletedLastRowInSection = NO;
        deletedLastSection = NO;
        isDeletingFromThisController = NO;
        preDeletedDrugListGroupIndices = [[NSMutableArray alloc] init];
        drugListGroupIndices = [[NSMutableArray alloc] init];
        drugImagesDictionary = [[NSMutableDictionary alloc] init];
        drugList = [[NSMutableArray alloc] init];
        tableViewController = nil;
        refreshControl = nil;

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:HistoryManagerHistoryEditedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDrugImageRefresh:)
                                                     name:DrugImageAvailableNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSyncComplete:)
                                                     name:LogSyncCompleteNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSyncFail:)
                                                     name:LogSyncFailedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HistoryManagerHistoryEditedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncFailedNotification object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
    // Set add button
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(handleAddDrug:)];
	self.navigationItem.rightBarButtonItem = addButton;
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugsViewPillTableViewCell" owner:self options:nil];
    examplePillTableViewCell = pillTableViewCell;
    pillTableViewCell = nil;
    
    // Setup refresh control
    tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    
    if ([[DataModel getInstance].apiFlags getFlag:DosecastAPIEnableSync])
    {
        refreshControl = [[UIRefreshControl alloc] init];
        refreshControl.tintColor = [DosecastUtil getNavigationBarColor];
        refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:
                                          NSLocalizedStringWithDefaultValue(@"SyncPullPrompt", @"Dosecast", [DosecastUtil getResourceBundle], @"Pull to Sync", @"The message prompting the user to pull to begin sync"])];
        [refreshControl addTarget:self action:@selector(handleSync:) forControlEvents:UIControlEventValueChanged];
        tableViewController.refreshControl = refreshControl;
        refreshControl.layer.zPosition += 1; // Make sure this appears on top of the table's background image
    }
    isExceedingMaxLocalNotifications = [[DataModel getInstance] isExceedingMaxLocalNotifications];
}

- (void)handleSync:(id)sender
{
    AccountType accountType = [DataModel getInstance].globalSettings.accountType;
    // Subscription-only feature
    if (accountType != AccountTypeSubscription)
    {
        if (refreshControl.refreshing)
            [refreshControl endRefreshing];        
    }
    else
    {
        DebugLog(@"manual sync start");

        [DataModel getInstance].syncNeeded = YES;
        [[DataModel getInstance] writeToFile:nil];
        [[LogManager sharedManager] startUploadLogsImmediately];
    }
}

- (void)handleSyncFail:(NSNotification *)notification
{
    if (refreshControl && refreshControl.refreshing)
    {
        NSString* errorMessage = (NSString*)notification.object;
        
        DebugLog(@"manual sync end, error (%@)", (errorMessage ? errorMessage : @"none"));

        [refreshControl endRefreshing];
        if (errorMessage)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorSyncTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Sync Error", @"The title on the alert appearing when a sync error occurs"])
                                                                                               message:errorMessage];
            [alert showInViewController:self];
        }
    }
}

- (void)handleSyncComplete:(NSNotification *)notification
{
    if (refreshControl && refreshControl.refreshing)
    {
        NSString* errorMessage = (NSString*)notification.object;
        
        DebugLog(@"manual sync end");

        [refreshControl endRefreshing];
        if (errorMessage)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorSyncTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Sync Error", @"The title on the alert appearing when a sync error occurs"])
                                                                                               message:errorMessage];
            [alert showInViewController:self];
        }
    }
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
    
    if ( animated)
        [drugImagesDictionary removeAllObjects];
    
    [self refreshDrugList];
    [self updateTabBarItemBadge];
    [self.tableView reloadData];
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];

    pillNotificationManager.canRefreshDrugState = YES;
			
	// Update the drug list if it is stale
	if (pillNotificationManager.needsRefreshDrugState)
        [[PillNotificationManager getInstance] refreshDrugState:NO];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    
    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];
    pillNotificationManager.canRefreshDrugState = NO;
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

- (void)handleDrugEdited
{
}

- (void)handleHistoryEditedNotification:(NSNotification *)notification
{
    if (!isDeletingFromThisController)
    {
        [drugImagesDictionary removeAllObjects];

        // Reload all cells in case, after the history was edited, we need to refresh drugs that have dose limits set
        [self refreshDrugList];
        [self updateTabBarItemBadge];
        [self.tableView reloadData];
    }
}

- (BOOL) managedDrugHasUpdate:(Drug*)d
{
    if ([d isManaged])
    {
        ManagedDrugDosage* managedDrugDosage = (ManagedDrugDosage*)d.dosage;
        // Ignore archived meds
        return (([managedDrugDosage requiresUserNotification] || [managedDrugDosage isNew] || managedDrugDosage.isDiscontinued) && !d.reminder.invisible);
    }
    else
        return NO;
}

// Returns whether to display group names
- (BOOL) displayGroupNames
{
    DataModel* dataModel = [DataModel getInstance];
    
    if ([self doManagedDrugUpdatesExist])
        return YES;
    
    // See if any archived drugs exist
    for (Drug* d in drugList)
    {
        if (d.reminder.archived)
            return YES;
    }

    return ([[dataModel.globalSettings.personNames allGuids] count] > 0);
}

// Returns the group name for the group containing the given drug
- (NSString*)getGroupNameForGroupContainingDrug:(Drug*)drug
{
    if (![self displayGroupNames])
        return nil;
    
    if ([self managedDrugHasUpdate:drug])
        return NSLocalizedStringWithDefaultValue(@"ViewDrugsManagedDrugUpdatesSectionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Updates", @"The title of the managed drug updates section in the drugs view"]);

    if (drug.reminder.archived)
        return NSLocalizedStringWithDefaultValue(@"ViewDrugsArchivedDrugsSectionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Archived", @"The title of the archived drugs section in the drugs view"]);
    
    DataModel* dataModel = [DataModel getInstance];

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
    else if ([self doManagedDrugUpdatesExist])
        return NSLocalizedStringWithDefaultValue(@"ViewDrugsCurrentDrugsSectionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Current", @"The title of the current drugs section in the drugs view"]);
    else
        return nil;
}

// Updates the list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
- (void)updateGroupIndicesForDrugList
{
    [drugListGroupIndices removeAllObjects];
        
    if ([self displayGroupNames])
    {
        NSString* lastGroupName = nil;
        
        int numDrugs = (int)[drugList count];
        for (int i = 0; i < numDrugs; i++)
        {
            Drug* d = [drugList objectAtIndex:i];
            NSString* thisGroupName = [self getGroupNameForGroupContainingDrug:d];
            if ((!lastGroupName && thisGroupName) ||
                (lastGroupName && !thisGroupName) ||
                (lastGroupName  && thisGroupName && [lastGroupName compare:thisGroupName options:NSLiteralSearch] != NSOrderedSame))
            {
                [drugListGroupIndices addObject:[NSNumber numberWithInt:i]];
                lastGroupName = thisGroupName;
            }
            else if (i == 0)
                [drugListGroupIndices addObject:[NSNumber numberWithInt:0]];
        }
    }
    else if ([drugList count] > 0)
        [drugListGroupIndices addObject:[NSNumber numberWithInt:0]];    
}

// Function to compare two drugs' names
NSComparisonResult compareDosecastDrugName(Drug* d1, Drug* d2, void* context)
{
    DosecastDrugsViewController* controller = (__bridge DosecastDrugsViewController*)context;

    // Make sure managed updates come first
    BOOL d1ManagedUpdate = [controller managedDrugHasUpdate:d1];
    BOOL d2ManagedUpdate = [controller managedDrugHasUpdate:d2];
    
    if (d1ManagedUpdate && !d2ManagedUpdate)
        return NSOrderedAscending;
    else if (!d1ManagedUpdate && d2ManagedUpdate)
        return NSOrderedDescending;
    else if (!d1.reminder.archived && d2.reminder.archived)
        return NSOrderedAscending;
    else if (d1.reminder.archived && !d2.reminder.archived)
        return NSOrderedDescending;
    else
        return [d1.name compare:d2.name options:NSLiteralSearch];
}

- (void)refreshDrugList
{
    DataModel* dataModel = [DataModel getInstance];
    NSArray* fullDrugList = [dataModel.drugList sortedArrayUsingFunction:compareDosecastDrugName context:(__bridge void*)self];
	[drugList removeAllObjects];
    
    // Filter out any archived and/or discontinued meds
    for (Drug* d in fullDrugList)
    {
        if (!d.reminder.invisible && (!d.reminder.archived || dataModel.globalSettings.archivedDrugsDisplayed))
            [drugList addObject:d];
    }
    
    [self updateGroupIndicesForDrugList];
}

#pragma mark Table view methods

- (Drug*) getDrugForCellAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger section = indexPath.section;
    if (isExceedingMaxLocalNotifications)
        section -= 1;
    int drugIndex = [((NSNumber*)[drugListGroupIndices objectAtIndex:section]) intValue] + (int)indexPath.row;
    return [drugList objectAtIndex:drugIndex];
}

- (int) getNumRowsInSection:(int)section
{
    if (isExceedingMaxLocalNotifications)
        section -= 1;

    // Calculate the start & end indixes for this section
    int drugIndexStart = [((NSNumber*)[drugListGroupIndices objectAtIndex:section]) intValue];
    int drugIndexEnd = -1;
    if (section == [drugListGroupIndices count]-1)
        drugIndexEnd = (int)[drugList count]-1;
    else
        drugIndexEnd = [((NSNumber*)[drugListGroupIndices objectAtIndex:section+1]) intValue]-1;
    
    return drugIndexEnd-drugIndexStart+1;
}

- (BOOL) doManagedDrugUpdatesExist
{
    // All managed drug updates are sorted first. See if any exist by looking at the first drug.
    return ([drugList count] > 0 && [self managedDrugHasUpdate:((Drug*)[drugList firstObject])]);
}

- (int) getNumSectionsForDrugListGroupIndices:(NSArray*)thisDrugListGroupIndices
{
    if ([thisDrugListGroupIndices count] > 0)
        return (int)[thisDrugListGroupIndices count];
    else
        return 1;
}

- (CGFloat) getHeightForCellLabelTag:(int)tag labelBaseHeight:(float)labelBaseHeight withString:(NSString*)value
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (isExceedingMaxLocalNotifications && indexPath.section == 0)
        return 52;
    else
    {
        Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
        
        CGFloat cellHeight = examplePillTableViewCell.frame.size.height;
        
        CGFloat nameHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:DRUGNAME_LABEL_BASE_HEIGHT withString:drug.name];
        cellHeight += (nameHeight - DRUGNAME_LABEL_BASE_HEIGHT);
        
        NSString* warningMessages = [self getWarningMessagesForDrug:drug];
        CGFloat warningHeight = [self getHeightForCellLabelTag:11 labelBaseHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];
        cellHeight += (warningHeight - WARNING_LABEL_BASE_HEIGHT);
        
        NSString* dosage = [drug.dosage getDescriptionForDrugDose:nil];
        if ([dosage length] > 0)
        {
            CGFloat dosageHeight = [self getHeightForCellLabelTag:200 labelBaseHeight:DOSAGE_LABEL_BASE_HEIGHT withString:dosage];
            cellHeight += (dosageHeight - DOSAGE_LABEL_BASE_HEIGHT);
        }
        
        CGFloat directionsHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DIRECTIONS_LABEL_BASE_HEIGHT withString:drug.directions];
        cellHeight += (directionsHeight - DIRECTIONS_LABEL_BASE_HEIGHT);

        return cellHeight;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return nil;
	else if ([drugListGroupIndices count] == 0)
        return nil;
    else
    {
        Drug* d = [self getDrugForCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
        return [self getGroupNameForGroupContainingDrug:d];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return nil;
	else if ([drugListGroupIndices count] == 0)
    {
		return NSLocalizedStringWithDefaultValue(@"ViewMainNoDrugsMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"No drugs have been added. To add a new drug, touch the + button.", @"The message appearing in the main view when no drugs have been added"]);
    }
	else
		return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];
    int numSections = [self getNumSectionsForDrugListGroupIndices:drugListGroupIndices];
    if (isExceedingMaxLocalNotifications)
        numSections += 1;
    return numSections;

}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return 1;
	else if ([drugListGroupIndices count] == 0)
        return 0;
    else
        return [self getNumRowsInSection:(int)section];
}

-(NSString*) getWarningMessagesForDrug:(Drug*)drug
{
    NSMutableString* warningMessages = [NSMutableString stringWithString:@""];
    DataModel* dataModel = [DataModel getInstance];
    
    if ([drug wouldExceedDoseLimitIfTakenAtDate:[NSDate date] nextAvailableDoseTime:nil])
    {
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
        [warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewDrugViewMaxDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Max doses taken", @"The Max Doses Taken label in the Drug View view"])];
    }
    if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [drug isEmpty])
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningEmpty", @"Dosecast", [DosecastUtil getResourceBundle], @"Empty", @"The Empty warning in the main view for a particular drug when there is no quantity remaining"])];
	}
	else if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [drug isRunningLow])
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningRunningLow", @"Dosecast", [DosecastUtil getResourceBundle], @"Running low", @"The Running Low warning in the main view for a particular drug when the quantity remaining is running low"])];
	}
    if ([drug.reminder isExpired])
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningExpired", @"Dosecast", [DosecastUtil getResourceBundle], @"Expired", @"The Expired warning in the main view for a particular drug when the expiration date has passed"])];
	}
	else if ([drug.reminder isExpiringSoon])
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningExpiringSoon", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiring soon", @"The Expiring Soon warning in the main view for a particular drug when the expiration date is approaching"])];
	}
    
    return warningMessages;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (isExceedingMaxLocalNotifications && indexPath.section == 0)
    {
        UIView* containerView = [localNotificationWarningCell viewWithTag:1];
        localNotificationWarningCell.backgroundColor = [DosecastUtil getDrugWarningLabelColor];
        UILabel* label = (UILabel*)[containerView viewWithTag:2];
        label.text = NSLocalizedStringWithDefaultValue(@"ErrorNoLocalNotificationsLeftWarning", @"Dosecast", [DosecastUtil getResourceBundle], @"This device can't deliver all the dose reminders for your drugs. To fix this, tap here.", @"The message of the alert appearing when there are no more local notifications left"]);
        return localNotificationWarningCell;
    }
    else
    {
        static NSString *MyIdentifier = @"PillCellIdentifier";
        
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
        if (cell == nil) {
            [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugsViewPillTableViewCell" owner:self options:nil];
            
            cell = pillTableViewCell;
            pillTableViewCell = nil;
        }
        
        // Configure the cell.
        
        Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
        
        UIColor* normalTextColor = (drug.reminder.archived ? [UIColor lightGrayColor] : [UIColor blackColor]);
        UIColor* warningTextColor = (drug.reminder.archived ? [UIColor lightGrayColor] : [DosecastUtil getDrugWarningLabelColor]);
        BOOL showDrugImages = [DataModel getInstance].globalSettings.drugImagesDisplayed;
        
        CGFloat drugImageLeftEdge = [cell viewWithTag:100].frame.origin.x;
        CGFloat drugImageWidthAndMargin = [cell viewWithTag:1].frame.origin.x - drugImageLeftEdge;

        // Set the drug label
        UILabel* drugNameLabel = (UILabel *)[cell viewWithTag:1];
        drugNameLabel.text = drug.name;
        drugNameLabel.textColor = normalTextColor;
        
        CGFloat nameHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:DRUGNAME_LABEL_BASE_HEIGHT withString:drug.name];
        drugNameLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:1].frame.origin.x : drugImageLeftEdge,
                                         drugNameLabel.frame.origin.y,
                                         showDrugImages ? [examplePillTableViewCell viewWithTag:1].frame.size.width : [examplePillTableViewCell viewWithTag:1].frame.size.width + drugImageWidthAndMargin,
                                         (int)ceilf(nameHeight));
        CGFloat shiftY = (nameHeight - DRUGNAME_LABEL_BASE_HEIGHT);
           
        UIImageView* warningImage = (UIImageView *)[cell viewWithTag:300];
        UILabel* warningLabel = (UILabel *)[cell viewWithTag:11];
        BOOL allowWarningImageDisplay = !drug.reminder.archived;
        NSString* warningMessages = [self getWarningMessagesForDrug:drug];
        
        if ([warningMessages length] > 0 && (warningLabel || warningImage))
        {
            CGFloat warningLabelHeight = [self getHeightForCellLabelTag:11 labelBaseHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];

            if (warningLabel)
            {
                warningLabel.hidden = NO;
                warningLabel.textColor = warningTextColor;
                warningLabel.text = warningMessages;
                
                warningLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.origin.x : drugImageLeftEdge + ([examplePillTableViewCell viewWithTag:11].frame.origin.x - [examplePillTableViewCell viewWithTag:300].frame.origin.x),
                                                (int)ceilf([examplePillTableViewCell viewWithTag:11].frame.origin.y + shiftY),
                                                showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.size.width : [examplePillTableViewCell viewWithTag:11].frame.size.width + drugImageWidthAndMargin,
                                                (int)ceilf(warningLabelHeight));
            }
            
            if (warningImage)
            {
                warningImage.hidden = !allowWarningImageDisplay;
                warningImage.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:300].frame.origin.x : drugImageLeftEdge,
                                                (warningLabel.frame.origin.y + warningLabel.frame.size.height/2) - warningImage.frame.size.height/2,
                                                warningImage.frame.size.width,
                                                warningImage.frame.size.height);
            }
            
            shiftY += (warningLabelHeight - WARNING_LABEL_BASE_HEIGHT);
        }
        else
        {
            if (warningImage)
                warningImage.hidden = YES;
            warningLabel.hidden = YES;
        }
        
        // Determine whether to display the unread/discontinued icons for managed drugs
        UIImageView *unreadIcon = (UIImageView *)[cell viewWithTag:3];

        if ([drug isManaged])
        {
            ManagedDrugDosage* managedDrugDosage = (ManagedDrugDosage*)drug.dosage;
            if (managedDrugDosage.isDiscontinued)
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.editingAccessoryType = UITableViewCellAccessoryNone;
                unreadIcon.hidden = NO;
                
                unreadIcon.backgroundColor = [UIColor clearColor];
                unreadIcon.image = [UIImage imageWithContentsOfFile:
                                    [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/ManagedDiscontinuedIcon.png"]];
            }
            else if ([managedDrugDosage requiresUserNotification] || [managedDrugDosage isNew])
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.editingAccessoryType = UITableViewCellAccessoryNone;
                unreadIcon.hidden = NO;
                
                unreadIcon.backgroundColor = [UIColor clearColor];
                unreadIcon.image = [UIImage imageWithContentsOfFile:
                                    [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/ManagedUnreadIcon.png"]];
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
                unreadIcon.hidden = YES;
            }
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            unreadIcon.hidden = YES;
        }
        
        // Set the drug dosage, route, etc. label.
        
        UILabel *drugDosageAndRouteLabel = (UILabel *)[cell viewWithTag:200];
        NSString* dosageDescription = [drug.dosage getDescriptionForDrugDose:nil];
        if ([dosageDescription length] > 0)
        {
            drugDosageAndRouteLabel.hidden = NO;
            CGFloat dosageHeight = [self getHeightForCellLabelTag:200 labelBaseHeight:DOSAGE_LABEL_BASE_HEIGHT withString:dosageDescription];
            drugDosageAndRouteLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:200].frame.origin.x : drugImageLeftEdge,
                                                       (int)ceilf([examplePillTableViewCell viewWithTag:200].frame.origin.y + shiftY),
                                                       showDrugImages ? [examplePillTableViewCell viewWithTag:200].frame.size.width : [examplePillTableViewCell viewWithTag:200].frame.size.width + drugImageWidthAndMargin,
                                                       (int)ceilf(dosageHeight));

            drugDosageAndRouteLabel.text = dosageDescription;
            drugDosageAndRouteLabel.textColor = normalTextColor;
            
            shiftY += (dosageHeight - DOSAGE_LABEL_BASE_HEIGHT);
        }
        else
            drugDosageAndRouteLabel.hidden = YES;
        
        UIImageView *notesIcon = (UIImageView *)[cell viewWithTag:44];
        notesIcon.hidden = ((!drug.notes || [[drug.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) &&
                            (!drug.directions || [[drug.directions stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0));
        
        UILabel* directionsLabel = (UILabel *)[cell viewWithTag:2];
        CGFloat directionsHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DIRECTIONS_LABEL_BASE_HEIGHT withString:drug.directions];

        directionsLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:2].frame.origin.x : drugImageLeftEdge,
                                           (int)ceilf([examplePillTableViewCell viewWithTag:2].frame.origin.y + shiftY),
                                           showDrugImages ? [examplePillTableViewCell viewWithTag:2].frame.size.width : [examplePillTableViewCell viewWithTag:2].frame.size.width + drugImageWidthAndMargin,
                                           (int)ceilf(directionsHeight));
        directionsLabel.text = drug.directions;
        directionsLabel.textColor = normalTextColor;
        
        shiftY += (directionsHeight - DIRECTIONS_LABEL_BASE_HEIGHT);

        UIImageView *drugThumbnailImageView = (UIImageView *)[cell viewWithTag:100];
        drugThumbnailImageView.backgroundColor = [DosecastUtil getDrugImagePlaceholderColor];
        drugThumbnailImageView.image = nil;
        drugThumbnailImageView.hidden = !showDrugImages;
        
        UIActivityIndicatorView *activity = (UIActivityIndicatorView *)[cell viewWithTag:1000];
        activity.hidden = !showDrugImages || drug.drugImageGUID.length == 0;
        activity.layer.zPosition += 1; // Make sure this appears on top of everything else

        UILabel *noDrugImageLabel = (UILabel *)[cell viewWithTag:20];
        noDrugImageLabel.text = NSLocalizedStringWithDefaultValue(@"NoDrugImagePlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"No drug image", @"The default placeholder string when no image has been set throughout the client "]);
        noDrugImageLabel.hidden = !showDrugImages;
        
        if (showDrugImages)
        {
            if (drug.drugImageGUID.length > 0 )
            {
                [activity startAnimating];

                // Check if image has already been fetched from disk.
                
                if ( [[drugImagesDictionary allKeys] containsObject:drug.drugImageGUID] )
                {
                    // The image has already been fetched once
                    
                    UIImage *drugImage = [drugImagesDictionary objectForKey:drug.drugImageGUID];
                    
                    if ( [drugImagesDictionary objectForKey:drug.drugImageGUID] == [NSNull null] )
                    {
                        BOOL hasPlaceholderImage = self.drugPlaceholderImageView.image != nil;
                        
                        drugThumbnailImageView.image = hasPlaceholderImage ? self.drugPlaceholderImageView.image : nil;
                        noDrugImageLabel.hidden = hasPlaceholderImage;
                    }
                    else
                    {
                        drugThumbnailImageView.image = drugImage;
                        noDrugImageLabel.hidden = YES;
                    }
                    
                    [activity stopAnimating];
                }
                else
                {
                    // The image has not yet been fetched.
                    
                    // We'll need to do so. If the image exists, place it in a dictionary to
                    // improve scrolling performance and minimize database fetching.
                    
                    DrugImageManager *manager = [DrugImageManager sharedManager];

                    BOOL imageExists = [manager doesImageExistForImageGUID:drug.drugImageGUID];
                    
                    if ( imageExists )
                    {
                        [activity stopAnimating];

                        UIImage *returnedDrugImage = [manager imageForImageGUID:drug.drugImageGUID];
                        
                        if ( returnedDrugImage )
                            [drugImagesDictionary setObject:returnedDrugImage forKey:drug.drugImageGUID];
                        else
                            [drugImagesDictionary setObject:[NSNull null] forKey:drug.drugImageGUID];
                        
                        drugThumbnailImageView.image = returnedDrugImage;
                        noDrugImageLabel.hidden = returnedDrugImage != nil;
                    }
                    else
                    {
                        // Let the activity indicator continue to animate until the image is loaded and exists
                        
                        [drugImagesDictionary setObject:[NSNull null] forKey:drug.drugImageGUID];

                        BOOL hasPlaceholderImage = self.drugPlaceholderImageView.image != nil;
                        
                        drugThumbnailImageView.image = hasPlaceholderImage ? self.drugPlaceholderImageView.image : nil;
                        noDrugImageLabel.hidden = hasPlaceholderImage;
                    }
                }
            }
            else
            {
                // Default behavior if a drug has no drug image GUID
                
                BOOL hasPlaceholderImage = self.drugPlaceholderImageView.image != nil;
                
                drugThumbnailImageView.image = hasPlaceholderImage ? self.drugPlaceholderImageView.image : nil;
                
                noDrugImageLabel.hidden = hasPlaceholderImage;
            }
        }
        
        return cell;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	   
    if (isExceedingMaxLocalNotifications && indexPath.section == 0)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorNoLocalNotificationsLeftMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The message of the alert appearing when there are no more local notifications left"])];
        [alert showInViewController:self];
    }
    else
    {
        Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
        
        // Handle tapping on a discontinued med
        if ([drug isManaged] && ((ManagedDrugDosage*)drug.dosage).isDiscontinued)
        {
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugDiscontinuedManagedDrugTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Discontinued", @"The notification text to display in the Drug View view for discontinued managed drugs"])
                                                                                       message:NSLocalizedStringWithDefaultValue(@"ViewDrugDiscontinuedManagedDrugNotification", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug was discontinued by your doctor and will be removed.", @"The notification text to display in the Drug View view for discontinued managed drugs"])
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonRemove", @"Dosecast", [DosecastUtil getResourceBundle], @"Remove Drug", @"The text on the Remove button in a confirmation action sheet in the Drug Edit view"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction* action) {
                                              Drug* d = [[DataModel getInstance] findDrugWithId:discontinuedDrugId];
                                              
                                              DrugReminder* newReminder = [d.reminder mutableCopy];
                                              newReminder.invisible = YES;
                                              
                                              [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerEditingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Editing drug", @"The message appearing in the spinner view when editing a drug"])];
                                              
                                              [[LocalNotificationManager getInstance] editPill:d.drugId
                                                                                      drugName:d.name
                                                                                     imageGUID:d.drugImageGUID
                                                                                      personId:d.personId
                                                                                    directions:d.directions
                                                                                 doctorContact:d.doctorContact
                                                                               pharmacyContact:d.pharmacyContact
                                                                               prescriptionNum:d.prescriptionNum
                                                                                  drugReminder:newReminder
                                                                                    drugDosage:d.dosage
                                                                                         notes:d.notes
                                                                          undoHistoryEventGUID:d.undoHistoryEventGUID
                                                                                  updateServer:YES
                                                                                     respondTo:self
                                                                                         async:YES];
                                              
                                              discontinuedDrugId = nil;
                                          }]];
            
            [alert showInViewController:self];

            discontinuedDrugId = drug.drugId;
        }
        else
        {
            // Set Back button title
            NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
            UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
            backButton.style = UIBarButtonItemStylePlain;
            if (!backButton.image)
                backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
            self.navigationItem.backBarButtonItem = backButton;
            
            // Display DrugViewController in new view
            DrugViewController* drugController = [[DrugViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugViewController"]
                                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                                      drugId:drug.drugId
                                                                                    viewDate:[NSDate date]
                                                                                allowEditing:YES
                                                                                    delegate:self];
            [self.navigationController pushViewController:drugController animated:YES];
        }
    }
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}


- (void) didEndEditingRowAtIndexPathAsync:(NSIndexPath*)indexPath
{    
    [[LogManager sharedManager] endPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    __unsafe_unretained NSIndexPath* indexP = indexPath;
	
	// Call the async method
	SEL asyncMethod = @selector(didEndEditingRowAtIndexPathAsync:);
	NSMethodSignature * mySignature = [DosecastDrugsViewController instanceMethodSignatureForSelector:asyncMethod];
	NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
	[myInvocation setTarget:self];
	[myInvocation setSelector:asyncMethod];
	[myInvocation setArgument:&indexP atIndex:2];
	[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY_ON_UNSWIPE invocation:myInvocation repeats:NO];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        DataModel* dataModel = [DataModel getInstance];
		deletedIndexPath = indexPath;
        [preDeletedDrugListGroupIndices setArray:drugListGroupIndices];
        deletedLastRowInSection = ([self getNumRowsInSection:(int)deletedIndexPath.section] == 1);
        
        if (deletedLastRowInSection && [self getNumSectionsForDrugListGroupIndices:drugListGroupIndices] == 1)
            deletedLastSection = YES;
        else
            deletedLastSection = NO;

        Drug* d = [self getDrugForCellAtIndexPath:deletedIndexPath];
                
        // If any history exists (and it's a premium edition), ask the user what they want to do with it
        if ([[HistoryManager getInstance] eventsExistForDrugId:d.drugId] && dataModel.globalSettings.accountType != AccountTypeDemo)
        {
            if (d.reminder.archived)
            {
                DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmArchivedDrugDeleteTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The title on the confirmation alert when deleting an archived drug the Drug Edit view"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmArchivedDrugDeleteMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Warning: if you delete this drug, all dose history will be deleted. Are you sure you want to delete this drug?", @"The message on the confirmation alert when deleting an archived drug the Drug Edit view"])
                                                                                             style:DosecastAlertControllerStyleAlert];
                
                
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                                style:DosecastAlertActionStyleCancel
                                              handler:^(DosecastAlertAction* action){
                                                  [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:deletedIndexPath] withRowAnimation:UITableViewRowAnimationNone]; // redraw the cell if the user cancels
                                                  deletedIndexPath = nil;
                                                  deletedLastRowInSection = NO;
                                                  [preDeletedDrugListGroupIndices removeAllObjects];
                                                  deletedLastSection = NO;
                                              }]];
                
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"])
                                                style:DosecastAlertActionStyleDefault
                                              handler:^(DosecastAlertAction *action){
                                                  Drug* d = [self getDrugForCellAtIndexPath:deletedIndexPath];
                                                  
                                                  [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting drug", @"The message appearing in the spinner view when deleting a drug"])];
                                                  
                                                  // Remove the drug image from the dictionary for the deleted drug
                                                  if (d.drugImageGUID && [d.drugImageGUID length] > 0 && [[drugImagesDictionary allKeys] containsObject:d.drugImageGUID] )
                                                      [drugImagesDictionary removeObjectForKey:d.drugImageGUID];
                                                  
                                                  isDeletingFromThisController = YES;
                                                  
                                                  [[LocalNotificationManager getInstance] deletePill:d.drugId
                                                                                        updateServer:YES
                                                                                           respondTo:self
                                                                                               async:YES];
                                              }]];
                
                [alert showInViewController:self];
            }
            else
            {
                DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmNonArchivedDrugDeleteTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The title on the confirmation alert when deleting a non-archived drug the Drug Edit view"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmNonArchivedDrugDeleteMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Warning: if you delete this drug, all dose history will be deleted. If you archive it, the dose history will be kept. What do you want to do?", @"The message on the confirmation alert when deleting a non-archived drug the Drug Edit view"])
                                                                                             style:DosecastAlertControllerStyleAlert];
                
                
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                                style:DosecastAlertActionStyleCancel
                                              handler:^(DosecastAlertAction* action){
                                                  [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:deletedIndexPath] withRowAnimation:UITableViewRowAnimationNone]; // redraw the cell if the user cancels
                                                  deletedIndexPath = nil;
                                                  deletedLastRowInSection = NO;
                                                  [preDeletedDrugListGroupIndices removeAllObjects];
                                                  deletedLastSection = NO;
                                              }]];
                
                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonArchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Archive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"])
                                                style:DosecastAlertActionStyleDefault
                                              handler:^(DosecastAlertAction *action){
                                                  [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:deletedIndexPath] withRowAnimation:UITableViewRowAnimationNone]; // redraw the cell if the user cancels
                                                  deletedLastRowInSection = NO;
                                                  [preDeletedDrugListGroupIndices removeAllObjects];
                                                  deletedLastSection = NO;
                                                  
                                                  Drug* d = [self getDrugForCellAtIndexPath:deletedIndexPath];
                                                  
                                                  DrugReminder* newReminder = [d.reminder mutableCopy];
                                                  newReminder.archived = YES;
                                                  
                                                  [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerEditingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Editing drug", @"The message appearing in the spinner view when editing a drug"])];
                                                  
                                                  [[LocalNotificationManager getInstance] editPill:d.drugId
                                                                                          drugName:d.name
                                                                                         imageGUID:d.drugImageGUID
                                                                                          personId:d.personId
                                                                                        directions:d.directions
                                                                                     doctorContact:d.doctorContact
                                                                                   pharmacyContact:d.pharmacyContact
                                                                                   prescriptionNum:d.prescriptionNum
                                                                                      drugReminder:newReminder
                                                                                        drugDosage:d.dosage
                                                                                             notes:d.notes
                                                                              undoHistoryEventGUID:d.undoHistoryEventGUID
                                                                                      updateServer:YES
                                                                                         respondTo:self
                                                                                             async:YES];
                                              }]];

                [alert addAction:
                 [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"])
                                                style:DosecastAlertActionStyleDefault
                                              handler:^(DosecastAlertAction *action){
                                                  Drug* d = [self getDrugForCellAtIndexPath:deletedIndexPath];
                                                  
                                                  [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting drug", @"The message appearing in the spinner view when deleting a drug"])];
                                                  
                                                  // Remove the drug image from the dictionary for the deleted drug
                                                  if (d.drugImageGUID && [d.drugImageGUID length] > 0 && [[drugImagesDictionary allKeys] containsObject:d.drugImageGUID] )
                                                      [drugImagesDictionary removeObjectForKey:d.drugImageGUID];
                                                  
                                                  isDeletingFromThisController = YES;
                                                  
                                                  [[LocalNotificationManager getInstance] deletePill:d.drugId
                                                                                        updateServer:YES
                                                                                           respondTo:self
                                                                                               async:YES];
                                              }]];

                [alert showInViewController:self];
            }
        }
        else
        {            
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting drug", @"The message appearing in the spinner view when deleting a drug"])];
            
            // Remove the drug image from the dictionary for the deleted drug
            if (d.drugImageGUID && [d.drugImageGUID length] > 0 && [[drugImagesDictionary allKeys] containsObject:d.drugImageGUID] )
                [drugImagesDictionary removeObjectForKey:d.drugImageGUID];

            isDeletingFromThisController = YES;

            [[LocalNotificationManager getInstance] deletePill:d.drugId
                                                  updateServer:YES
                                                     respondTo:self
                                                         async:YES];
        }
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (isExceedingMaxLocalNotifications && indexPath.section == 0)
        return UITableViewCellEditingStyleNone;
    else
    {
        Drug* d = [self getDrugForCellAtIndexPath:indexPath];
        if ([d isManaged])
            return UITableViewCellEditingStyleNone;
        else
            return UITableViewCellEditingStyleDelete;
    }
}

- (void)handleDrugDelete:(NSString*)drugId
{
    [drugImagesDictionary removeAllObjects];

    [self refreshDrugList];
    [self updateTabBarItemBadge];
	[tableView reloadData];
}

- (void)editPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
        deletedIndexPath = nil;
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Edit Drug", @"The message in the alert appearing in the Drug Edit view when editing a drug fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}	
}

- (void)deletePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];
	[dataModel allowDosecastUserInteractionsWithMessage:YES];
	
    isDeletingFromThisController = NO;
   
	if (result)
	{
        [self refreshDrugList];
        [self updateTabBarItemBadge];

		[self.tableView beginUpdates];
        if (deletedLastRowInSection)
        {
            if (deletedLastSection)
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:deletedIndexPath.section] withRowAnimation:UITableViewRowAnimationLeft];
            else
            {
                // Create a set of sections to delete. Start with the section for the deleted cell.
                NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSetWithIndex:deletedIndexPath.section];
                
                // See if 2 sections were merged. If so, handle this
                int preDeletedNumSections = [self getNumSectionsForDrugListGroupIndices:preDeletedDrugListGroupIndices];
                int postDeletedNumSections = [self getNumSectionsForDrugListGroupIndices:drugListGroupIndices];
                if ((preDeletedNumSections - postDeletedNumSections) > 1)
                {
                    // Also delete the prior section
                    [deletedSections addIndex:deletedIndexPath.section-1];
                    
                    // Also reload the next section
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:deletedIndexPath.section+1] withRowAnimation:UITableViewRowAnimationLeft];
                }
                
                [self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
            }
        }
        else
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:deletedIndexPath] withRowAnimation:UITableViewRowAnimationLeft];
        if (isExceedingMaxLocalNotifications && ![dataModel isExceedingMaxLocalNotifications])
        {
            isExceedingMaxLocalNotifications = NO;
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationLeft];
        }
		[self.tableView endUpdates];
		
		deletedIndexPath = nil;
        deletedLastRowInSection = NO;
        [preDeletedDrugListGroupIndices removeAllObjects];
        deletedLastSection = NO;
	}
	else
	{
		deletedIndexPath = nil;
        deletedLastRowInSection = NO;
        [preDeletedDrugListGroupIndices removeAllObjects];
        deletedLastSection = NO;

        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditDeleteFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Delete Drug", @"The message in the alert appearing in the Drug Edit view when deleting a drug fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}	
}

- (IBAction)handleAddDrug:(id)sender
{
	DrugAddEditViewController* drugAddEditController = [[DrugAddEditViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugAddEditViewController"]
																						   bundle:[DosecastUtil getResourceBundle]
																							 mode:DrugAddEditViewControllerModeAddDrug
																						   drugId:nil
                                                                               treatmentStartDate:nil
																						 delegate:nil];	
	[self.navigationController pushViewController:drugAddEditController animated:YES];
}

- (void)handleDrugImageRefresh:(NSNotification *)notification
{
    [drugImagesDictionary removeAllObjects];

    [self.tableView reloadData];
}

// Called whenever the data model (re)builds from JSON
- (void)handleDataModelRefresh:(NSNotification *)notification
{
    NSMutableDictionary* notificationDict = (NSMutableDictionary*)notification.object;
    NSSet* serverMethodCalls = nil;
    if (notificationDict)
        serverMethodCalls = [notificationDict objectForKey:DataModelDataRefreshNotificationServerMethodCallsKey];
    
	// Don't refresh the table if a delete is in progress. We'll handle the deletion explicitly with animation later.
	if (!isDeletingFromThisController || !serverMethodCalls || ![serverMethodCalls member:DeletePillMethodName])
	{
        [drugImagesDictionary removeAllObjects];

		// Refresh the table's data
        [self refreshDrugList];
        [self updateTabBarItemBadge];
        
        isExceedingMaxLocalNotifications = [[DataModel getInstance] isExceedingMaxLocalNotifications];

		[self.tableView reloadData];
		
        PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];

		// We just did a refresh - so reset the needsDrugListRefresh flag
		if (pillNotificationManager.needsRefreshDrugState)
			pillNotificationManager.needsRefreshDrugState = NO;		
	}
}

- (void)updateTabBarItemBadge
{
    int numManagedDrugUpdates = 0;
    
    for (Drug* d in drugList)
    {
        if ([self managedDrugHasUpdate:d])
            numManagedDrugUpdates += 1;
    }

    // If this view controller is one tab of many, set the badge on the tab bar icon to the number of updates
    if (self.navigationController && self.navigationController.tabBarItem)
    {
        NSString* badgeValue = nil;
        if (numManagedDrugUpdates > 0)
            badgeValue = [NSString stringWithFormat:@"%d", numManagedDrugUpdates];
        self.navigationController.tabBarItem.badgeValue = badgeValue;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return SECTION_EMPTY_HEADER_HEIGHT;
    else if ([self displayGroupNames])
    {
        if ([drugListGroupIndices count] == 0)
            return SECTION_EMPTY_HEADER_HEIGHT;
        else
        {
            Drug* d = [self getDrugForCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
            NSString* groupName = [self getGroupNameForGroupContainingDrug:d];
            if (groupName)
                return SECTION_NONEMPTY_HEADER_HEIGHT;
            else
                return SECTION_EMPTY_HEADER_HEIGHT;
        }
    }
    else
        return SECTION_EMPTY_HEADER_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return SECTION_NONEMPTY_FOOTER_HEIGHT;
	else if ([drugListGroupIndices count] == 0)
        return SECTION_EMPTY_FOOTER_HEIGHT;
    else
        return SECTION_NONEMPTY_FOOTER_HEIGHT;
}

@end

