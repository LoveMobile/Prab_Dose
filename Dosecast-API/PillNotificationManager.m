//
//  PillNotificationManager.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/12/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "PillNotificationManager.h"
#import "DataModel.h"

#import "PillAlertViewController.h"
#import "Drug.h"
#import "ReachabilityManager.h"
#import "DrugViewController.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "HistoryManager.h"
#import "TakePillHandler.h"
#import "SkipPillHandler.h"
#import "PostponePillHandler.h"
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "LocalNotificationManager.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "ManagedDrugDosage.h"
#import "GlobalSettings.h"
#import "LogManager.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static NSString *TakePillMethodName = @"takePill";
static NSString *SkipPillMethodName = @"skipPill";
static NSString *PostponePillMethodName = @"postponePill";
static NSString *SyncMethodName = @"sync";

static PillNotificationManager *gInstance = nil;

@implementation PillNotificationManager

@synthesize notificationsPaused;
@synthesize delegate;
@synthesize needsRefreshDrugState;
@synthesize suppressOverdueDoseAlert;
@synthesize canRefreshDrugState;

- (id)init
{
    if ((self = [super init]))
    {
		notificationsPaused = NO;
		receivedPillNotification = NO;
		isViewingDrugFromOverdueDoseAlert = NO;
        canRefreshDrugState = NO;
        needsRefreshDrugState = NO;
        suppressOverdueDoseAlert = NO;
        isResolvingOverdueDrug = NO;
        takePillHandler = nil;
        skipPillHandler = nil;
        postponePillHandler = nil;
        isGetStateInProgress = NO;
						
		pillAlertViewController = nil;
        player = nil;
		allowNotificationSound = NO;
		delegate = nil;
        
        disabledReminderTimerDict = [[NSMutableDictionary alloc] init];
        
        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
	}
	
    return self;
}

- (void)dealloc
{
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];

    [self clearDisabledReminderTimers];
    
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    notificationsPaused = NO;
    receivedPillNotification = NO;
    isViewingDrugFromOverdueDoseAlert = NO;
    canRefreshDrugState = NO;
    needsRefreshDrugState = NO;
    suppressOverdueDoseAlert = NO;
    isResolvingOverdueDrug = NO;
    takePillHandler = nil;
    skipPillHandler = nil;
    postponePillHandler = nil;
    
    pillAlertViewController = nil;
				
    allowNotificationSound = NO;
    
    [disabledReminderTimerDict  removeAllObjects];
}

// Singleton methods

+ (PillNotificationManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

// Called when pill notification occurs from within app
- (void)handlePillNotification
{
    allowNotificationSound = YES;
	   
	// If we get a notification while paused or while a server call is in progress, ignore it.
	// When we get the response, we will automatically display a notification
	// if a pill is overdue.
	if (notificationsPaused)
    {
        // Play the notification sound right now, even if we can't display the alert. The sound won't get played later,
        // so there's no downside, and at least it can serve as a cue that something happened in case the user isn't looking at the screen.
        [self playNotificationSound:nil];
        
		return;
    }
	
	receivedPillNotification = YES;
	
	// Simply make a GetState request. The result should contain
	// an overdue pill, which the data model delegate will respond
	// to with a notification
    if (!isGetStateInProgress)
    {
        isGetStateInProgress = YES;
        [[LocalNotificationManager getInstance] getState:YES respondTo:self async:YES];
    }
}

// Returns whether the user is resolving an overdue dose alert
- (BOOL) isResolvingOverdueDoseAlert
{
    DataModel* dataModel = [DataModel getInstance];
    BOOL hasOverdueDrugs = [dataModel numOverdueDrugs] > 0;
    return (hasOverdueDrugs &&
            (isViewingDrugFromOverdueDoseAlert ||
             isResolvingOverdueDrug ||
             (pillAlertViewController && pillAlertViewController.visible)));
}

- (void)playNotificationSound:(NSTimer*)theTimer
{
	DataModel* dataModel = [DataModel getInstance];
	
	// Play the default SMS sound if we are allowed to
	if (allowNotificationSound)
	{
        NSString *path = [[NSBundle mainBundle] pathForResource:dataModel.globalSettings.reminderSoundFilename ofType:nil];
        NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
        NSError *error;
        if (player && player.playing)
            [player stop];
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:&error];
        [player prepareToPlay];
        [player play];        
		allowNotificationSound = NO;
	}			
}

