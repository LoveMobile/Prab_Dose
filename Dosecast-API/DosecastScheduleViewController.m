//
//  DosecastScheduleViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DosecastScheduleViewController.h"
#import "DataModel.h"
#import "DrugViewController.h"
#import "DrugAddEditViewController.h"
#import "PillNotificationManager.h"
#import "Drug.h"
#import "ScheduleViewDoseTime.h"
#import "ScheduleViewDose.h"
#import "DosecastUtil.h"
#import "SettingsViewController.h"
#import "IntervalDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "DrugHistoryViewController.h"
#import "LocalNotificationManager.h"
#import "HistoryManager.h"
#import "HistoryEvent.h"
#import "CustomNameIDList.h"
#import <QuartzCore/QuartzCore.h>
#import "DrugImageManager.h"
#import "ScheduledDrugReminder.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "ManagedDrugDosage.h"
#import "GlobalSettings.h"
#import "LogManager.h"
#import "AccountViewController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int SECTION_HEADER_HEIGHT = 8;
static const int SECTION_NONEMPTY_FOOTER_HEIGHT = 8;
static const int SECTION_EMPTY_FOOTER_HEIGHT = 100;
static const int DRUG_ACTION_BUTTON_HEIGHT = 30;
static const CGFloat DRUGNAME_LABEL_BASE_HEIGHT = 18.0f;
static const CGFloat DOSAGE_LABEL_BASE_HEIGHT = 16.0f;
static const CGFloat NEXTDOSE_LABEL_BASE_HEIGHT = 15.0f;
static const CGFloat WARNING_LABEL_BASE_HEIGHT = 16.0f;

static const double SEC_PER_HOUR = 60*60;

@implementation DosecastScheduleViewController

@synthesize pillTableViewCell;
@synthesize tableView;
@synthesize scheduleToolbarView;
@synthesize drugPlaceholderImageView;
@synthesize localNotificationWarningCell;

- (ScheduleViewDose*) addDoseToSchedule:(NSString*)drugID
                           historyEvent:(HistoryEvent*)historyEvent
                     doseLimitCheckDate:(NSDate*)doseLimitDate
                                 atTime:(NSDate*)date
{
    ScheduleViewDose* dose = [[ScheduleViewDose alloc] init:drugID
                                                    doseTime:date
                                                historyEvent:historyEvent
                                          doseLimitCheckDate:doseLimitDate
                                                isLastAction:NO
                                                isNextAction:NO];
    const double epsilon = 0.0001;

    BOOL added = NO;
    int numDoseTimes = (int)[scheduleViewDoseTimes count];
    for (int i = 0; i < numDoseTimes && !added; i++)
    {
        ScheduleViewDoseTime* doseTime = [scheduleViewDoseTimes objectAtIndex:i];

        NSTimeInterval interval = [doseTime.doseTime timeIntervalSinceDate:date];

        if (fabs(interval) < 60.0-epsilon) // add to existing dose time
        {
            if (historyEvent) // Put doses with history at the beginning of dose time lists
                [doseTime.scheduleViewDoses insertObject:dose atIndex:0];
            else
                [doseTime.scheduleViewDoses addObject:dose];
            added = YES;
        }
        else if (interval > 0) // add a new dose time here
        {
            ScheduleViewDoseTime* newDoseTime = [[ScheduleViewDoseTime alloc] init:date
                                                                  scheduleViewDoses:[NSArray arrayWithObject:dose]];
            [scheduleViewDoseTimes insertObject:newDoseTime atIndex:i];
            added = YES;
        }
    }
    
    if (!added)
    {
        ScheduleViewDoseTime* newDoseTime = [[ScheduleViewDoseTime alloc] init:date
                                                              scheduleViewDoses:[NSArray arrayWithObject:dose]];
        [scheduleViewDoseTimes addObject:newDoseTime];
    }
        
    return dose;
}

