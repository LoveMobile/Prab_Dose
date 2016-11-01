//
//  DosecastMainViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DosecastMainViewController.h"
#import "DataModel.h"
#import "DrugViewController.h"
#import "DrugAddEditViewController.h"
#import "PillNotificationManager.h"
#import "Drug.h"

#import "DosecastUtil.h"
#import "ScheduledDrugReminder.h"
#import "IntervalDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "DrugHistoryViewController.h"
#import "LocalNotificationManager.h"
#import "HistoryManager.h"
#import "HistoryEvent.h"
#import "CustomNameIDList.h"
#import "SettingsViewController.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DrugImageManager.h"
#import "GlobalSettings.h"
#import "AccountViewController.h"
#import "LogManager.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const double ASYNC_TIME_DELAY_ON_UNSWIPE = 0.01;
static const int SECTION_EMPTY_HEADER_HEIGHT = 8;
static const int SECTION_NONEMPTY_HEADER_HEIGHT = 32;
static const int SECTION_NONEMPTY_FOOTER_HEIGHT = 8;
static const int SECTION_EMPTY_FOOTER_HEIGHT = 100;
static const int DRUG_ACTION_BUTTON_HEIGHT = 30;
static const CGFloat DRUGNAME_LABEL_BASE_HEIGHT = 18.0f;
static const CGFloat DOSAGE_LABEL_BASE_HEIGHT = 16.0f;
static const CGFloat WARNING_LABEL_BASE_HEIGHT = 16.0f;
static const CGFloat NEXTDOSE_LABEL_BASE_HEIGHT = 15.0f;

static const double SEC_PER_HOUR = 60*60;

static NSString *DeletePillMethodName = @"deletePill";
static DosecastMainViewController *gInstance = nil;

@implementation DosecastMainViewController

@synthesize pillTableViewCell;
@synthesize localNotificationWarningCell;
@synthesize drugPlaceholderImageView;
@synthesize tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.title = [DosecastUtil getProductComponentName];

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        wouldExceedDoseLimitIfTakenDict = [[NSMutableDictionary alloc] init];
        nextAvailableDoseTimeDict = [[NSMutableDictionary alloc] init];
        deletedIndexPath = nil;
        undoDrugId = nil;
        checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = NO;
        drugIdsWithScheduledDosesAlreadyAtDoseLimit = [[NSMutableArray alloc] init];
        drugListGroupIndices = [[NSMutableArray alloc] init];
        drugList = [[NSMutableArray alloc] init];
        examplePillTableViewCell = nil;
        buttonMinimumScaleFactor = -1.0;
        isExceedingMaxLocalNotifications = NO;
        
        DataModel* dataModel = [DataModel getInstance];
        self.hidesBottomBarWhenPushed = ![dataModel.apiFlags getFlag:DosecastAPIShowMainToolbar];

        deletedLastRowInSection = NO;
        deletedLastSection = NO;
        isDeletingFromThisController = NO;
        preDeletedDrugListGroupIndices = [[NSMutableArray alloc] init];
        drugImagesDictionary = [[NSMutableDictionary alloc] init];
        
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
        
        tableViewController = nil;
        refreshControl = nil;
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
    self.tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

    // Set add button
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(handleAddDrug:)];
	self.navigationItem.rightBarButtonItem = addButton;
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"MainViewPillTableViewCell" owner:self options:nil];
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

- (void) recalcWouldExceedDoseLimitIfTakenDict
{
    [wouldExceedDoseLimitIfTakenDict removeAllObjects];
    [nextAvailableDoseTimeDict removeAllObjects];
    
    DataModel* dataModel = [DataModel getInstance];
    NSDate* now = [NSDate date];
    for (Drug* d in dataModel.drugList)
    {
        NSDate* nextAvailableDoseTime = nil;

        NSNumber* resultNum = [NSNumber numberWithBool:
                              [d wouldExceedDoseLimitIfTakenAtDate:now nextAvailableDoseTime:&nextAvailableDoseTime]];
        [wouldExceedDoseLimitIfTakenDict setObject:resultNum forKey:d.drugId];
        if (nextAvailableDoseTime)
            [nextAvailableDoseTimeDict setObject:nextAvailableDoseTime forKey:d.drugId];
    }
}