- (void)displayOverduePills:(NSTimer*)theTimer
{
    DataModel* dataModel = [DataModel getInstance];
    int numOverdueDrugs = [dataModel numOverdueDrugs];
	BOOL shouldDisplayOverduePills = (numOverdueDrugs > 0 &&
                                      !isViewingDrugFromOverdueDoseAlert &&
                                      !suppressOverdueDoseAlert &&
                                      !isResolvingOverdueDrug);
    
    if (!shouldDisplayOverduePills)
    {
        [self hideOverduePillAlertIfVisible:YES];

        return;
    }
    
    DebugLog(@"Displaying dose alert: %d overdue drugs", numOverdueDrugs);

    // Make sure the Dosecast component is visible now
    [delegate displayDosecastComponent];

	// Refresh the dialog if it is already visible
	if (pillAlertViewController)
        [pillAlertViewController refresh];
    else
    {
        pillAlertViewController = [[PillAlertViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PillAlertViewController"]
                                                                            bundle:[DosecastUtil getResourceBundle]
                                                                          delegate:self];
    }
    
    if (!pillAlertViewController.visible)
    {
        UINavigationController* mainNavigationController = [delegate getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        [pillAlertViewController showOnViewController:topNavController.topViewController animated:YES];
    }
    
     [NSTimer scheduledTimerWithTimeInterval:.3 target:self selector:@selector(playNotificationSound:) userInfo:nil repeats:NO];    
}

// Adds the given 24-hour time to the dictionary of disabled reminder time timers
- (void) addDisabledReminderTimeForTime:(NSDate*)time
{
    // Create a new timer if one wasn't already created at this time today
    NSNumber* timeNum = [NSNumber numberWithInt:[DosecastUtil getDateAs24hrTime:time]];
    NSTimer* timer = [disabledReminderTimerDict objectForKey:timeNum];
    if (!timer)
    {
        timer = [[NSTimer alloc] initWithFireDate:time interval:0.0 target:self selector:@selector(onFireDisabledReminderTimer:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [disabledReminderTimerDict setObject:timer forKey:timeNum];
    }
}

- (void)onFireDisabledReminderTimer:(NSTimer*)theTimer
{
	// If we get a notification while paused or while a server call is in progress, ignore it.
	// When we get the response, we will automatically display a notification
	// if a pill is overdue.
	if (notificationsPaused)
        return;
    
    [self refreshDrugState:NO];
}

- (void) clearDisabledReminderTimers
{
    // Invalidate all timers
    for (NSTimer* timer in [disabledReminderTimerDict allValues])
        [timer invalidate];
    
    [disabledReminderTimerDict removeAllObjects];
}

// Refreshes the dictionary containing a timer for each disabled reminder time
- (void) refreshDisabledReminderTimers
{
    DataModel* dataModel = [DataModel getInstance];
    NSDate* now = [NSDate date];

    [self clearDisabledReminderTimers];
    
    // Create new timers for drugs due today that have reminders disabled
    for (Drug* d in dataModel.drugList)
    {
        if (d.reminder.remindersEnabled ||
            ([d isManaged] && ((ManagedDrugDosage*)d.dosage).isDiscontinued)) // ignore discontinued managed meds
        {
            continue;
        }
        
        NSArray* todaysReminderTimes = [d.reminder getFutureDoseTimesDueOnDay:now];
        
        for (NSDate* reminderTime in todaysReminderTimes)
        {
            [self addDisabledReminderTimeForTime:reminderTime];
        }        
    }
}

// Called to refresh all drug state. Returns whether successful.
- (BOOL)refreshDrugState:(BOOL)force
{
	DebugLog(@"Refresh drug state start");
	DataModel* dataModel = [DataModel getInstance];
		
	if (!isGetStateInProgress && (![delegate isDosecastComponentVisible] || canRefreshDrugState || force))
	{
        isGetStateInProgress = YES;
        
		[dataModel disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRefreshingDrugList", @"Dosecast", [DosecastUtil getResourceBundle], @"Refreshing drug list", @"The message appearing in the spinner view when refreshing the drug list"])];
		
		DebugLog(@"Refresh drug state end: root view controller active & visible");

		// Make a GetState request
        [[LocalNotificationManager getInstance] getState:YES respondTo:self async:YES];
		
		return YES;
	}
	else
	{
		DebugLog(@"Refresh drug state end: root view controller not active");

		needsRefreshDrugState = YES;
		return NO;
	}
}

- (void)handlePopViewDrug:(id)sender
{    
    UINavigationController* mainNavigationController = [delegate getUINavigationController];
	UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
    
    [topNavController popViewControllerAnimated:YES];
    
    // Resume display of overdue reminders
    if (isViewingDrugFromOverdueDoseAlert)
        isViewingDrugFromOverdueDoseAlert = NO;
    
    // If there are still any overdue pills, force the user to decide what to do
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(displayOverduePills:) userInfo:nil repeats:NO];
}

- (void)handleAlertViewDrug:(NSString*)drugId
{
    [self hideOverduePillAlertIfVisible:NO];

    // Stop display of overdue reminders temporarily
    if (!isViewingDrugFromOverdueDoseAlert)
        isViewingDrugFromOverdueDoseAlert = YES;

    UINavigationController* mainNavigationController = [delegate getUINavigationController];
	UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];

    // Display DrugViewController in new view
	DrugViewController* drugController = [[DrugViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugViewController"]
                                                                              bundle:[DosecastUtil getResourceBundle]
                                                                              drugId:drugId
                                                                            viewDate:[NSDate date]
                                                                        allowEditing:NO
                                                                            delegate:nil];
	[topNavController pushViewController:drugController animated:YES];
	
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    backButton.target = self;
    backButton.action = @selector(handlePopViewDrug:);
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
	topNavController.topViewController.navigationItem.leftBarButtonItem = backButton;    
}

// Called whenever the data model (re)builds from JSON
- (void)handleDataModelRefresh:(NSNotification *)notification
{
    NSMutableDictionary* notificationDict = (NSMutableDictionary*)notification.object;
    NSSet* serverMethodCalls = nil;
    if (notificationDict)
        serverMethodCalls = [notificationDict objectForKey:DataModelDataRefreshNotificationServerMethodCallsKey];

    // Set timers for disabled reminder times
    [self refreshDisabledReminderTimers];
    
	DataModel* dataModel = [DataModel getInstance];
    int numOverdueDrugs = [dataModel numOverdueDrugs];

    if (serverMethodCalls && [serverMethodCalls member:SyncMethodName] &&
        numOverdueDrugs == 0 &&
        pillAlertViewController && pillAlertViewController.visible &&
        !isViewingDrugFromOverdueDoseAlert &&
        !isResolvingOverdueDrug)
    {
        DebugLog(@"Hiding dose alert");

        [pillAlertViewController hide:YES]; // Hide the dose reminder alert if a sync occurred and the overdue dose was resolved
    }
    // Handle a time zone change before displaying overdue pills, and don't display overdue pills
	// after a takePill, skipPill, or postponePill method call (since their respective Done methods already do this).
	else if (![dataModel needsToResolveTimezoneChange] &&
        (!serverMethodCalls ||
         (![serverMethodCalls member:TakePillMethodName] &&
          ![serverMethodCalls member:SkipPillMethodName] &&
          ![serverMethodCalls member:PostponePillMethodName])))
	{
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(displayOverduePills:) userInfo:nil repeats:NO];
	}
}

// Hides the overdue pill alert if it's visible
- (void)hideOverduePillAlertIfVisible:(BOOL)animated
{
    if (pillAlertViewController && pillAlertViewController.visible)
    {
        DebugLog(@"Hiding dose alert");

        [pillAlertViewController hide:animated];
    }
}

- (void)handleAlertTakeDose:(id)sender
{    
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleTakePillOnReminderButtonClick:) userInfo:sender repeats:NO];
}

- (void)handleAlertSkipDose:(id)sender
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleSkipPillOnReminderButtonClick:) userInfo:sender repeats:NO];
}