- (void) recalcWouldExceedDoseLimitIfTakenDict
{
    [wouldExceedDoseLimitIfTakenDict removeAllObjects];
    [nextAvailableDoseTimeDict removeAllObjects];
    
    DataModel* dataModel = [DataModel getInstance];
    NSDate* now = [NSDate date];
    BOOL isScheduleDayToday = [DosecastUtil areDatesOnSameDay:scheduleDay date2:now];
    NSDate* doseLimitCheckDate = (isScheduleDayToday ? now : [DosecastUtil getMidnightOnDate:scheduleDay]);
    
    for (Drug* d in dataModel.drugList)
    {
        NSDate* nextAvailableDoseTime = nil;
        
        NSNumber* resultNum = [NSNumber numberWithBool:
                               [d wouldExceedDoseLimitIfTakenAtDate:doseLimitCheckDate nextAvailableDoseTime:&nextAvailableDoseTime]];
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

- (void) rebuildDoseList
{
    [scheduleViewDoseTimes removeAllObjects];
    NSDate* now = [NSDate date];
    BOOL isScheduleDayToday = [DosecastUtil areDatesOnSameDay:scheduleDay date2:now];
    
    [self recalcWouldExceedDoseLimitIfTakenDict];
    
    DataModel* dataModel = [DataModel getInstance];
    for (Drug* d in dataModel.drugList)
    {
        if (d.reminder.archived || d.reminder.invisible ||
            ([d isManaged] && ((ManagedDrugDosage*)d.dosage).isDiscontinued)) // ignore discontinued managed meds
        {
            continue;
        }
        
        int postponeDuration = 0;
        BOOL wasPostponed = [d.reminder wasPostponed:&postponeDuration];
        
        // --- deal with the past
        
        // If the schedule day is today, add the past times from the history for this drug
        if (isScheduleDayToday)
        {
            ScheduleViewDose* lastDose = nil;
            NSArray* historyEvents = [[HistoryManager getInstance] getHistoryEventsForTodayForDrugId:d.drugId];
            for (HistoryEvent* historyEvent in historyEvents)
            {
                // Add resolving events (take/skip/miss)
                if ([historyEvent.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame ||
                    [historyEvent.operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame ||
                    [historyEvent.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
                {                    
                    NSDate* time = historyEvent.scheduleDate;
                    if (!time)
                        time = historyEvent.creationDate;
                    lastDose = [self addDoseToSchedule:d.drugId historyEvent:historyEvent doseLimitCheckDate:nil atTime:time];
                }
            }
            
            // Flag the last dose if it wasn't postponed
            if (!wasPostponed && lastDose)
                lastDose.isLastAction = YES;

            // If this drug is scheduled and not logging missed doses, add the list of past doses today that were missed
            if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
            {
                ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;
                if (!scheduledReminder.logMissedDoses)
                {
                    NSArray* doseTimes = [scheduledReminder getPastDoseTimesDueOnDay:scheduleDay];
                    doseTimes = [doseTimes sortedArrayUsingSelector:@selector(compare:)]; // put results in chronological order
                    NSArray* missedDoseTimes = [[HistoryManager getInstance] findMissedDosesForDrugId:d.drugId amongDoseTimes:doseTimes errorMessage:nil];
                                        
                    int numMissedDoses = (int)[missedDoseTimes count];
                    for (int i = 0; i < numMissedDoses; i++)
                    {
                        NSDate* doseTime = [missedDoseTimes objectAtIndex:i];
                        
                        // Don't bother adding a missed dose time if this is the last missed dose and the drug was postponed. We'll pick the dose up in the future scheduled dose times next.
                        if (i == numMissedDoses-1 &&
                            wasPostponed &&
                            (!lastDose || [doseTime timeIntervalSinceDate:lastDose.doseTime] > 0))
                        {
                            continue;
                        }
                        
                        [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:nil atTime:doseTime];
                    }
                }
            }            
        }
        
        // --- deal with the future

        NSArray* doseTimes = [d.reminder getFutureDoseTimesDueOnDay:scheduleDay];
        if ([doseTimes count] > 0)
        {
            ScheduleViewDose* nextDose = nil;
            for (NSDate* doseTime in doseTimes)
            {
                NSDate* doseLimitCheckDate = (isScheduleDayToday ? now : [DosecastUtil getMidnightOnDate:scheduleDay]);    
                NSDate* nextAvailableDoseTime = nil;
                ScheduleViewDose* thisDose = nil;
                BOOL wouldExceedDoseLimitIfTaken = NO;
                [self getDoseLimitStateForDrug:d.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

                if (wouldExceedDoseLimitIfTaken)
                {
                    if (nextAvailableDoseTime && [DosecastUtil areDatesOnSameDay:nextAvailableDoseTime date2:scheduleDay])
                        thisDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:nextAvailableDoseTime]; 
                }
                else
                    thisDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:doseTime];
                
                // Flag the next dose only once (and flag it as the last dose if it was postponed) - but only for today.
                if (thisDose && !nextDose && isScheduleDayToday)
                {
                    thisDose.isNextAction = YES;
                    nextDose = thisDose;
                    if (wasPostponed)
                        thisDose.isLastAction = YES;
                }
            }
        }
        else if ([d.reminder isKindOfClass:[IntervalDrugReminder class]] &&
                 (!d.reminder.nextReminder || [scheduleDay timeIntervalSinceDate:[DosecastUtil getLastSecondOnDate:d.reminder.nextReminder]] > 0))
        {
            ScheduleViewDose* nextDose = nil;
            
            // If we still don't have a time set, try the earliest time possible on the day if the treatment has started & not ended
            if ([d.reminder treatmentStartedOnDay:scheduleDay] && ![d.reminder treatmentEndedOnDay:scheduleDay])
            {
                NSDate* doseTime = nil;
                
                if (isScheduleDayToday)
                    doseTime = now;
                else
                {
                    doseTime = [dataModel getBedtimeEndDateOnDay:scheduleDay];
                    if (!doseTime)
                        doseTime = [DosecastUtil getMidnightOnDate:scheduleDay];
                }
                
                NSDate* doseLimitCheckDate = (isScheduleDayToday ? now : [DosecastUtil getMidnightOnDate:scheduleDay]);
                NSDate* nextAvailableDoseTime = nil;
                BOOL wouldExceedDoseLimitIfTaken = NO;
                [self getDoseLimitStateForDrug:d.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

                if (wouldExceedDoseLimitIfTaken)
                {
                    if (nextAvailableDoseTime && [DosecastUtil areDatesOnSameDay:nextAvailableDoseTime date2:scheduleDay])
                        nextDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:nextAvailableDoseTime];                
                }
                else
                    nextDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:doseTime];
            }
            
            // Flag the next dose (and flag it as the last dose if it was postponed) - but only for today.
            if (nextDose && isScheduleDayToday)
            {
                nextDose.isNextAction = YES;
                if (wasPostponed)
                    nextDose.isLastAction = YES;
            }
        }
        else if ([d.reminder isKindOfClass:[AsNeededDrugReminder class]] &&
                 (!d.reminder.nextReminder || [scheduleDay timeIntervalSinceDate:[DosecastUtil getLastSecondOnDate:d.reminder.nextReminder]] > 0))
        {            
            ScheduleViewDose* nextDose = nil;

            // Try the latest time possible on the day if the treatment has started & not ended
            if ([d.reminder treatmentStartedOnDay:scheduleDay] && ![d.reminder treatmentEndedOnDay:scheduleDay])
            {
                NSDate* doseTime = [DosecastUtil getLastSecondOnDate:scheduleDay];

                NSDate* doseLimitCheckDate = (isScheduleDayToday ? now : [DosecastUtil getMidnightOnDate:scheduleDay]);    

                NSDate* nextAvailableDoseTime = nil;
                BOOL wouldExceedDoseLimitIfTaken = NO;
                [self getDoseLimitStateForDrug:d.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];
                if (wouldExceedDoseLimitIfTaken)
                {
                    if (nextAvailableDoseTime && [DosecastUtil areDatesOnSameDay:nextAvailableDoseTime date2:scheduleDay])
                        nextDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:nextAvailableDoseTime];                
                }
                else
                    nextDose = [self addDoseToSchedule:d.drugId historyEvent:nil doseLimitCheckDate:doseLimitCheckDate atTime:doseTime];
            }
            
            // Flag the next dose (and flag it as the last dose if it was postponed) - but only for today.
            if (nextDose && isScheduleDayToday)
            {
                nextDose.isNextAction = YES;
                if (wasPostponed)
                    nextDose.isLastAction = YES;
            }
        }            
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.title = NSLocalizedStringWithDefaultValue(@"ViewScheduleTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Schedule", @"The title of the Schedule view"]);

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        scheduleDay = [DosecastUtil getMidnightOnDate:[NSDate date]];
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        undoDrugId = nil;
        checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = NO;
        drugIdsWithScheduledDosesAlreadyAtDoseLimit = [[NSMutableSet alloc] init];
        drugImagesDictionary = [[NSMutableDictionary alloc] init];
        examplePillTableViewCell = nil;
        buttonMinimumScaleFactor = -1.0;
        self.hidesBottomBarWhenPushed = YES;
        wouldExceedDoseLimitIfTakenDict = [[NSMutableDictionary alloc] init];
        nextAvailableDoseTimeDict = [[NSMutableDictionary alloc] init];

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:HistoryManagerHistoryEditedNotification
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

        scheduleViewDoseTimes = [[NSMutableArray alloc] init];
        [self rebuildDoseList];
        tableViewController = nil;
        refreshControl = nil;
        isExceedingMaxLocalNotifications = NO;
    }
    return self;
}

- (void)dealloc {
    
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HistoryManagerHistoryEditedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncFailedNotification object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	    
    // Set add button
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(handleAddDrug:)];
	self.navigationItem.rightBarButtonItem = addButton;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"ScheduleViewPillTableViewCell" owner:self options:nil];
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

- (void)updateScheduleToolbar
{
    // Set the day label
    UILabel* dayLabel = (UILabel*)[scheduleToolbarView viewWithTag:4];
    BOOL isToday = [DosecastUtil areDatesOnSameDay:scheduleDay date2:[NSDate date]];
    if (isToday)
    {
        dayLabel.text = NSLocalizedStringWithDefaultValue(@"ViewScheduleDayToday", @"Dosecast", [DosecastUtil getResourceBundle], @"Today", @"The today label in the schedule view"]);
    }
    else
    {
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        dayLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:scheduleDay], [dateFormatter stringFromDate:scheduleDay]];
    }
    
    // Set the visibility for the prev button
    UIButton* prevButton = (UIButton*)[scheduleToolbarView viewWithTag:2];
    prevButton.hidden = isToday;
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
    
    // If the app has been active across a day boundary, do a refresh
    if ([scheduleDay timeIntervalSinceDate:[DosecastUtil getMidnightOnDate:[NSDate date]]] < 0)
    {
        scheduleDay = [DosecastUtil getMidnightOnDate:[NSDate date]];
        [self rebuildDoseList];
        [drugImagesDictionary removeAllObjects];
        [self.tableView reloadData];
    }
    
    [self updateScheduleToolbar];
    
    if ( animated )
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
    
    DataModel* dataModel = [DataModel getInstance];
    [drugIdsWithScheduledDosesAlreadyAtDoseLimit removeAllObjects];
    NSMutableString* drugNamesWithScheduledDosesAlreadyAtDoseLimit = [NSMutableString stringWithString:@""];

    for (ScheduleViewDoseTime* scheduleDoseTime in scheduleViewDoseTimes)
    {
        for (ScheduleViewDose* dose in scheduleDoseTime.scheduleViewDoses)
        {
            Drug* d = [dataModel findDrugWithId:dose.drugID];

            if ([d isExceedingDoseLimit])
            {
                [drugIdsWithScheduledDosesAlreadyAtDoseLimit addObject:d.drugId];
                if ([drugNamesWithScheduledDosesAlreadyAtDoseLimit length] > 0)
                    [drugNamesWithScheduledDosesAlreadyAtDoseLimit appendString:@"\n"];
                [drugNamesWithScheduledDosesAlreadyAtDoseLimit appendString:d.name];
            }
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
                                          [[PillNotificationManager getInstance] performSkipPills:[drugIdsWithScheduledDosesAlreadyAtDoseLimit allObjects] displayActions:NO sourceButton:nil];
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
                                          [[PillNotificationManager getInstance] performSkipPills:[drugIdsWithScheduledDosesAlreadyAtDoseLimit allObjects] displayActions:NO sourceButton:nil];
                                      }]];
        
        [alert showInViewController:self];
    }
}