- (void) getDoseLimitStateForDrug:(NSString*)drugId
      wouldExceedDoseLimitIfTaken:(BOOL*)wouldExceedDoseLimitIfTaken
            nextAvailableDoseTime:(NSDate**)nextAvailableDoseTime
{
    *wouldExceedDoseLimitIfTaken = NO;
    *nextAvailableDoseTime = nil;

    NSNumber* wouldExceedDoseLimitIfTakenNum = [wouldExceedDoseLimitIfTakenDict objectForKey:drugId];
    if (wouldExceedDoseLimitIfTakenNum)
        *wouldExceedDoseLimitIfTaken = [wouldExceedDoseLimitIfTakenNum boolValue];
    *nextAvailableDoseTime = [nextAvailableDoseTimeDict objectForKey:drugId];
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
    {
        [drugImagesDictionary removeAllObjects];

        [self.tableView reloadData];
    }
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (void) handleCheckForDrugsWithScheduledDosesAlreadyAtDoseLimit
{
    checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = NO;
    
    int numDrugs = (int)[drugList count];
    [drugIdsWithScheduledDosesAlreadyAtDoseLimit removeAllObjects];
    NSMutableString* drugNamesWithScheduledDosesAlreadyAtDoseLimit = [NSMutableString stringWithString:@""];
    
    // Check for drugs with scheduled doses that are already at their dose limit
    for (int i = 0; i < numDrugs; i++)
    {
        Drug* d = [drugList objectAtIndex:i];
        if ([d isExceedingDoseLimit])
        {
            [drugIdsWithScheduledDosesAlreadyAtDoseLimit addObject:d.drugId];
            if ([drugNamesWithScheduledDosesAlreadyAtDoseLimit length] > 0)
                [drugNamesWithScheduledDosesAlreadyAtDoseLimit appendString:@"\n"];
            [drugNamesWithScheduledDosesAlreadyAtDoseLimit appendString:d.name];
        }
    }

    if ([drugIdsWithScheduledDosesAlreadyAtDoseLimit count] == 1)
    {
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSLocalizedStringWithDefaultValue(@"ViewDrugViewMaxDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Max doses taken", @"The Max Doses Taken label in the Drug View view"]) capitalizedString]
                                                                                   message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainDrugsWithScheduledDosesAlreadyAtLimitMessageSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"You've already taken your maximum number of doses of %@, but an additional dose is scheduled. Your next scheduled dose will automatically be skipped.", @"The message appearing in the main view when drugs exist with scheduled doses that are already at their dose limit"]), drugNamesWithScheduledDosesAlreadyAtDoseLimit]
                                                                                     style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction* action){
                                          // Skip dem pills
                                          [[PillNotificationManager getInstance] performSkipPills:drugIdsWithScheduledDosesAlreadyAtDoseLimit displayActions:NO sourceButton:nil];
                                      }]];
        
        [alert showInViewController:self];        
    }
    else if ([drugIdsWithScheduledDosesAlreadyAtDoseLimit count] > 1)
    {
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:[NSLocalizedStringWithDefaultValue(@"ViewDrugViewMaxDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Max doses taken", @"The Max Doses Taken label in the Drug View view"]) capitalizedString]
                                                                                   message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainDrugsWithScheduledDosesAlreadyAtLimitMessagePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"You've already taken your maximum number of doses for the drugs below, but additional doses are scheduled.\n\n%@\n\nYour next scheduled doses will automatically be skipped.", @"The message appearing in the main view when drugs exist with scheduled doses that are already at their dose limit"]), drugNamesWithScheduledDosesAlreadyAtDoseLimit]
                                                                                     style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction* action){
                                          // Skip dem pills
                                          [[PillNotificationManager getInstance] performSkipPills:drugIdsWithScheduledDosesAlreadyAtDoseLimit displayActions:NO sourceButton:nil];
                                      }]];
        
        [alert showInViewController:self];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];

    pillNotificationManager.canRefreshDrugState = YES;
			
	// Update the drug list if it is stale
	if (pillNotificationManager.needsRefreshDrugState)
        [[PillNotificationManager getInstance] refreshDrugState:NO];
    // If we need to check for drugs with scheduled doses that are already at their dose limit, do so now.
    else if (checkForDrugsWithScheduledDosesAlreadyAtDoseLimit)
        [self handleCheckForDrugsWithScheduledDosesAlreadyAtDoseLimit];
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
    // The user may have edited down the max number of doses so that some drugs are already scheduled above their dose limits. Check for this.
    checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = YES;
    [self.tableView reloadData];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
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