- (void)handleAlertPostponeDose:(id)sender
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handlePostponePillOnReminderButtonClick:) userInfo:sender repeats:NO];
}

- (void)handleSkipPillOnReminderButtonClick:(NSTimer*)theTimer
{
    skipPillHandler = [[SkipPillHandler alloc] init:[[DataModel getInstance] getOverdueDrugIds]
                                     displayActions:YES
                                       sourceButton:(UIButton*)theTimer.userInfo
                                           delegate:self];
}

- (void)handleTakePillOnReminderButtonClick:(NSTimer*)theTimer
{
    takePillHandler = [[TakePillHandler alloc] init:[[DataModel getInstance] getOverdueDrugIds]
                                       sourceButton:(UIButton*)theTimer.userInfo
                                           delegate:self];
}

- (void)handlePostponePillOnReminderButtonClick:(NSTimer*)theTimer
{
    postponePillHandler = [[PostponePillHandler alloc] init:[[DataModel getInstance] getOverdueDrugIds]
                                               sourceButton:(UIButton*)theTimer.userInfo
                                                   delegate:self];
}

- (void)getStateLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	if (receivedPillNotification)
    {        
        if (!result)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:errorMessage];
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
			[alert showInViewController:topNavController.topViewController];
        }
        
        receivedPillNotification = NO;
    }
	else
    {
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

        if (result)
        {
            DataModel* dataModel = [DataModel getInstance];
            int numOverdueDrugs = [dataModel numOverdueDrugs];
                                    
            if (numOverdueDrugs > 0) // a dose reminder will be displayed - do nothing else right now
            {
                isGetStateInProgress = NO;
                return;
            }
            else
            {  
                // Post a notification about this, in case anyone cares. Now is a good time to display user alerts.
                [[NSNotificationCenter defaultCenter] postNotification:
                 [NSNotification notificationWithName:DosecastAPIDisplayUserAlertsNotification object:nil]];
            }
        }
        else
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:errorMessage];
            UINavigationController* mainNavigationController = [delegate getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            [alert showInViewController:topNavController.topViewController];
        }
	}
    
    isGetStateInProgress = NO;
}