// Returns cell index path to scroll to
- (NSIndexPath*) getScrollCellIndexPath
{
    int numScheduleViewDoseTimes = (int)[scheduleViewDoseTimes count];
    if (numScheduleViewDoseTimes == 0)
        return nil;
    
    NSDate* now = [NSDate date];
    if ([DosecastUtil areDatesOnSameDay:scheduleDay date2:now])
    {
        NSIndexPath* cellPath = nil;
        for (int i = 0; i < numScheduleViewDoseTimes && !cellPath; i++)
        {
            ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:i];
            if ([scheduleDoseTime.scheduleViewDoses count] > 0 &&
                [now timeIntervalSinceDate:scheduleDoseTime.doseTime] < 0)
            {
                cellPath = [NSIndexPath indexPathForRow:0 inSection:i];
            }            
        }
        
        if (!cellPath)
        {
            ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:(numScheduleViewDoseTimes-1)];
            cellPath = [NSIndexPath indexPathForRow:([scheduleDoseTime.scheduleViewDoses count]-1) inSection:(numScheduleViewDoseTimes-1)];
        }
        return cellPath;
    }
    else
        return [NSIndexPath indexPathForRow:0 inSection:0];
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

    // Scroll to relevant cell
    [self scrollTable:nil];
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
}

- (void)handleHistoryEditedNotification:(NSNotification *)notification
{        
    [self rebuildDoseList];
    [drugImagesDictionary removeAllObjects];

    [self.tableView reloadData];
    
    // The user may have added dose taken entries that pushed drugs already scheduled above their dose limits. Check for this.
    checkForDrugsWithScheduledDosesAlreadyAtDoseLimit = YES;
}