// Returns whether to display group names
- (BOOL) displayGroupNames
{
    DataModel* dataModel = [DataModel getInstance];

    // See if any archived drugs exist
    for (Drug* d in drugList)
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

// Function to compare two drugs' types
NSComparisonResult compareDrugType(Drug* d1, Drug* d2, void* context)
{
    if (!d1.reminder.archived && d2.reminder.archived)
        return NSOrderedAscending;
    else if (d1.reminder.archived && !d2.reminder.archived)
        return NSOrderedDescending;
    else
    {
        NSInteger (*orderedSameComparator)(id, id, void *) = (NSInteger (*)(id, id, void *))context;
        NSString* d1TypeName = [d1.dosage getTypeName];
        NSString* d2TypeName = [d2.dosage getTypeName];
        
        NSComparisonResult comparison = [d1TypeName compare:d2TypeName options:NSLiteralSearch];
        if (comparison == NSOrderedSame)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else
            return comparison;
    }
}

// Function to compare two drugs' names
NSComparisonResult compareDrugName(Drug* d1, Drug* d2, void* context)
{
    if (!d1.reminder.archived && d2.reminder.archived)
        return NSOrderedAscending;
    else if (d1.reminder.archived && !d2.reminder.archived)
        return NSOrderedDescending;
    else
    {
        NSInteger (*orderedSameComparator)(id, id, void *) = (NSInteger (*)(id, id, void *))context;
        
        NSComparisonResult comparison = [d1.name compare:d2.name options:NSLiteralSearch];
        
        // For 2 drugs with the same person name, order by the next reminder time
        if (comparison == NSOrderedSame)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else
            return comparison;
    }
}

// Function to compare two drugs' persons
NSComparisonResult compareDrugPerson(Drug* d1, Drug* d2, void* context)
{
    if (!d1.reminder.archived && d2.reminder.archived)
        return NSOrderedAscending;
    else if (d1.reminder.archived && !d2.reminder.archived)
        return NSOrderedDescending;
    else
    {
        NSInteger (*orderedSameComparator)(id, id, void *) = (NSInteger (*)(id, id, void *))context;
        
        // For 2 drugs with the same person name, order by the comparator (if available)
        if ([d1.personId caseInsensitiveCompare:d2.personId] == NSOrderedSame)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else if ([d1.personId length] == 0) // If d1's person is 'Me'
            return NSOrderedAscending;
        else if ([d2.personId length] == 0) // If d2's person is 'Me'
            return NSOrderedDescending;
        else
        {
            DataModel* dataModel = [DataModel getInstance];
            NSString* p1Name = [dataModel.globalSettings.personNames nameForGuid:d1.personId];
            NSString* p2Name = [dataModel.globalSettings.personNames nameForGuid:d2.personId];

            NSComparisonResult comparison = [p1Name compare:p2Name options:NSLiteralSearch];
            if (comparison == NSOrderedSame)
            {
                if (orderedSameComparator)
                    return orderedSameComparator(d1, d2, NULL);
                else
                    return NSOrderedSame;
            }
            else
                return comparison;
        }
    }
}

// Returns whether the given dates are within the same minute
BOOL areDatesWithinSameMinute(NSDate* d1, NSDate* d2)
{
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
    NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents* d1Components = [cal components:unitFlags fromDate:d1];
    NSDateComponents* d2Components = [cal components:unitFlags fromDate:d2];
    
    return ([d1Components year] == [d2Components year] &&
            [d1Components month] == [d2Components month] &&
            [d1Components day] == [d2Components day] &&
            [d1Components hour] == [d2Components hour] &&
            [d1Components minute] == [d2Components minute]);
}

// Returns data on the given drug for use in comparing & sorting drugs
void getDrugComparisonData(Drug* d, NSDate** timeRank, BOOL* isIntervalReminderReady, BOOL* isAsNeededReminder)
{
    DataModel* dataModel = [DataModel getInstance];

	NSDate* nextBedtimeEndDate = [dataModel getNextBedtimeEndDate];
    
    *timeRank = d.reminder.nextReminder;
	*isIntervalReminderReady = ([d.reminder treatmentStarted] && ![d.reminder treatmentEnded] &&
                                [d.reminder isKindOfClass:[IntervalDrugReminder class]] && !d.reminder.nextReminder);
	*isAsNeededReminder = ([d.reminder treatmentStarted] && ![d.reminder treatmentEnded] &&
                           [d.reminder isKindOfClass:[AsNeededDrugReminder class]] && !d.reminder.nextReminder);
    
    NSDate* nextAvailableDoseTime = nil;
    BOOL wouldExceedDoseLimitIfTaken = NO;
    [gInstance getDoseLimitStateForDrug:d.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];
    
    // If the treatment hasn't started and we don't have a nextReminder set, use the start date
	if (![d.reminder treatmentStarted] && !d.reminder.nextReminder)
	{
		// For interval reminders (and bedtime is enabled), use the start date once bedtime ends
		if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] && dataModel.globalSettings.bedtimeStart != -1 && dataModel.globalSettings.bedtimeEnd != -1)
			*timeRank = [dataModel getBedtimeEndDateOnDay:d.reminder.treatmentStartDate];
		else
			*timeRank = d.reminder.treatmentStartDate;
	}
    // If this drug is at the dose limit for today
    else if (wouldExceedDoseLimitIfTaken)
    {
        if (nextAvailableDoseTime)
            *timeRank = nextAvailableDoseTime;
        
        if ([d.reminder isKindOfClass:[IntervalDrugReminder class]])
            *isIntervalReminderReady = NO;
        else // AsNeededDrugReminder
            *isAsNeededReminder = NO;
    }
	// Substitute the bedtime end time for interval reminders that are 'when ready in the morning'
	else if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] && [((IntervalDrugReminder*)d.reminder) wouldSubsequentDoseFallInBedtime])
	{
		*isIntervalReminderReady = NO;
		*timeRank = nextBedtimeEndDate;
	}
}

// Function to compare two drugs' nextReminder dates
NSComparisonResult compareDrugNextReminders(Drug* d1, Drug* d2, void* context)
{
    if (!d1.reminder.archived && d2.reminder.archived)
        return NSOrderedAscending;
    else if (d1.reminder.archived && !d2.reminder.archived)
        return NSOrderedDescending;
    else
    {
        NSInteger (*orderedSameComparator)(id, id, void *) = (NSInteger (*)(id, id, void *))context;
        
        // Get the data to use for comparing both drugs
        NSDate* d1TimeRank = nil;
        BOOL d1IntervalReminderReady = NO;
        BOOL d1AsNeededReminder = NO;
        getDrugComparisonData(d1, &d1TimeRank, &d1IntervalReminderReady, &d1AsNeededReminder);
        
        NSDate* d2TimeRank = nil;
        BOOL d2IntervalReminderReady = NO;
        BOOL d2AsNeededReminder = NO;
        getDrugComparisonData(d2, &d2TimeRank, &d2IntervalReminderReady, &d2AsNeededReminder);
        
        // For treatment-ended reminders, list them last in reverse chronological order
        if ([d1.reminder treatmentEnded] && ![d2.reminder treatmentEnded])
            return NSOrderedDescending;
        else if (![d1.reminder treatmentEnded] && [d2.reminder treatmentEnded])
            return NSOrderedAscending;
        else if ([d1.reminder treatmentEnded] && [d2.reminder treatmentEnded])
        {
            NSTimeInterval interval = [d1.reminder.treatmentEndDate timeIntervalSinceDate:d2.reminder.treatmentEndDate];
            if (areDatesWithinSameMinute(d1.reminder.treatmentEndDate, d2.reminder.treatmentEndDate))
            {
                if (orderedSameComparator)
                    return orderedSameComparator(d1, d2, NULL);
                else
                    return NSOrderedSame;
            }
            else if (interval < 0)
                return NSOrderedDescending;
            else // if (interval > 0)
                return NSOrderedAscending;
        }
        // For interval reminders that appear as 'when ready', list them first
        else if (d1IntervalReminderReady && d2IntervalReminderReady)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else if (d1IntervalReminderReady && !d2IntervalReminderReady)
            return NSOrderedAscending;
        else if (!d1IntervalReminderReady && d2IntervalReminderReady)
            return NSOrderedDescending;
        // For as needed reminders, list them last (but before the treatment-ended reminders)
        else if (d1AsNeededReminder && d2AsNeededReminder)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else if (d1AsNeededReminder && !d2AsNeededReminder)
            return NSOrderedDescending;
        else if (!d1AsNeededReminder && d2AsNeededReminder)
            return NSOrderedAscending;
        // otherwise, reminders with a next-dose time should appear in chronological order before those without one
        else if (d1TimeRank == nil && d2TimeRank == nil)
        {
            if (orderedSameComparator)
                return orderedSameComparator(d1, d2, NULL);
            else
                return NSOrderedSame;
        }
        else if (d1TimeRank != nil && d2TimeRank == nil)
            return NSOrderedAscending;
        else if (d1TimeRank == nil && d2TimeRank != nil)
            return NSOrderedDescending;
        else
        {
            NSTimeInterval interval = [d1TimeRank timeIntervalSinceDate:d2TimeRank];
            if (areDatesWithinSameMinute(d1TimeRank, d2TimeRank))
            {
                if (orderedSameComparator)
                    return orderedSameComparator(d1, d2, NULL);
                else
                    return NSOrderedSame;
            }
            else if (interval < 0)
                return NSOrderedAscending;
            else // if (interval > 0)
                return NSOrderedDescending;
        }
    }
}