// Returns the minimum postpone period in minutes
- (int) minimumPostponePeriodMin
{
    return [PostponePillHandler minimumPostponePeriodMin];
}

// Get the main navigation controller
- (UINavigationController*)getUINavigationController
{
    return [delegate getUINavigationController];
}

- (void)handlePostponePillHandlerDone:(NSArray*)postponedDrugIds
{
    [[LogManager sharedManager] endPausingBackgroundSync]; // We can restoring synching now
    isResolvingOverdueDrug = NO;
    
    // If there are still any overdue pills, force the user to decide what to do
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(displayOverduePills:) userInfo:nil repeats:NO];
}

- (void)handleSkipPillHandlerDone:(NSArray*)skippedDrugIds
{
    [[LogManager sharedManager] endPausingBackgroundSync]; // We can restoring synching now
    isResolvingOverdueDrug = NO;
    
    // If there are still any overdue pills, force the user to decide what to do
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(displayOverduePills:) userInfo:nil repeats:NO];
}

- (void)handleTakePillHandlerDone:(NSArray*)takenDrugIds
{
    [[LogManager sharedManager] endPausingBackgroundSync]; // We can restoring synching now
    isResolvingOverdueDrug = NO;
    
    // If there are still any overdue pills, force the user to decide what to do
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(displayOverduePills:) userInfo:nil repeats:NO];
}

// Called to handle a request to take the given drugs
- (void)performTakePills:(NSArray*)drugIds sourceButton:(UIButton*)button
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    takePillHandler = [[TakePillHandler alloc] init:drugIds sourceButton:button delegate:self];
}

// Called to handle a request to skip the given drugs
- (void)performSkipPills:(NSArray*)drugIds displayActions:(BOOL)displayActions sourceButton:(UIButton*)button
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    skipPillHandler = [[SkipPillHandler alloc] init:drugIds displayActions:displayActions sourceButton:button delegate:self];
}

// Called to handle a request to postpone the given drugs
- (void)performPostponePills:(NSArray*)drugIds sourceButton:(UIButton*)button
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't do a background sync while operating on pills
    isResolvingOverdueDrug = YES;
    postponePillHandler = [[PostponePillHandler alloc] init:drugIds sourceButton:button delegate:self];
}

@end