#pragma mark Table view methods

- (Drug*) getDrugForCellAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger section = indexPath.section;
    if (isExceedingMaxLocalNotifications)
        section -= 1;
    
    ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:section];
    ScheduleViewDose* dose = [scheduleDoseTime.scheduleViewDoses objectAtIndex:indexPath.row];
    
    DataModel* dataModel = [DataModel getInstance];
    return [dataModel findDrugWithId:dose.drugID];
}

- (int) getNumRowsInSection:(int)section
{
    if (isExceedingMaxLocalNotifications)
        section -= 1;

    if ([scheduleViewDoseTimes count] == 0)
        return 0;
    ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:section];
    return (int)[scheduleDoseTime.scheduleViewDoses count];
}

- (CGFloat) getHeightForCellLabelTag:(int)tag baseLabelHeight:(CGFloat)baseLabelHeight withString:(NSString*)value
{
    UILabel* label = (UILabel*)[examplePillTableViewCell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, baseLabelHeight * (float)label.numberOfLines);
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName: label.font}
                                      context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    if (labelSize.height > baseLabelHeight)
        return labelSize.height+2.0f;
    else
        return baseLabelHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (isExceedingMaxLocalNotifications && indexPath.section == 0)
        return 52;
    else
    {
        Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
        ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:indexPath.section];
        ScheduleViewDose* dose = [scheduleDoseTime.scheduleViewDoses objectAtIndex:indexPath.row];
        
        CGFloat cellHeight = examplePillTableViewCell.frame.size.height;
        
        CGFloat nameHeight = [self getHeightForCellLabelTag:1 baseLabelHeight:DRUGNAME_LABEL_BASE_HEIGHT withString:drug.name];
        cellHeight += (nameHeight - DRUGNAME_LABEL_BASE_HEIGHT);
        
        NSDate* nextAvailableDoseTime = nil;
        BOOL wouldExceedDoseLimitIfTaken = NO;
        [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

        BOOL isAtDoseLimit = dose.doseLimitCheckDate && wouldExceedDoseLimitIfTaken;
        NSString* warningMessages = [self getWarningMessagesForDrug:drug isAtDoseLimit:isAtDoseLimit dose:dose];
        CGFloat warningHeight = [self getHeightForCellLabelTag:11 baseLabelHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];
        cellHeight += (warningHeight - WARNING_LABEL_BASE_HEIGHT);
        
        NSString* dosageDescription = nil;
        if (dose.historyEvent)
        {
            HistoryManager* historyManager = [HistoryManager getInstance];
            dosageDescription = [historyManager getEventDescriptionForHistoryEvent:dose.historyEvent.drugId
                                                                         operation:dose.historyEvent.operation
                                                                     operationData:dose.historyEvent.operationData
                                                                        dosageType:dose.historyEvent.dosageType
                                                                   preferencesDict:[historyManager createHistoryEventPreferencesDict:dose.historyEvent]
                                                            legacyEventDescription:dose.historyEvent.eventDescription
                                                                   displayDrugName:NO];        
        }
        else
            dosageDescription = [drug.dosage getDescriptionForDrugDose:nil];
        
        if ([dosageDescription length] > 0)
        {
            CGFloat dosageHeight = [self getHeightForCellLabelTag:200 baseLabelHeight:DOSAGE_LABEL_BASE_HEIGHT withString:dosageDescription];
            cellHeight += (dosageHeight - DOSAGE_LABEL_BASE_HEIGHT);
        }
        
        // If no buttons are visible, shorten the height of the cell
        if (![self canTakeDose:drug dose:dose] &&
            ![self canSkipDose:drug dose:dose] &&
            ![self canPostponeDose:drug dose:dose] &&
            ![self canUndoDose:drug dose:dose])
        {
            cellHeight -= DRUG_ACTION_BUTTON_HEIGHT;
        }
        
        return cellHeight;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return nil;
	else if ([scheduleViewDoseTimes count] == 0)
        return NSLocalizedStringWithDefaultValue(@"ViewScheduleNoDosesMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"No medications have scheduled doses on this day. To add a new medication, touch the + button.", @"The message appearing in the schedule view when no doses have been added"]);
	else
		return nil;
}

- (int) getNumSections
{
    int numSections = 0;
    
    if ([scheduleViewDoseTimes count] == 0)
        numSections = 1;
    else
        numSections = (int)[scheduleViewDoseTimes count];
    
    if (isExceedingMaxLocalNotifications)
        numSections += 1;

    return numSections;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];
    return [self getNumSections];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return 1;
    else if ([scheduleViewDoseTimes count] == 0)
        return 0;
    else
        return [self getNumRowsInSection:(int)section];
}