// Refreshes & sorts the drug list
- (void)refreshDrugList
{
	NSArray* sortedDrugList = nil;
    DataModel* dataModel = [DataModel getInstance];
    
    gInstance = self; // cache a pointer to ourself temporarily so that the sort can proceed
    if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByNextDoseTime)
        sortedDrugList = [dataModel.drugList sortedArrayUsingFunction:compareDrugNextReminders context:compareDrugPerson];
    else if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByPerson)
        sortedDrugList = [dataModel.drugList sortedArrayUsingFunction:compareDrugPerson context:compareDrugNextReminders];
    else if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByDrugName)
        sortedDrugList = [dataModel.drugList sortedArrayUsingFunction:compareDrugName context:compareDrugNextReminders];
    else // DrugSortOrderByDrugType
        sortedDrugList = [dataModel.drugList sortedArrayUsingFunction:compareDrugType context:compareDrugNextReminders];
    gInstance = nil;
    
	[drugList removeAllObjects];
    
    // Filter out any archived meds if they shouldn't be displayed
    for (Drug* d in sortedDrugList)
    {
        if (!d.reminder.invisible && (!d.reminder.archived || dataModel.globalSettings.archivedDrugsDisplayed))
            [drugList addObject:d];
    }

    [drugListGroupIndices setArray:[self getGroupIndicesForDrugList:drugList]];
}


- (void)handleHistoryEditedNotification:(NSNotification *)notification
{
    if (!isDeletingFromThisController)
    {
        // Re-sort all drugs and reload all cells in case, after the history was edited, we need to refresh drugs that have dose limits set
        [drugImagesDictionary removeAllObjects];

        [self.tableView reloadData];
        
        // The user may have added dose taken entries that pushed drugs already scheduled above their dose limits. Check for this.
        checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = YES;
    }
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

- (int) getNumSectionsForDrugListGroupIndices:(NSArray*)drugGroupIndices
{
    if ([drugGroupIndices count] > 0)
        return (int)[drugGroupIndices count];
    else
        return 1;
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
        
        NSDate* nextAvailableDoseTime = nil;
        BOOL wouldExceedDoseLimitIfTaken = NO;
        [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

        NSString* warningMessages = [self getWarningMessagesForDrug:drug];
        CGFloat warningHeight = [self getHeightForCellLabelTag:11 labelBaseHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];
        cellHeight += (warningHeight - WARNING_LABEL_BASE_HEIGHT);

        NSString* dosage = [drug.dosage getDescriptionForDrugDose:nil];
        if ([dosage length] > 0)
        {
            CGFloat dosageHeight = [self getHeightForCellLabelTag:200 labelBaseHeight:DOSAGE_LABEL_BASE_HEIGHT withString:dosage];
            cellHeight += (dosageHeight - DOSAGE_LABEL_BASE_HEIGHT);
        }
        
        // If no buttons are visible, shorten the height of the cell
        if (![self canTakeDrug:drug] && ![self canSkipDrug:drug] && ![self canPostponeDrug:drug] && ![self canUndoDrug:drug])
            cellHeight -= DRUG_ACTION_BUTTON_HEIGHT;

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
    [self recalcWouldExceedDoseLimitIfTakenDict];
    [self refreshDrugList];
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

- (BOOL)canTakeDrug:(Drug*)drug
{
    NSDate* nextAvailableDoseTime = nil;
    BOOL wouldExceedDoseLimitIfTaken = NO;
    [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

    return ([drug.reminder canTakeDose] && !wouldExceedDoseLimitIfTaken);
}

- (BOOL)canPostponeDrug:(Drug*)drug
{
    return [drug.reminder canPostponeDose];
}

- (BOOL)canSkipDrug:(Drug*)drug
{
    return [drug.reminder canSkipDose];
}

- (BOOL)canUndoDrug:(Drug*)drug
{
    return !drug.reminder.invisible && !drug.reminder.archived && [drug hasUndoState];
}

// Sets whether all buttons are visible
- (void)updateAllButtonVisibilityForDrug:(Drug*)drug inCell:(UITableViewCell*)cell
{	
	UIButton* takeDoseButton = (UIButton *)[cell viewWithTag:4];
	
    if (buttonMinimumScaleFactor < 0)
        buttonMinimumScaleFactor = 10.0 / takeDoseButton.titleLabel.font.pointSize;
    
	// Determine whether to show the TakePill button.
    takeDoseButton.hidden = ![self canTakeDrug:drug];
    
    if ( takeDoseButton.currentImage == nil )
    {
        [takeDoseButton setTitle:NSLocalizedStringWithDefaultValue(@"ScheduleDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take", @"The Take Dose button on the schedule reminder"]) forState:UIControlStateNormal];
        takeDoseButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        takeDoseButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:takeDoseButton color:[DosecastUtil getDrugCellButtonColor]];
    }
    
	// Determine whether to show the Postpone button. 
	UIButton* postponeButton = (UIButton *)[cell viewWithTag:5];

	postponeButton.hidden = ![self canPostponeDrug:drug];
    
    if ( postponeButton.currentImage == nil )
    {
        [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateNormal];
        postponeButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        postponeButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:postponeButton color:[DosecastUtil getDrugCellButtonColor]];
    }
    
	// Determine whether to show the SkipPill button. 
	UIButton* skipPillButton = (UIButton *)[cell viewWithTag:6];

	skipPillButton.hidden = ![self canSkipDrug:drug];
    
    if ( skipPillButton.currentImage == nil )
    {
        [skipPillButton setTitle:NSLocalizedStringWithDefaultValue(@"ScheduleDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip", @"The Skip Dose button on the dose schedule reminder"]) forState:UIControlStateNormal];
        skipPillButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        skipPillButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:skipPillButton color:[DosecastUtil getDrugCellButtonColor]];
    }
    
	// Determine whether to show the undo button
	UIButton* undoButton = (UIButton *)[cell viewWithTag:12];

    undoButton.hidden = ![self canUndoDrug:drug];
    if ( undoButton.currentImage == nil )
    {
        [undoButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndo", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo", @"The Undo Last button in the main view for a particular drug"]) forState:UIControlStateNormal];
        undoButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        undoButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:undoButton color:[DosecastUtil getDrugCellButtonColor]];
    }    
}

-(NSString*) getWarningMessagesForDrug:(Drug*)drug
{
    NSMutableString* warningMessages = [NSMutableString stringWithString:@""];
    DataModel* dataModel = [DataModel getInstance];
    
    NSDate* nextAvailableDoseTime = nil;
    BOOL wouldExceedDoseLimitIfTaken = NO;
    [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

    if (wouldExceedDoseLimitIfTaken)
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
            [[DosecastUtil getResourceBundle] loadNibNamed:@"MainViewPillTableViewCell" owner:self options:nil];
            
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
        
        // Get the day/month/year for tomorrow
        NSDate* now = [NSDate date];
        unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
        NSDate *tomorrow = [DosecastUtil addDaysToDate:now numDays:1];
        NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *tomorrowComponents = [cal components:unitFlags fromDate:tomorrow];
        
        // Determine the next dose label
        UILabel* nextDoseLabel = (UILabel *)[cell viewWithTag:3];
        NSDate* nextAvailableDoseTime = nil;
        BOOL wouldExceedDoseLimitIfTaken = NO;
        [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];
        
        if ([drug.reminder treatmentEnded])
        {
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            nextDoseLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseEnded", @"Dosecast", [DosecastUtil getResourceBundle], @"Ended on %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:drug.reminder.treatmentEndDate]];
            nextDoseLabel.textColor = warningTextColor;
        }
        else if (drug.reminder.archived)
        {
            nextDoseLabel.text = nil;
        }
        else if (![drug.reminder treatmentStarted])
        {
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            nextDoseLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseStarts", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting on %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:drug.reminder.treatmentStartDate]];
            nextDoseLabel.textColor = normalTextColor;
        }
        else if ([drug.reminder wouldSubsequentDoseFallAfterDate:drug.reminder.treatmentEndDate])
        {
            nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseEndingSoon", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending before next dose", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
            nextDoseLabel.textColor = normalTextColor;
        }
        else if (wouldExceedDoseLimitIfTaken)
        {
            if ([drug.reminder isKindOfClass:[AsNeededDrugReminder class]])
            {
                AsNeededDrugReminder* asNeededReminder = (AsNeededDrugReminder*)drug.reminder;
                if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypePerDay)
                {
                    nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1Tomorrow", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: tomorrow", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
                    nextDoseLabel.textColor = normalTextColor;
                }
                else // AsNeededDrugReminderDrugLimitTypePer24Hours
                {
                    NSString* nextDoseDayTaken = nil;
                    
                    NSDateComponents* doseLimitEndComponents = [cal components:unitFlags fromDate:nextAvailableDoseTime];
                    
                    // If next reminder is tomorrow
                    if ([tomorrowComponents day] == [doseLimitEndComponents day] &&
                        [tomorrowComponents month] == [doseLimitEndComponents month] &&
                        [tomorrowComponents year] == [doseLimitEndComponents year])
                    {
                        nextDoseDayTaken = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine2Tomorrow", @"Dosecast", [DosecastUtil getResourceBundle], @"tomorrow", @"The 2nd line of the next dose phrase appearing in the main view for a particular drug"]);
                    }
                    
                    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                    
                    NSMutableString* nextDoseText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:nextAvailableDoseTime]];
                    if (nextDoseDayTaken)
                        [nextDoseText appendFormat:@" %@", nextDoseDayTaken];
                    nextDoseLabel.text = nextDoseText;
                    nextDoseLabel.textColor = normalTextColor;
                }
            }
            else // IntervalDrugReminder
            {
                IntervalDrugReminder* intervalReminder = (IntervalDrugReminder*)drug.reminder;
                if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypePerDay)
                {
                    DataModel* dataModel = [DataModel getInstance];
                    BOOL bedtimeDefined = (dataModel.globalSettings.bedtimeStart != -1 || dataModel.globalSettings.bedtimeEnd != -1);
                    
                    if (bedtimeDefined)
                    {
                        NSDate* bedtimeStartTime = nil;
                        NSDate* bedtimeEndTime = nil;
                        [dataModel getBedtimeAsDates:&bedtimeStartTime bedtimeEnd:&bedtimeEndTime];
                        
                        [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                        
                        nextDoseLabel.text = [NSString stringWithFormat:@"%@ %@",
                                              NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1WhenReady", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: when ready", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]),
                                              [NSString stringWithFormat:[NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]) lowercaseString],
                                               [dateFormatter stringFromDate:bedtimeEndTime]]];
                        nextDoseLabel.textColor = normalTextColor;
                    }
                    else
                    {
                        nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1Tomorrow", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: tomorrow", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
                        nextDoseLabel.textColor = normalTextColor;
                    }
                }
                else // IntervalDrugReminderDrugLimitTypePer24Hours
                {
                    NSString* nextDoseDayTaken = nil;
                    
                    NSDateComponents* doseLimitEndComponents = [cal components:unitFlags fromDate:nextAvailableDoseTime];
                    
                    // If next reminder is tomorrow
                    if ([tomorrowComponents day] == [doseLimitEndComponents day] &&
                        [tomorrowComponents month] == [doseLimitEndComponents month] &&
                        [tomorrowComponents year] == [doseLimitEndComponents year])
                    {
                        nextDoseDayTaken = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine2Tomorrow", @"Dosecast", [DosecastUtil getResourceBundle], @"tomorrow", @"The 2nd line of the next dose phrase appearing in the main view for a particular drug"]);
                    }
                    
                    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                    NSMutableString* nextDoseText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:nextAvailableDoseTime]];
                    if (nextDoseDayTaken)
                        [nextDoseText appendFormat:@" %@", nextDoseDayTaken];
                    nextDoseLabel.text = nextDoseText;
                    nextDoseLabel.textColor = normalTextColor;
                }
            }
        }
        else if ([drug.reminder isKindOfClass:[AsNeededDrugReminder class]] && !drug.reminder.nextReminder)
        {
            nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1WhenNeeded", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: when needed", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
            nextDoseLabel.textColor = normalTextColor;
        }
        else if ([drug.reminder isKindOfClass:[IntervalDrugReminder class]] && !drug.reminder.nextReminder)
        {
            NSString* nextDoseDayTaken = nil;
            
            // If bedtime is defined, and the subsequent dose (if this pill is taken now) would lie
            // during bedtime, inform the user
            if ([((IntervalDrugReminder*)drug.reminder) wouldSubsequentDoseFallInBedtime])
            {
                NSDate* bedtimeStartTime = nil;
                NSDate* bedtimeEndTime = nil;
                DataModel* dataModel = [DataModel getInstance];
                [dataModel getBedtimeAsDates:&bedtimeStartTime bedtimeEnd:&bedtimeEndTime];
                
                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                
                nextDoseDayTaken = [NSString stringWithFormat:[NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]) lowercaseString],
                                    [dateFormatter stringFromDate:bedtimeEndTime]];
            }
            
            NSMutableString* nextDoseText = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1WhenReady", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: when ready", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"])];
            if (nextDoseDayTaken)
                [nextDoseText appendFormat:@" %@", nextDoseDayTaken];
            nextDoseLabel.text = nextDoseText;
            nextDoseLabel.textColor = normalTextColor;
            
        }
        else if ([drug.reminder isKindOfClass:[ScheduledDrugReminder class]] && !drug.reminder.nextReminder)
        {
            nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1Never", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: never", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
            nextDoseLabel.textColor = normalTextColor;
        }
        else
        {
            // Determine when the next reminder for this drug is
            
            // Get the day/month/year for today and for the next reminder
            NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
            NSDateComponents* nextReminderComponents = [cal components:unitFlags fromDate:drug.reminder.nextReminder];
            NSString* nextDoseDayTaken = nil;
            
            // If next reminder is tomorrow
            if ([tomorrowComponents day] == [nextReminderComponents day] &&
                [tomorrowComponents month] == [nextReminderComponents month] &&
                [tomorrowComponents year] == [nextReminderComponents year])
            {
                nextDoseDayTaken = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine2Tomorrow", @"Dosecast", [DosecastUtil getResourceBundle], @"tomorrow", @"The 2nd line of the next dose phrase appearing in the main view for a particular drug"]);
            }
            // For all future days
            else if ([todayComponents day] != [nextReminderComponents day] ||
                     [todayComponents month] != [nextReminderComponents month] ||
                     [todayComponents year] != [nextReminderComponents year])
            {
                [dateFormatter setDateStyle:NSDateFormatterShortStyle];
                [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
                nextDoseDayTaken = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine2Date", @"Dosecast", [DosecastUtil getResourceBundle], @"on %@", @"The 2nd line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:drug.reminder.nextReminder]];
            }
            
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            NSMutableString* nextDoseText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1Time", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:drug.reminder.nextReminder]];
            if (nextDoseDayTaken)
                [nextDoseText appendFormat:@" %@", nextDoseDayTaken];
            nextDoseLabel.text = nextDoseText;
            nextDoseLabel.textColor = normalTextColor;
        }
        
        // Size the nextDoseLabel height appropriately
        CGSize nextDoseLabelMaxSize = CGSizeMake(nextDoseLabel.frame.size.width, NEXTDOSE_LABEL_BASE_HEIGHT * nextDoseLabel.numberOfLines);
        
        CGRect rect = [nextDoseLabel.text boundingRectWithSize:nextDoseLabelMaxSize
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                       attributes:@{NSFontAttributeName: nextDoseLabel.font}
                                          context:nil];
        CGSize nextDoseLabelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
        
        nextDoseLabel.frame = CGRectMake(nextDoseLabel.frame.origin.x, nextDoseLabel.frame.origin.y, nextDoseLabel.frame.size.width, (int)ceilf(nextDoseLabelSize.height));

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
        
        if ([warningMessages length] > 0)
        {
            warningLabel.hidden = NO;
            warningLabel.textColor = warningTextColor;
            warningLabel.text = warningMessages;
            
            CGFloat warningLabelHeight = [self getHeightForCellLabelTag:11 labelBaseHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];

            warningLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.origin.x : drugImageLeftEdge + ([examplePillTableViewCell viewWithTag:11].frame.origin.x - [examplePillTableViewCell viewWithTag:300].frame.origin.x),
                                            (int)ceilf([examplePillTableViewCell viewWithTag:11].frame.origin.y + shiftY),
                                            showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.size.width : [examplePillTableViewCell viewWithTag:11].frame.size.width + drugImageWidthAndMargin,
                                            (int)ceilf(warningLabelHeight));
            
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
        
        UIImageView *notesIcon = (UIImageView *)[cell viewWithTag:44];
        notesIcon.hidden = ((!drug.notes || [[drug.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) &&
                            (!drug.directions || [[drug.directions stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0));

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
        
        // Determine the last dose label
        UILabel* lastDoseLabel = (UILabel *)[cell viewWithTag:2];
        lastDoseLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:2].frame.origin.x : drugImageLeftEdge,
                                         (int)ceilf([examplePillTableViewCell viewWithTag:2].frame.origin.y + shiftY),
                                         showDrugImages ? [examplePillTableViewCell viewWithTag:2].frame.size.width : [examplePillTableViewCell viewWithTag:2].frame.size.width + drugImageWidthAndMargin,
                                         lastDoseLabel.frame.size.height);

        NSDate* lastTaken = drug.reminder.lastTaken;
        if (lastTaken != nil)
        {
            // Determine when the last reminder for this drug was
            
            NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            NSDate* now = [NSDate date];
            unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
            
            // Get the day/month/year for today and for the next reminder
            NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
            NSDateComponents* lastTakenComponents = [cal components:unitFlags fromDate:lastTaken];
            
            // Get the day/month/year for yesterday
            NSDate *yesterday = [DosecastUtil addDaysToDate:now numDays:-1];
            NSDateComponents *yesterdayComponents = [cal components:unitFlags fromDate:yesterday];
            
            NSString* lastDoseDayTaken = nil;
            
            // If last taken is yesterday
            if ([yesterdayComponents day] == [lastTakenComponents day] &&
                [yesterdayComponents month] == [lastTakenComponents month] &&
                [yesterdayComponents year] == [lastTakenComponents year])
            {
                lastDoseDayTaken = NSLocalizedStringWithDefaultValue(@"ViewMainLastDosePhraseLine2Yesterday", @"Dosecast", [DosecastUtil getResourceBundle], @"yesterday", @"The 2nd line of the last dose phrase appearing in the main view for a particular drug"]);
            }
            // For all past days
            else if ([todayComponents day] != [lastTakenComponents day] ||
                     [todayComponents month] != [lastTakenComponents month] ||
                     [todayComponents year] != [lastTakenComponents year])
            {
                [dateFormatter setDateStyle:NSDateFormatterShortStyle];
                [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
                lastDoseDayTaken = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainLastDosePhraseLine2Date", @"Dosecast", [DosecastUtil getResourceBundle], @"on %@", @"The 2nd line of the last dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:lastTaken]];
            }
            
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            NSMutableString* lastDoseText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainLastDosePhraseLine1Time", @"Dosecast", [DosecastUtil getResourceBundle], @"Last taken: %@", @"The 1st line of the last dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:lastTaken]];
            if (lastDoseDayTaken)
                [lastDoseText appendFormat:@" %@", lastDoseDayTaken];
            lastDoseLabel.text = lastDoseText;
            lastDoseLabel.textColor = normalTextColor;
        }
        else
        {
            lastDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainLastDosePhraseLine1Never", @"Dosecast", [DosecastUtil getResourceBundle], @"Last taken: never", @"The 1st line of the last dose phrase appearing in the main view for a particular drug"]);
            lastDoseLabel.hidden = NO;
            lastDoseLabel.textColor = normalTextColor;
        }

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
        
        // Set the visibility of all buttons
        [self updateAllButtonVisibilityForDrug:drug inCell:cell];
        
        return cell;
    }
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
	// Call the async method
    __unsafe_unretained NSIndexPath* indexP = indexPath;
	SEL asyncMethod = @selector(didEndEditingRowAtIndexPathAsync:);
	NSMethodSignature * mySignature = [DosecastMainViewController instanceMethodSignatureForSelector:asyncMethod];
	NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
	[myInvocation setTarget:self];
	[myInvocation setSelector:asyncMethod];
	[myInvocation setArgument:&indexP atIndex:2];
	[NSTimer scheduledTimerWithTimeInterval:ASYNC_TIME_DELAY_ON_UNSWIPE invocation:myInvocation repeats:NO];
}