- (BOOL)canTakeDose:(Drug*)drug dose:(ScheduleViewDose*)dose
{
    NSDate* nextAvailableDoseTime = nil;
    BOOL wouldExceedDoseLimitIfTaken = NO;
    [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

    return ([drug.reminder canTakeDose] && dose.isNextAction &&
            (!dose.doseLimitCheckDate || !wouldExceedDoseLimitIfTaken));
}

- (BOOL)canPostponeDose:(Drug*)drug dose:(ScheduleViewDose*)dose
{
    return ([drug.reminder canPostponeDose] && dose.isNextAction);
}

- (BOOL)canSkipDose:(Drug*)drug dose:(ScheduleViewDose*)dose
{
    return ([drug.reminder canSkipDose] && dose.isNextAction);
}

- (BOOL)canUndoDose:(Drug*)drug dose:(ScheduleViewDose*)dose
{
    return ([drug hasUndoState] && dose.isLastAction);
}

// Sets whether all buttons are visible
- (void)updateAllButtonVisibilityForDrug:(Drug*)drug
                                    dose:(ScheduleViewDose*)dose
                                doseTime:(NSDate*)doseTime
                                  inCell:(UITableViewCell*)cell
{
	// Determine whether to show the TakePill button. 
	UIButton* takeDoseButton = (UIButton *)[cell viewWithTag:7];
    
    if (buttonMinimumScaleFactor < 0)
        buttonMinimumScaleFactor = 10.0 / takeDoseButton.titleLabel.font.pointSize;
    
    takeDoseButton.hidden = ![self canTakeDose:drug dose:dose];
    
    if ( takeDoseButton.currentImage == nil  )
    {
        [takeDoseButton setTitle:NSLocalizedStringWithDefaultValue(@"ScheduleDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take", @"The Take Dose button on the schedule reminder"]) forState:UIControlStateNormal];
        takeDoseButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        takeDoseButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:takeDoseButton color:[DosecastUtil getDrugCellButtonColor]];
    }
	    
	// Determine whether to show the Postpone button. 
	UIButton* postponeButton = (UIButton *)[cell viewWithTag:8];
	postponeButton.hidden = ![self canPostponeDose:drug dose:dose];

    if ( postponeButton.currentImage == nil  )
    {
        [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateNormal];
        postponeButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        postponeButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:postponeButton color:[DosecastUtil getDrugCellButtonColor]];
    }

	// Determine whether to show the SkipPill button. 
	UIButton* skipPillButton = (UIButton *)[cell viewWithTag:9];
	skipPillButton.hidden = ![self canSkipDose:drug dose:dose];

    if ( skipPillButton.currentImage == nil  )
    {
        [skipPillButton setTitle:NSLocalizedStringWithDefaultValue(@"ScheduleDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip", @"The Skip Dose button on the dose schedule reminder"]) forState:UIControlStateNormal];
        skipPillButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        skipPillButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:skipPillButton color:[DosecastUtil getDrugCellButtonColor]];
    }
	
	// Determine whether to show the undo button
	UIButton* undoButton = (UIButton *)[cell viewWithTag:12];
    undoButton.hidden = ![self canUndoDose:drug dose:dose];

    if ( undoButton.currentImage == nil )
    {
        [undoButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewMainDrugButtonUndo", @"Dosecast", [DosecastUtil getResourceBundle], @"Undo", @"The Undo Last button in the main view for a particular drug"]) forState:UIControlStateNormal];
        undoButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        undoButton.titleLabel.minimumScaleFactor = buttonMinimumScaleFactor;
        [DosecastUtil setBackgroundColorForButton:undoButton color:[DosecastUtil getDrugCellButtonColor]];
    }
}