- (void)editPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
        deletedIndexPath = nil;
        
        [self.tableView reloadData];
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Edit Drug", @"The message in the alert appearing in the Drug Edit view when editing a drug fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}	
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

	[self.tableView reloadData];
}

- (void)undoPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{		
        // Don't need to reloadData - this will be covered by the didBuildDataModel callback
		undoDrugId = nil;
        
        // If we need to check for drugs with scheduled doses that are already at their dose limit, do so now.
        [self handleCheckForDrugsWithScheduledDosesAlreadyAtDoseLimit];
	}
	else
	{
		undoDrugId = nil;
		
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorUndoFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Undo", @"The message in the alert appearing when undoing a dose event fails"])
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

- (IBAction)handlePostponePill:(id)sender
{	
    // Make sure the sender is a UIButton
    if (![sender isKindOfClass:[UIButton class]])
        return;
	
	// Get the superview (the UITableViewCell)
	UIButton* senderButton = (UIButton*)sender;
    UIView* superView = senderButton.superview;
    while (![superView isKindOfClass:[UITableViewCell class]])
        superView = superView.superview;
	UITableViewCell *tableViewCell = (UITableViewCell*)superView;
	
	// Now extract the index path for the cell
	NSIndexPath* cellIndexPath = [self.tableView indexPathForCell:tableViewCell];
    Drug* d = [self getDrugForCellAtIndexPath:cellIndexPath];
	
	[[PillNotificationManager getInstance] performPostponePills:[NSArray arrayWithObjects:d.drugId,nil] sourceButton:sender];
}

- (IBAction)handleTakePill:(id)sender
{	
    // Make sure the sender is a UIButton
    if (![sender isKindOfClass:[UIButton class]])
        return;
	
	// Get the superview (the UITableViewCell)
	UIButton* senderButton = (UIButton*)sender;
    UIView* superView = senderButton.superview;
    while (![superView isKindOfClass:[UITableViewCell class]])
        superView = superView.superview;
	UITableViewCell *tableViewCell = (UITableViewCell*)superView;
	
	// Now extract the index path for the cell
	NSIndexPath* cellIndexPath = [self.tableView indexPathForCell:tableViewCell];
    Drug* d = [self getDrugForCellAtIndexPath:cellIndexPath];
	    
	// See if we should allow this to be taken
	DataModel* dataModel = [DataModel getInstance];
	if (d.reminder.nextReminder && [d.reminder.nextReminder timeIntervalSinceNow] > SEC_PER_HOUR &&
		dataModel.globalSettings.preventEarlyDrugDoses)
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseEarlyPreventTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Take Dose", @"The title of the alert preventing an early dose"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"AlertTakeDoseEarlyPreventMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This dose is scheduled to be taken more than one hour from now. Please take this dose later, or change the settings to disable this alert.", @"The title of the alert confirming whether the user wants to take a dose early"])];

		[alert showInViewController:self];
	}
	else
		[[PillNotificationManager getInstance] performTakePills:[NSArray arrayWithObjects:d.drugId, nil] sourceButton:sender];
}

- (IBAction)handleSkipPill:(id)sender
{	
    // Make sure the sender is a UIButton
    if (![sender isKindOfClass:[UIButton class]])
        return;
	
	// Get the superview (the UITableViewCell)
	UIButton* senderButton = (UIButton*)sender;
    UIView* superView = senderButton.superview;
    while (![superView isKindOfClass:[UITableViewCell class]])
        superView = superView.superview;
	UITableViewCell *tableViewCell = (UITableViewCell*)superView;
	
	// Now extract the index path for the cell
	NSIndexPath* cellIndexPath = [self.tableView indexPathForCell:tableViewCell];
    Drug* d = [self getDrugForCellAtIndexPath:cellIndexPath];
	[[PillNotificationManager getInstance] performSkipPills:[NSArray arrayWithObjects:d.drugId, nil] displayActions:YES sourceButton:sender];
}

- (IBAction)handleUndoPill:(id)sender
{	
    // Make sure the sender is a UIButton
    if (![sender isKindOfClass:[UIButton class]])
        return;
	
	// Get the superview (the UITableViewCell)
	UIButton* senderButton = (UIButton*)sender;
    UIView* superView = senderButton.superview;
    while (![superView isKindOfClass:[UITableViewCell class]])
        superView = superView.superview;
	UITableViewCell *tableViewCell = (UITableViewCell*)superView;
	
	// Now extract the index path for the cell
	NSIndexPath* cellIndexPath = [self.tableView indexPathForCell:tableViewCell];
    Drug* d = [self getDrugForCellAtIndexPath:cellIndexPath];
	
	undoDrugId = d.drugId;
		
	NSString* actionButtonTitle = nil;
	
	// If this drug has an undo history event id, use it to determine what type of event we're undoing
	if ([d hasUndoState])
	{
        NSString* undoOperation = [d undoOperation];
		if (undoOperation)
		{
			if ([undoOperation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
                actionButtonTitle = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndoTakeDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo Last Dose Taken", @"The Undo Last Dose Taken button in the main view for a particular drug"])];            
			else if ([undoOperation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
                actionButtonTitle = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndoSkipDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo Last Dose Skipped", @"The Undo Last Dose Skipped button in the main view for a particular drug"])];            
			if ([undoOperation caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
                actionButtonTitle = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndoPostponeDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo Last Dose Postponed", @"The Undo Last Dose Postponed button in the main view for a particular drug"])];            
		}
	}
    
    if (!actionButtonTitle)
        actionButtonTitle = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndo", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo", @"The Undo Last button in the main view for a particular drug"])];

	// Construct a new action sheet and use it to confirm the user wants to undo
    DosecastAlertController* undoController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    [undoController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      undoDrugId = nil;
                                  }]];
    [undoController addAction:
     [DosecastAlertAction actionWithTitle:actionButtonTitle
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                          [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerPerformingUndo", @"Dosecast", [DosecastUtil getResourceBundle], @"Performing undo", @"The message appearing in the spinner view when performing an undo"])];
                                          
                                          [[LocalNotificationManager getInstance] undoPill:undoDrugId
                                                                                 respondTo:self async:YES];
                                  }]];
    
    [undoController showInViewController:self sourceView:(UIButton*)sender];
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

        isExceedingMaxLocalNotifications = [[DataModel getInstance] isExceedingMaxLocalNotifications];
        
		// Refresh the table's data
		[self.tableView reloadData];
		
        PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];

		// We just did a refresh - so reset the needsDrugListRefresh flag
		if (pillNotificationManager.needsRefreshDrugState)
			pillNotificationManager.needsRefreshDrugState = NO;
		
        // If we need to check for drugs with scheduled doses that are already at their dose limit, do so now.
        if (checkForDrugsWithScheduledDosesAlreadyAtDoseLimit)
            [self handleCheckForDrugsWithScheduledDosesAlreadyAtDoseLimit];
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