-(NSString*) getWarningMessagesForDrug:(Drug*)drug isAtDoseLimit:(BOOL)isAtDoseLimit dose:(ScheduleViewDose*)dose
{
    NSMutableString* warningMessages = [NSMutableString stringWithString:@""];
    DataModel* dataModel = [DataModel getInstance];
    
    if (isAtDoseLimit && !dose.historyEvent)
    {
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
        [warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewDrugViewMaxDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Max doses taken", @"The Max Doses Taken label in the Drug View view"])];
    }
    if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [drug isEmpty] && !dose.historyEvent)
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningEmpty", @"Dosecast", [DosecastUtil getResourceBundle], @"Empty", @"The Empty warning in the main view for a particular drug when there is no quantity remaining"])];
	}
	else if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [drug isRunningLow] && !dose.historyEvent)
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningRunningLow", @"Dosecast", [DosecastUtil getResourceBundle], @"Running low", @"The Running Low warning in the main view for a particular drug when the quantity remaining is running low"])];
	}
    if ([drug.reminder isExpired] && !dose.historyEvent)
	{
        if ([warningMessages length] > 0)
            [warningMessages appendString:@"\n"];
		[warningMessages appendString:NSLocalizedStringWithDefaultValue(@"ViewMainDrugWarningExpired", @"Dosecast", [DosecastUtil getResourceBundle], @"Expired", @"The Expired warning in the main view for a particular drug when the expiration date has passed"])];
	}
	else if ([drug.reminder isExpiringSoon] && !dose.historyEvent)
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
            [[DosecastUtil getResourceBundle] loadNibNamed:@"ScheduleViewPillTableViewCell" owner:self options:nil];
            
            cell = pillTableViewCell;
            pillTableViewCell = nil;
        }
        
        // Configure the cell.
        
        Drug* drug = [self getDrugForCellAtIndexPath:indexPath];
        ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:indexPath.section];
        ScheduleViewDose* dose = [scheduleDoseTime.scheduleViewDoses objectAtIndex:indexPath.row];
        NSDate* doseTime = scheduleDoseTime.doseTime;
            
        UIColor* textColor = [UIColor blackColor];
        BOOL showDrugImages = [DataModel getInstance].globalSettings.drugImagesDisplayed;
        
        CGFloat drugImageLeftEdge = [cell viewWithTag:100].frame.origin.x;
        CGFloat drugImageWidthAndMargin = [cell viewWithTag:1].frame.origin.x - drugImageLeftEdge;
        
        BOOL isUnscheduledIntervalDose = ([drug.reminder isKindOfClass:[IntervalDrugReminder class]] &&
                                          (!drug.reminder.nextReminder || [scheduleDay timeIntervalSinceDate:[DosecastUtil getLastSecondOnDate:drug.reminder.nextReminder]] > 0));

        if (dose.historyEvent)
        {
            if ([dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame ||
                [dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
            {
                textColor = [UIColor lightGrayColor];
            }
            else if ([dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            {
                textColor = [DosecastUtil getDrugWarningLabelColor];
            }
        }
        else if (!isUnscheduledIntervalDose) // set the color to gray for past events if this isn't an unscheduled interval dose
        {
            NSDate* now = [NSDate date];
            if ([now timeIntervalSinceDate:doseTime] > 0)
                textColor = [UIColor lightGrayColor];
        }
     
        NSDate* nextAvailableDoseTime = nil;
        BOOL wouldExceedDoseLimitIfTaken = NO;
        [self getDoseLimitStateForDrug:drug.drugId wouldExceedDoseLimitIfTaken:&wouldExceedDoseLimitIfTaken nextAvailableDoseTime:&nextAvailableDoseTime];

        BOOL isAtDoseLimit = dose.doseLimitCheckDate && wouldExceedDoseLimitIfTaken;
        
        // Determine the next dose label
        UILabel* nextDoseLabel = (UILabel *)[cell viewWithTag:3];
        
        if ([drug.reminder isKindOfClass:[AsNeededDrugReminder class]] && !dose.historyEvent &&
            (!drug.reminder.nextReminder || [scheduleDay timeIntervalSinceDate:[DosecastUtil getLastSecondOnDate:drug.reminder.nextReminder]] > 0))
        {
            if (isAtDoseLimit)
            {
                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                
                nextDoseLabel.text = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:doseTime]];
            }
            else
                nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1WhenNeeded", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: when needed", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
            nextDoseLabel.textColor = textColor;
        }
        else if ([drug.reminder isKindOfClass:[IntervalDrugReminder class]] && !dose.historyEvent &&
                 (!drug.reminder.nextReminder || [scheduleDay timeIntervalSinceDate:[DosecastUtil getLastSecondOnDate:drug.reminder.nextReminder]] > 0))
        {
            if (isAtDoseLimit)
            {
                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                
                nextDoseLabel.text = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1AfterTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: after %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:doseTime]];
            }
            else
                nextDoseLabel.text = NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1WhenReady", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: when ready", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]);
            nextDoseLabel.textColor = textColor;
        }
        else
        {
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            NSMutableString* nextDoseText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewMainNextDosePhraseLine1Time", @"Dosecast", [DosecastUtil getResourceBundle], @"Next dose: %@", @"The 1st line of the next dose phrase appearing in the main view for a particular drug"]), [dateFormatter stringFromDate:doseTime]];
            nextDoseLabel.text = nextDoseText;
            nextDoseLabel.textColor = textColor;
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
        drugNameLabel.textColor = textColor;

        CGFloat nameHeight = [self getHeightForCellLabelTag:1 baseLabelHeight:DRUGNAME_LABEL_BASE_HEIGHT withString:drug.name];
        drugNameLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:1].frame.origin.x : drugImageLeftEdge,
                                         drugNameLabel.frame.origin.y,
                                         showDrugImages ? [examplePillTableViewCell viewWithTag:1].frame.size.width : [examplePillTableViewCell viewWithTag:1].frame.size.width + drugImageWidthAndMargin,
                                         (int)ceilf(nameHeight));
        CGFloat shiftY = (nameHeight - DRUGNAME_LABEL_BASE_HEIGHT);
        
        UIImageView* warningImage = (UIImageView *)[cell viewWithTag:300];
        UILabel* warningLabel = (UILabel *)[cell viewWithTag:11];
        NSString* warningMessages = [self getWarningMessagesForDrug:drug isAtDoseLimit:isAtDoseLimit dose:dose];
        
        if ([warningMessages length] > 0)
        {
            warningLabel.hidden = NO;
            warningLabel.textColor = [DosecastUtil getDrugWarningLabelColor];
            warningLabel.text = warningMessages;
            
            CGFloat warningLabelHeight = [self getHeightForCellLabelTag:11 baseLabelHeight:WARNING_LABEL_BASE_HEIGHT withString:warningMessages];
            
            warningLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.origin.x : drugImageLeftEdge + ([examplePillTableViewCell viewWithTag:11].frame.origin.x - [examplePillTableViewCell viewWithTag:300].frame.origin.x),
                                            (int)ceilf([examplePillTableViewCell viewWithTag:11].frame.origin.y + shiftY),
                                            showDrugImages ? [examplePillTableViewCell viewWithTag:11].frame.size.width : [examplePillTableViewCell viewWithTag:11].frame.size.width + drugImageWidthAndMargin,
                                            (int)ceilf(warningLabelHeight));
            
            if (warningImage)
            {
                warningImage.hidden = NO;
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

        NSString* dosageDescription = nil;
        if (dose.historyEvent)
        {
            HistoryManager* historyManager = [HistoryManager getInstance];
            dosageDescription = [historyManager getEventDescriptionForHistoryEvent:dose.historyEvent.drugId
                                                                         operation:dose.historyEvent.operation
                                                                     operationData:dose.historyEvent.operationData
                                                                        dosageType:dose.historyEvent.dosageType
                                                                   preferencesDict:[historyManager createHistoryEventPreferencesDict:dose.historyEvent]
                                                            legacyEventDescription:dose.historyEvent.eventDescription
                                                                   displayDrugName:NO];
        }
        else
            dosageDescription = [drug.dosage getDescriptionForDrugDose:nil];
        
        if ([dosageDescription length] > 0)
        {
            drugDosageAndRouteLabel.hidden = NO;
            CGFloat dosageHeight = [self getHeightForCellLabelTag:200 baseLabelHeight:DOSAGE_LABEL_BASE_HEIGHT withString:dosageDescription];
            drugDosageAndRouteLabel.frame = CGRectMake(showDrugImages ? [examplePillTableViewCell viewWithTag:200].frame.origin.x : drugImageLeftEdge,
                                                       (int)ceilf([examplePillTableViewCell viewWithTag:200].frame.origin.y + shiftY),
                                                       showDrugImages ? [examplePillTableViewCell viewWithTag:200].frame.size.width : [examplePillTableViewCell viewWithTag:200].frame.size.width + drugImageWidthAndMargin,
                                                       (int)ceilf(dosageHeight));

            drugDosageAndRouteLabel.text = dosageDescription;
            drugDosageAndRouteLabel.textColor = textColor;

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

        if (dose.historyEvent)
        {
            lastDoseLabel.hidden = NO;
            NSString* formatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerFutureTime", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ at %@", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            
            if ([dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame)
            {
                lastDoseLabel.textColor = textColor;
                lastDoseLabel.text = [NSString stringWithFormat:formatText,
                                      [DosecastUtil capitalizeFirstLetterOfString:NSLocalizedStringWithDefaultValue(@"DrugHistoryTakenDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"taken", @"The description for taken doses in the drug history"])],
                                      [dateFormatter stringFromDate:dose.historyEvent.creationDate]];
            }
            else if ([dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerSkipPillOperationName] == NSOrderedSame)
            {
                lastDoseLabel.textColor = textColor;
                lastDoseLabel.text = [NSString stringWithFormat:formatText,
                                      [DosecastUtil capitalizeFirstLetterOfString:NSLocalizedStringWithDefaultValue(@"DrugHistorySkippedDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"skipped", @"The description for skipped doses in the drug history"])],
                                      [dateFormatter stringFromDate:dose.historyEvent.creationDate]];
            }
            else if ([dose.historyEvent.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            {
                lastDoseLabel.textColor = textColor;
                lastDoseLabel.text = [DosecastUtil capitalizeFirstLetterOfString:NSLocalizedStringWithDefaultValue(@"DrugHistoryMissedDescription", @"Dosecast", [DosecastUtil getResourceBundle], @"missed", @"The description for missed doses in the drug history"])];
            }
            else
                lastDoseLabel.hidden = YES;
        }
        else
        {
            lastDoseLabel.hidden = YES;
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
        [self updateAllButtonVisibilityForDrug:drug
                                          dose:dose
                                      doseTime:doseTime
                                        inCell:cell];
        
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
    return NO;
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
        ScheduleViewDoseTime* scheduleDoseTime = [scheduleViewDoseTimes objectAtIndex:indexPath.section];
        NSDate* now = [NSDate date];
        BOOL isToday = [DosecastUtil areDatesOnSameDay:scheduleDay date2:now];
        NSDate* doseLimitCheckDate = (isToday ? now : scheduleDoseTime.doseTime);    

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
                                                                                viewDate:doseLimitCheckDate
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

- (void)handleDrugDelete:(NSString*)drugId
{
    [self rebuildDoseList];
    [drugImagesDictionary removeAllObjects];
	[tableView reloadData];
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

- (IBAction)handleAddDrug:(id)sender
{
	DrugAddEditViewController* drugAddEditController = [[DrugAddEditViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugAddEditViewController"]
																						   bundle:[DosecastUtil getResourceBundle]
																							 mode:DrugAddEditViewControllerModeAddDrug
																						   drugId:nil
                                                                               treatmentStartDate:scheduleDay
																						 delegate:nil];	
	[self.navigationController pushViewController:drugAddEditController animated:YES];
}

- (void) scrollTable:(NSTimer*)theTimer
{
    // Scroll to relevant cell
    NSIndexPath* cellPath = [self getScrollCellIndexPath];
    if (cellPath)
        [tableView scrollToRowAtIndexPath:cellPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (IBAction)handlePrevScheduleDay:(id)sender
{
    [tableView beginUpdates];

    // Delete all current sections
    NSMutableIndexSet* sectionsToDelete = [NSMutableIndexSet indexSet];
    int oldNumSections = [self getNumSections];
    for (int i = 0; i < oldNumSections; i++)
        [sectionsToDelete addIndex:i];
    [tableView deleteSections:sectionsToDelete withRowAnimation:UITableViewRowAnimationRight];

    // update the schedule day and rebuild the dose list
    NSDate *newScheduleDay = [DosecastUtil addDaysToDate:scheduleDay numDays:-1];
    scheduleDay = newScheduleDay;
    [self updateScheduleToolbar];
    [self rebuildDoseList];
    
    // Insert all new sections
    NSMutableIndexSet* sectionsToInsert = [NSMutableIndexSet indexSet];
    int newNumSections = [self getNumSections];
    for (int i = 0; i < newNumSections; i++)
        [sectionsToInsert addIndex:i];
    [tableView insertSections:sectionsToInsert withRowAnimation:UITableViewRowAnimationLeft];
    
    [tableView endUpdates];
    
    // Scroll to relevant cell after the table updates finish
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(scrollTable:) userInfo:nil repeats:NO];
}

- (IBAction)handleNextScheduleDay:(id)sender
{
    [tableView beginUpdates];

    // Delete all current sections
    NSMutableIndexSet* sectionsToDelete = [NSMutableIndexSet indexSet];
    int oldNumSections = [self getNumSections];
    for (int i = 0; i < oldNumSections; i++)
        [sectionsToDelete addIndex:i];
    [tableView deleteSections:sectionsToDelete withRowAnimation:UITableViewRowAnimationLeft];
    
    // update the schedule day and rebuild the dose list
    NSDate *newScheduleDay = [DosecastUtil addDaysToDate:scheduleDay numDays:1];
    scheduleDay = newScheduleDay;
    [self updateScheduleToolbar];
    [self rebuildDoseList];
    
    // Insert all new sections
    NSMutableIndexSet* sectionsToInsert = [NSMutableIndexSet indexSet];
    int newNumSections = [self getNumSections];
    for (int i = 0; i < newNumSections; i++)
        [sectionsToInsert addIndex:i];
    [tableView insertSections:sectionsToInsert withRowAnimation:UITableViewRowAnimationRight];
    
    [tableView endUpdates];
    
    // Scroll to relevant cell after the table updates finish
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(scrollTable:) userInfo:nil repeats:NO];
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
    [self rebuildDoseList];
    
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{        
    return SECTION_HEADER_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (isExceedingMaxLocalNotifications && section == 0)
        return SECTION_NONEMPTY_FOOTER_HEIGHT;
    else if ([scheduleViewDoseTimes count] == 0)
        return SECTION_EMPTY_FOOTER_HEIGHT;
    else
        return SECTION_NONEMPTY_FOOTER_HEIGHT;
}

@end

