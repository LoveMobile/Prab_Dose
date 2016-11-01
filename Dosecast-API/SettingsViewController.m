//
//  SettingsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "SettingsViewController.h"
#import "DosecastUtil.h"

#import "DataModel.h"
#import "BedtimeSettingsViewController.h"
#import "AccountViewController.h"
#import "LocalNotificationManager.h"

#import "PicklistViewController.h"
#import "NumericPickerViewController.h"
#import "HistoryManager.h"
#import "LateDoseSettingsViewController.h"
#import "ReminderSound.h"
#import "BooleanViewController.h"
#import "Drug.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DrugDosageUnitManager.h"
#import "TimePeriodViewController.h"
#import "JoinGroupEnterGroupNameViewController.h"
#import "ServerProxy.h"
#import "ViewDeleteGroupViewController.h"
#import "Group.h"
#import "GlobalSettings.h"
#import "LogManager.h"
#import "Preferences.h"
#import "SyncAddDeviceViewController.h"
#import "SyncMoveDeviceViewController.h"
#import "SyncViewDevicesViewController.h"
#import "TimePeriodViewController.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

// The different UI sections & rows
typedef enum {
	SettingsViewControllerSectionsVersion    = 0,    
	SettingsViewControllerSectionsEdition    = 1,
    SettingsViewControllerSectionsDisplay    = 2,
	SettingsViewControllerSectionsScheduling = 3,
    SettingsViewControllerSectionsReminders  = 4,
    SettingsViewControllerSectionsSecurityPrivacy   = 5,
    SettingsViewControllerSectionsHistory    = 6,
    SettingsViewControllerSectionsGroups     = 7,
    SettingsViewControllerSectionsSync  = 8
} SettingsViewControllerSections;

typedef enum {
	SettingsViewControllerDisplaySectionRowsDrugSortOrder = 0,
	SettingsViewControllerDisplaySectionRowsDisplayArchivedDrugs  = 1,
    SettingsViewControllerDisplaySectionRowsDisplayDrugImages  = 2
} SettingsViewControllerDisplaySectionRows;

typedef enum {
    SettingsViewControllerSecurityPrivacySectionRowsPrivacyMode = 0,
	SettingsViewControllerSecurityPrivacySectionRowsChangePasscode = 1,
	SettingsViewControllerSecurityPrivacySectionRowsDeleteAllData  = 2,
    SettingsViewControllerSecurityPrivacySectionRowsLogging  = 3
} SettingsViewControllerSecurityPrivacySectionRows;

static const int BEDTIME_LABEL_HEIGHT = 43;
static const int LATE_DOSE_PERIOD_LABEL_HEIGHT = 43;
static const int PERIOD_MINUTE_INTERVAL = 1;
static const int PERIOD_MAX_HOURS = 9;

static NSString *ReminderSoundFilenameKey = @"reminderSoundFilename";
static NSString *DoseHistoryDaysKey = @"doseHistoryDays";
static NSString *PostponesDisplayedKey = @"postponesDisplayed";
static NSString *ArchivedDrugsDisplayedKey = @"archivedDrugsDisplayed";
static NSString *DrugImagesDisplayedKey = @"showImages";
static NSString *DrugNamesDisplayedInNotificationsKey = @"privacyMode";
static NSString *PreventEarlyDrugDosesKey = @"earlyDoseWarning";
static NSString *LateDosePeriodSecsKey = @"lateDosePeriodSecs";
static NSString *DrugSortOrderKey = @"drugSortOrder";
static NSString *SecondaryReminderPeriodSecsKey = @"secondaryReminderPeriodSecs";
static NSString *ReminderSoundPicklistId = @"reminderSound";
static NSString *DrugSortOrderPicklistId = @"drugSortOrder";
static NSString *PostponesDisplayedId = @"postponesDisplayed";
static NSString *PreventEarlyDrugDosesId = @"earlyDoseWarning";
static NSString *ArchivedDrugsDisplayedId = @"archivedDrugsDisplayed";
static NSString *DrugImagesDisplayedId = @"showImages";
static NSString *PrivacyModeId = @"PrivacyModeId";
static NSString *LoggingModeId = @"debugLoggingId";
static NSString *DebugLoggingEnabledKey = @"debugLoggingEnabled";

@implementation SettingsViewController

@synthesize tableView;
@synthesize bedtimeCell;
@synthesize accountCell;
@synthesize reminderSoundCell;
@synthesize earlyWarningCell;
@synthesize historyDurationCell;
@synthesize lateDoseCell;
@synthesize displayPostponeEventsCell;
@synthesize drugSortOrderCell;
@synthesize changePasscodeCell;
@synthesize versionCell;
@synthesize secondaryRemindersPeriodCell;
@synthesize deleteAllDataCell;
@synthesize displayArchivedDrugsCell;
@synthesize displayDrugImagesCell;
@synthesize serverUserIDCell;
@synthesize privacyModeCell;
@synthesize addGroupCell;
@synthesize groupCell;
@synthesize syncAddDeviceCell;
@synthesize syncMoveDeviceCell;
@synthesize syncViewDevicesCell;
@synthesize moveScheduledRemindersCell;
@synthesize refreshAllRemindersCell;
@synthesize loggingCell;

// Function to compare two reminder sounds by their display name
NSComparisonResult compareReminderSounds(ReminderSound* s1, ReminderSound* s2, void* context)
{
    return [s1.displayName compare:s2.displayName options:NSLiteralSearch];    
}

// Get the list of reminder sounds
- (NSMutableArray*)getReminderSounds
{
    NSMutableArray* sounds = [[NSMutableArray alloc] init];

	// Search for all .caf files in the main bundle
	NSArray* filenames = [[NSBundle mainBundle] pathsForResourcesOfType:@"caf" inDirectory:nil];
	if (!filenames)
		return nil;

	int numFiles = (int)[filenames count];
	for (int i = 0; i < numFiles; i++)
	{
		// Extract the filename from the full path
		NSString* rawFilename = [filenames objectAtIndex:i];
		NSRange slashRange = [rawFilename rangeOfString:@"/" options:NSBackwardsSearch];
		NSRange dotRange = [rawFilename rangeOfString:@"." options:NSBackwardsSearch];
		NSRange rawFilenameRange = NSMakeRange(slashRange.location+1, dotRange.location-slashRange.location-1);
		NSString *filename = [rawFilename substringWithRange:rawFilenameRange];
		[sounds addObject:[[ReminderSound alloc] init:filename]];
	}
	
	// Sort the sound names
	[sounds sortUsingFunction:compareReminderSounds context:NULL];

	return sounds;
}

// Return the current reminder sound filename in use
- (NSString*)getCurrentReminderSoundFilename
{
	DataModel* dataModel = [DataModel getInstance];
	NSRange dotRange = [dataModel.globalSettings.reminderSoundFilename rangeOfString:@"." options:NSBackwardsSearch];
	return [dataModel.globalSettings.reminderSoundFilename substringToIndex:dotRange.location];
}

// Return the index of the current reminder sound from the list
- (int)getCurrentReminderSoundIndex
{
	NSString* currSoundFilename = [self getCurrentReminderSoundFilename];

	int index = -1;
	int numSounds = (int)[reminderSounds count];
	for (int i = 0; i < numSounds && index < 0; i++)
	{
		ReminderSound* sound = [reminderSounds objectAtIndex:i];
		if ([sound.filename compare:currSoundFilename] == NSOrderedSame)
			index = i;
	}
	
	return index;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
		reminderSounds = [self getReminderSounds];
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

		tableViewSections = [[NSMutableArray alloc] init];
        tableViewSecurityPrivacySectionRows = [[NSMutableArray alloc] init];
        tableViewDisplaySectionRows = [[NSMutableArray alloc] init];
        setPreferencesDict = [[NSMutableDictionary alloc] init];
        selectedGroup = nil;
        selectedGroupLogo = nil;
        deletedGroupIndexPath = nil;
        isMovingScheduledRemindersEarlier = NO;
        player = nil;
        self.hidesBottomBarWhenPushed = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
	}
	return self;
}

- (void)dealloc {
    
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
}

// Called whenever the data model (re)builds from JSON
- (void)handleDataModelRefresh:(NSNotification *)notification
{
    // Refresh the table's data
    [self.tableView reloadData];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSettingsTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Settings", @"The title of the Settings view"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 16;
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
    // Turn on table editing for the groups section
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


- (void)handleBedtimeSettingsDone
{
	[self.tableView reloadData];
}

// Callback for successful joining of a group
- (void)handleJoinGroupSuccess
{
    [self.navigationController popToViewController:self animated:YES];
	[self.tableView reloadData];
}

// Called when the user initiated a subscribe and it completed successfully
- (void)handleSubscribeComplete
{
	[self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)handleSelectItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
	if ([Id caseInsensitiveCompare:ReminderSoundPicklistId] == NSOrderedSame)
	{        
		// Play the sound for the item
		ReminderSound* sound = [reminderSounds objectAtIndex:item];
        
        NSString *path = [[NSBundle mainBundle] pathForResource:sound.filename ofType:@"caf"];
		NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
        NSError* error = nil;
        if (player && player.playing)
            [player stop];
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:&error];
        [player prepareToPlay];
        [player play];
	}
}

- (BOOL)handleDonePickingItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
	if ([Id caseInsensitiveCompare:ReminderSoundPicklistId] == NSOrderedSame)
	{
		if (item != [self getCurrentReminderSoundIndex])
		{            
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
            
            // Ensure our reminder sound is set
            ReminderSound* sound = [reminderSounds objectAtIndex:item];

            [setPreferencesDict removeAllObjects];
            [Preferences populatePreferenceInDictionary:setPreferencesDict key:ReminderSoundFilenameKey value:[NSString stringWithFormat:@"%@.caf", sound.filename] modifiedDate:[NSDate date] perDevice:NO];
            
            [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];

			return NO; // we will pop the view controller
		}
		else
        {
            if (player && player.playing)
                [player stop];
            
			return YES;
        }
	}
    else if ([Id caseInsensitiveCompare:DrugSortOrderPicklistId] == NSOrderedSame)
    {
        DataModel* dataModel = [DataModel getInstance];
        DrugSortOrder newSortOrder = (DrugSortOrder)item;
        if (newSortOrder != dataModel.globalSettings.drugSortOrder)
        {
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
            
            [setPreferencesDict removeAllObjects];
            [Preferences populatePreferenceInDictionary:setPreferencesDict key:DrugSortOrderKey value:[NSString stringWithFormat:@"%d", (int)newSortOrder] modifiedDate:[NSDate date] perDevice:NO];
            
            [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
            
            return NO; // we will pop the view controller
        }
        else
            return YES;
    }
	else
		return YES;
}

- (void) handlePickCancel:(NSString *)Id subIdentifier:(NSString *)subId
{
    if ([Id caseInsensitiveCompare:ReminderSoundPicklistId] == NSOrderedSame)
    {
        if (player && player.playing)
            [player stop];
    }
}

// Callback for when user requests to leave the group
- (void)handleLeaveGroup
{
    NSString* message = nil;
    if ([[DataModel getInstance] willLeavingGroupTakeAwaySubscription:selectedGroup.groupID])
        message = NSLocalizedStringWithDefaultValue(@"AlertLeaveGroupConfirmationSubscriptionDowngrade", @"Dosecast", [DosecastUtil getResourceBundle], @"Are you sure you want to leave the group? If you do, you will no longer have access to the Pro edition with CloudSync features.", @"The message of the confirmation alert appearing when the user attempts to leave a group"]);
    else if ([[DataModel getInstance] willLeavingGroupTakeAwayPremium:selectedGroup.groupID])
        message = NSLocalizedStringWithDefaultValue(@"AlertLeaveGroupConfirmationPremiumDowngrade", @"Dosecast", [DosecastUtil getResourceBundle], @"Are you sure you want to leave the group? If you do, you will no longer have access to the Premium edition features.", @"The message of the confirmation alert appearing when the user attempts to leave a group"]);
    else
        message = NSLocalizedStringWithDefaultValue(@"AlertLeaveGroupConfirmation", @"Dosecast", [DosecastUtil getResourceBundle], @"Are you sure you want to leave the group?", @"The message of the confirmation alert appearing when the user attempts to leave a group"]);
    
    DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsLeaveGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Leave Group", @"The Leave Group label in the Settings view"])
                                                                               message:message
                                                                                 style:DosecastAlertControllerStyleAlert];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:^(DosecastAlertAction *action) {
                                      if (deletedGroupIndexPath)
                                      {
                                          [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:deletedGroupIndexPath] withRowAnimation:UITableViewRowAnimationNone]; // redraw the cell if the user cancels
                                          deletedGroupIndexPath = nil;
                                      }
                                  }]];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsLeaveGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Leave Group", @"The Leave Group label in the Settings view"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingServer", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating server", @"The message appearing in the spinner view when updating the server"])];
                                      
                                      [[ServerProxy getInstance] groupLeave:selectedGroup.groupID respondTo:self];
                                  }]];
    
    [alert showInViewController:self];
}

- (void)setPreferencesLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];
    [dataModel allowDosecastUserInteractionsWithMessage:YES];

    if (result)
	{
        if ([setPreferencesDict objectForKey:ReminderSoundFilenameKey])
        {
            if (player && player.playing)
                [player stop];
        }
        [self.navigationController popViewControllerAnimated:YES];
        
        [setPreferencesDict removeAllObjects];
        [tableView reloadData];
	}
    else
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
		[alert showInViewController:self];
    }
}

- (void)detachDeviceServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];

    if (status == ServerProxySuccess)
    {
        [dataModel performDeleteAllData];
        [dataModel allowDosecastUserInteractionsWithMessage:YES];
    }
    else
    {
        [dataModel allowDosecastUserInteractionsWithMessage:YES];

        NSString* errorCategory = nil;
        if (status == ServerProxyCommunicationsError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerUnavailableTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Unavailable", @"The title on the alert appearing when the server is unavailable"]);
        else if (status == ServerProxyServerError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalErrorTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Error", @"The title on the alert appearing when the server experiences an internal error"]);
        
        if (status == ServerProxyDeviceDetached)
        {
            DebugLog(@"detach device: detect device detach");

            errorMessage = NSLocalizedStringWithDefaultValue(@"ViewDevicesDeviceRemovedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This device has been removed from your account and all data has been deleted from the device.", @"The message appearing when a device has been removed from a user's account"]);
            DataModel* dataModel = [DataModel getInstance];
            dataModel.wasDetached = NO; // clear the wasDetached flag since we are displaying the error message to the user
            [dataModel writeToFile:nil];
        }
        
        NSMutableString* finalErrorMessage = [NSMutableString stringWithString:@""];
        if (errorCategory)
            [finalErrorMessage appendFormat:@"%@: ", errorCategory];
        [finalErrorMessage appendString:errorMessage];
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:finalErrorMessage];
        [alert showInViewController:self];
    }
}

- (void)groupLeaveServerProxyResponse:(ServerProxyStatus)status groupLeaveResult:(NSString*)groupLeaveResult tookAwaySubscription:(BOOL)tookAwaySubscription tookAwayPremium:(BOOL)tookAwayPremium errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
    __block BOOL leaveGroupSuccess = NO;
    
    if (status == ServerProxySuccess)
	{
        NSString* alertMessage = nil;

        if ([groupLeaveResult compare:@"success"] == NSOrderedSame)
        {
            leaveGroupSuccess = YES;
            
            if (tookAwayPremium)
                alertMessage = NSLocalizedStringWithDefaultValue(@"AlertLeaveGroupResultSuccessDowngrade", @"Dosecast", [DosecastUtil getResourceBundle], @"You have successfully left the group, and you have been downgraded to the demo edition.", @"The message of the alert appearing when a leave group is successful"]);
            else
                alertMessage = NSLocalizedStringWithDefaultValue(@"AlertLeaveGroupResultSuccess", @"Dosecast", [DosecastUtil getResourceBundle], @"You have successfully left the group.", @"The message of the alert appearing when a leave group is successful"]);
        }
        else if ([groupLeaveResult compare:@"noSuchGroup"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorLeaveGroupNoSuchGroupMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"You could not leave the group, as the group could not be found. Please try again, and if the error persists, contact us.", @"The error message when the leave attempt is unsuccessful"]);
        }
        else // if ([groupLeaveResult compare:@"notMember"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorLeaveGroupNotMemberMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"You are not a member of this group. You must be a member to leave a group.", @"The error message when the leave attempt is unsuccessful"]);
        }

        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil message:alertMessage style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          if (leaveGroupSuccess)
                                          {
                                              // If the user left the group by viewing it, pop the controller now.
                                              if ([self.navigationController.topViewController isKindOfClass:[ViewDeleteGroupViewController class]])
                                              {
                                                  [self.navigationController popViewControllerAnimated:YES];
                                              }
                                          }
                                      }]];

        [alert showInViewController:self];
        
        [self.tableView reloadData];
	}
	else if (status != ServerProxyDeviceDetached)
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
	}
}

- (BOOL)handleSetNumericQuantity:(float)val unit:(NSString*)unit identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
    
    [setPreferencesDict removeAllObjects];
    [Preferences populatePreferenceInDictionary:setPreferencesDict key:DoseHistoryDaysKey value:[NSString stringWithFormat:@"%d", (int)val] modifiedDate:[NSDate date] perDevice:NO];

    [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
    
    return NO; // we will pop the view controller
}

- (BOOL)handleLateDoseSettingsDone:(BOOL)flagLateDoses lateDosePeriodSecs:(int)lateDosePeriodSecs
{
    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
    
    [setPreferencesDict removeAllObjects];
    [Preferences populatePreferenceInDictionary:setPreferencesDict key:LateDosePeriodSecsKey value:[NSString stringWithFormat:@"%d", (flagLateDoses ? lateDosePeriodSecs : -1)] modifiedDate:[NSDate date] perDevice:NO];
    
    [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
    
    return NO; // we will pop the view controller
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

// Returns whether to allow the controller to be popped
- (BOOL)handleBooleanDone:(BOOL)value identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
    if ([Id caseInsensitiveCompare:PostponesDisplayedId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:PostponesDisplayedKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];
        
        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller    
    }
    else if ([Id caseInsensitiveCompare:PreventEarlyDrugDosesId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:PreventEarlyDrugDosesKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];
        
        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller            
    }
    else if ([Id caseInsensitiveCompare:ArchivedDrugsDisplayedId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:ArchivedDrugsDisplayedKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];

        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller
    }
    else if ([Id caseInsensitiveCompare:DrugImagesDisplayedId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:DrugImagesDisplayedKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];
        
        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller
    }
    else if ([Id caseInsensitiveCompare:PrivacyModeId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
        
        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:DrugNamesDisplayedInNotificationsKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];

        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller
    }
    else if ([Id caseInsensitiveCompare:LoggingModeId] == NSOrderedSame)
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRefreshingDrugList", @"Dosecast", [DosecastUtil getResourceBundle], @"Refreshing drug list", @"The message appearing in the spinner view when refreshing the drug list"])];

        [setPreferencesDict removeAllObjects];
        [Preferences populatePreferenceInDictionary:setPreferencesDict key:DebugLoggingEnabledKey value:[NSString stringWithFormat:@"%d", (value ? 1 : 0)] modifiedDate:[NSDate date] perDevice:NO];
        
        [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
        
        return NO; // we will pop the view controller
    }
    else
        return YES;
}

// Display the group info now
- (void) displayGroupInfo
{
    // Set Back button title
    NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
    UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
    backButton.style = UIBarButtonItemStylePlain;
    if (!backButton.image)
        backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
    self.navigationItem.backBarButtonItem = backButton;
    
    ViewDeleteGroupViewController* viewGroupController = [[ViewDeleteGroupViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ViewDeleteGroupViewController"]
                                                                                                         bundle:[DosecastUtil getResourceBundle]
                                                                                                      logoImage:selectedGroupLogo
                                                                                                          group:selectedGroup
                                                                                                      viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsViewGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"View Group", @"The View Group label in the Settings view"])
                                                                                                     headerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsGroupInfo", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Info", @"The Group Info label in the Settings view"])
                                                                                                     footerText:nil
                                                                                           showLeaveGroupButton:YES
                                                                                             leftNavButtonTitle:nil
                                                                                            rightNavButtonTitle:nil
                                                                                                       delegate:self];
    [self.navigationController pushViewController:viewGroupController animated:YES];
}

- (void)getBlobServerProxyResponse:(ServerProxyStatus)status data:(NSData*)data errorMessage:(NSString *)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

    if (status == ServerProxySuccess)
    {
        if (data)
            selectedGroupLogo = [UIImage imageWithData:data];
        else
            selectedGroupLogo = nil;
        
        [self displayGroupInfo];
    }
    else
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)groupInfoByIDServerProxyResponse:(ServerProxyStatus)status groupFound:(BOOL)groupFound group:(Group*)group errorMessage:(NSString*)errorMessage
{
    if (status == ServerProxySuccess)
	{
        if (!groupFound)
        {
            [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
            
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorViewGroupGroupNotFoundTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot View Group", @"The title on the alert appearing when a general error occurs"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorViewGroupGroupNotFoundMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The group cannot be found.", @"The title on the alert appearing when a general error occurs"])];
            [alert showInViewController:self];
        }
        else
        {
            selectedGroup = group;

            if (group.logoGUID && [group.logoGUID length] > 0)
            {
                // Get the logo
                [[ServerProxy getInstance] getBlob:group.logoGUID respondTo:self];
            }
            else
            {
                [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

                selectedGroupLogo = nil;
                
                [self displayGroupInfo];
            }
        }
	}
	else
	{
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
        
        if (status != ServerProxyDeviceDetached)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:errorMessage];
            [alert showInViewController:self];
        }
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	DataModel* dataModel = [DataModel getInstance];

    [tableViewSections removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPIShowVersionInSettings])
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsVersion]];
    
    if ([dataModel.apiFlags getFlag:DosecastAPIShowAccount])
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsEdition]];

    [tableViewDisplaySectionRows removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPIMultiPersonSupport])
        [tableViewDisplaySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerDisplaySectionRowsDrugSortOrder]];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableShowArchivedDrugs])
        [tableViewDisplaySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerDisplaySectionRowsDisplayArchivedDrugs]];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableShowDrugImages])
        [tableViewDisplaySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerDisplaySectionRowsDisplayDrugImages]];
    if ([tableViewDisplaySectionRows count] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsDisplay]];

    [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsScheduling]];
    [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsReminders]];
    
    [tableViewSecurityPrivacySectionRows removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableShowDrugNamesInNotifications])
        [tableViewSecurityPrivacySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerSecurityPrivacySectionRowsPrivacyMode]];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableDebugLog])
        [tableViewSecurityPrivacySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerSecurityPrivacySectionRowsLogging]];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnablePasscodeSettings])
        [tableViewSecurityPrivacySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerSecurityPrivacySectionRowsChangePasscode]];
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableDeleteAllDataSettings])
        [tableViewSecurityPrivacySectionRows addObject:[NSNumber numberWithInt:SettingsViewControllerSecurityPrivacySectionRowsDeleteAllData]];
    if ([tableViewSecurityPrivacySectionRows count] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsSecurityPrivacy]];
    
    [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsHistory]];
    
    if ([dataModel.apiFlags getFlag:DosecastAPIEnableGroups])
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsGroups]];

    if ([dataModel.apiFlags getFlag:DosecastAPIEnableSync])
        [tableViewSections addObject:[NSNumber numberWithInt:SettingsViewControllerSectionsSync]];

	return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (settingsSection == SettingsViewControllerSectionsVersion)
    {
#ifdef DEBUG
        return 2; // Display server user ID in debug
#else
        return 1;
#endif
    }
    else if (settingsSection == SettingsViewControllerSectionsDisplay)
        return [tableViewDisplaySectionRows count];
    else if (settingsSection == SettingsViewControllerSectionsScheduling)
        return 3;
    else if (settingsSection == SettingsViewControllerSectionsReminders)
        return 3;
    else if (settingsSection == SettingsViewControllerSectionsSecurityPrivacy)
        return [tableViewSecurityPrivacySectionRows count];
    else if (settingsSection == SettingsViewControllerSectionsHistory)
        return 3;
    else if (settingsSection == SettingsViewControllerSectionsGroups)
        return [[DataModel getInstance].groups count]+1;
    else if (settingsSection == SettingsViewControllerSectionsSync)
        return 3;
    else
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	DataModel* dataModel = [DataModel getInstance];
    
    if (settingsSection == SettingsViewControllerSectionsVersion)
    {
        if (indexPath.row == 0)
        {
            // Extract the version header and label from the version string stored in the data model
            NSString* versionStr = dataModel.clientVersion;
            
            NSRange spaceRange = [versionStr rangeOfString:@" "];
            
            NSRange headerRange = NSMakeRange(0, spaceRange.location);
            UILabel* versionHeader = (UILabel *)[versionCell viewWithTag:1];
            NSString* versionHeaderText = [versionStr substringWithRange:headerRange];
            versionHeader.text = versionHeaderText;
            NSRange numRange = NSMakeRange(spaceRange.location+1, [versionStr length]-[versionHeaderText length]-1);
            UILabel* versionLabel = (UILabel *)[versionCell viewWithTag:2];

            versionLabel.text = [versionStr substringWithRange:numRange];  
            return versionCell;
        }
		else // indexPath.row == 1
        {
            UILabel* userIDLabel = (UILabel *)[serverUserIDCell viewWithTag:2];
            userIDLabel.text = dataModel.userIDAbbrev;
            return serverUserIDCell;
        }
    }
    else if (settingsSection == SettingsViewControllerSectionsEdition)
	{
		UILabel* accountTypeHeader = (UILabel *)[accountCell viewWithTag:1];
		UILabel* accountTypeLabel = (UILabel *)[accountCell viewWithTag:3];
        UILabel* subscriptionStatusHeader = (UILabel *)[accountCell viewWithTag:2];
        UILabel* subscriptionStatusLabel = (UILabel *)[accountCell viewWithTag:4];

        accountTypeHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEdition", @"Dosecast", [DosecastUtil getResourceBundle], @"Edition", @"The edition label in the Settings view"]);

        AccountType accountType = dataModel.globalSettings.accountType;
        accountCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        accountCell.selectionStyle = UITableViewCellSelectionStyleGray;

		if (accountType == AccountTypeDemo)
			accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionDemo", @"Dosecast", [DosecastUtil getResourceBundle], @"Free", @"The demo edition label in the Settings view"]);
		else if (accountType == AccountTypePremium)
			accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPremium", @"Dosecast", [DosecastUtil getResourceBundle], @"Premium", @"The Premium edition label in the Settings view"]);
        else
            accountTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionPro", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro with CloudSync", @"The Premium edition label in the Settings view"]);

        if (dataModel.globalSettings.subscriptionExpires &&
            ((accountType == AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0) ||
            (accountType != AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] < 0)))
        {
            subscriptionStatusHeader.hidden = NO;
            subscriptionStatusHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscription", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscription", @"The edition label in the Settings view"]);

            subscriptionStatusLabel.hidden = NO;
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];

            if ([dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0)
            {
                subscriptionStatusLabel.textColor = [UIColor blackColor];
                subscriptionStatusLabel.text = [NSString stringWithFormat:
                                                NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscriptionExpiresPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Expires on %@", @"The edition label in the Settings view"]),
                                                [dateFormatter stringFromDate:dataModel.globalSettings.subscriptionExpires]];
            }
            else
            {
                subscriptionStatusLabel.textColor = [DosecastUtil getDrugWarningLabelColor];
                subscriptionStatusLabel.text = [NSString stringWithFormat:
                                                NSLocalizedStringWithDefaultValue(@"ViewSettingsSubscriptionExpiredPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Expired on %@", @"The edition label in the Settings view"]),
                                                [dateFormatter stringFromDate:dataModel.globalSettings.subscriptionExpires]];
            }
        }
        else
        {
            subscriptionStatusHeader.hidden = YES;
            subscriptionStatusLabel.hidden = YES;
        }
        
		return accountCell;
	}	
    else if (settingsSection == SettingsViewControllerSectionsDisplay)
    {
        SettingsViewControllerDisplaySectionRows displayRow = (SettingsViewControllerDisplaySectionRows)[[tableViewDisplaySectionRows objectAtIndex:indexPath.row] intValue];
        
        if (displayRow == SettingsViewControllerDisplaySectionRowsDrugSortOrder)
        {
            UILabel* header = (UILabel *)[drugSortOrderCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrder", @"Dosecast", [DosecastUtil getResourceBundle], @"Sort Drugs By", @"The drug sort order label in the Settings view"]);
            UILabel* label = (UILabel *)[drugSortOrderCell viewWithTag:2];
            
            if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByNextDoseTime)
                label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByNextDoseTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of next dose", @"The drug sort order by next dose time label in the Settings view"]);
            else if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByPerson)
                label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByPerson", @"Dosecast", [DosecastUtil getResourceBundle], @"Person", @"The drug sort order by person label in the Settings view"]);
            else if (dataModel.globalSettings.drugSortOrder == DrugSortOrderByDrugName)
                label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug name", @"The drug sort order by drug name label in the Settings view"]);
            else // DrugSortOrderByDrugType
                label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug type", @"The drug sort order by drug type label in the Settings view"]);
            
            return drugSortOrderCell;
        }
        else if (displayRow == SettingsViewControllerDisplaySectionRowsDisplayArchivedDrugs)
        {
            UILabel* header = (UILabel *)[displayArchivedDrugsCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsShowArchivedDrugs", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Archived Drugs", @"The show archived drugs label in the Settings view"]);

            UILabel* value = (UILabel *)[displayArchivedDrugsCell viewWithTag:2];
            if (dataModel.globalSettings.archivedDrugsDisplayed)
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);

            return displayArchivedDrugsCell;
        }
        else if (displayRow == SettingsViewControllerDisplaySectionRowsDisplayDrugImages)
        {
            UILabel* header = (UILabel *)[displayDrugImagesCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsShowDrugImages", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Drug Images", @"The show drug images label in the Settings view"]);
            
            UILabel* value = (UILabel *)[displayDrugImagesCell viewWithTag:2];
            if (dataModel.globalSettings.drugImagesDisplayed)
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);
            
            return displayDrugImagesCell;
        }
        else
            return nil;
    }
    else if (settingsSection == SettingsViewControllerSectionsScheduling)
	{
		if (indexPath.row == 0)
		{
			UILabel* bedtimeHeader = (UILabel *)[bedtimeCell viewWithTag:1];
			bedtimeHeader.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimeSettingsIntervalRemindersSwitch", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval Reminders During Bedtime", @"The label appearing in the Bedtime Settings view for the interval reminders switch cell"]);
			
			BOOL bedtimeDefined = (dataModel.globalSettings.bedtimeStart != -1 || dataModel.globalSettings.bedtimeEnd != -1);
			UILabel* bedtimeOnOffLabel = (UILabel *)[bedtimeCell viewWithTag:3];
			UILabel* bedtimeLabel = (UILabel *)[bedtimeCell viewWithTag:2];
			bedtimeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime", @"The title of the Bedtime Period view"]);
			UILabel* bedtimePeriodLabel = (UILabel *)[bedtimeCell viewWithTag:4];
			if (bedtimeDefined)
			{
				bedtimeOnOffLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);

				NSDate* bedtimeStartDate = nil;
				NSDate* bedtimeEndDate = nil;
				[dataModel getBedtimeAsDates:&bedtimeStartDate bedtimeEnd:&bedtimeEndDate];
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];	
				bedtimePeriodLabel.text = [NSString stringWithFormat:@"%@ - %@",
										   [dateFormatter stringFromDate:bedtimeStartDate],
										   [dateFormatter stringFromDate:bedtimeEndDate]];
			}
			else
			{
				bedtimeOnOffLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
			}
			bedtimeLabel.hidden = !bedtimeDefined;
			bedtimePeriodLabel.hidden = !bedtimeDefined;

			return bedtimeCell;
		}
		else if (indexPath.row == 1)
		{
			UILabel* earlyWarningHeader = (UILabel *)[earlyWarningCell viewWithTag:1];
			earlyWarningHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsPreventEarlyDrugDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Prevent Early Drug Doses", @"The Prevent Early Drug Doses label in the Settings view"]);

            UILabel* earlyWarningValue = (UILabel *)[earlyWarningCell viewWithTag:2];
            if (dataModel.globalSettings.preventEarlyDrugDoses)
                earlyWarningValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                earlyWarningValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);
			
            return earlyWarningCell;
		}
        else // if (indexPath.row == 2)
        {
            UILabel* label = (UILabel *)[moveScheduledRemindersCell viewWithTag:1];
            label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Move All Scheduled Reminders Earlier or Later", @"The title of the settings button for deleting all data"]);

            return moveScheduledRemindersCell;
        }
	}
    else if (settingsSection == SettingsViewControllerSectionsReminders)
	{
        if (indexPath.row == 0)
        {
            UILabel* soundHeader = (UILabel *)[reminderSoundCell viewWithTag:1];
            soundHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsReminderSound", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminder Sound", @"The Reminder Sound label in the Settings view"]);
            UILabel* soundLabel = (UILabel *)[reminderSoundCell viewWithTag:2];
            
            int currentReminderSoundIndex = [self getCurrentReminderSoundIndex];
            ReminderSound* sound = [reminderSounds objectAtIndex:currentReminderSoundIndex];
            soundLabel.text = sound.displayName;
            return reminderSoundCell;
        }
        else if (indexPath.row == 1)
        {
            UILabel* header = (UILabel *)[secondaryRemindersPeriodCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSecondaryReminderAfter", @"Dosecast", [DosecastUtil getResourceBundle], @"Secondary Reminder After", @"The Secondary Reminder label in the Settings view"]);
            UILabel* value = (UILabel *)[secondaryRemindersPeriodCell viewWithTag:2];
            NSMutableString* periodLabelText = [NSMutableString stringWithString:@""];
            
            int timePeriodSecs = dataModel.globalSettings.secondaryReminderPeriodSecs;
            if (timePeriodSecs == 0)
            {
                [periodLabelText setString:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"])];
            }
            else
            {
                int numMinutes = timePeriodSecs/60;
                int numHours = numMinutes/60;
                int numMinutesLeft = numMinutes%60;
                if (numHours > 0)
                    [periodLabelText appendString:[self timePeriodStringLabelForHours:numHours]];
                if (numMinutesLeft > 0 || numHours == 0)
                {
                    if (numHours > 0)
                        [periodLabelText appendString:@" "];
                    [periodLabelText appendString:[self timePeriodStringLabelForMinutes:numMinutesLeft]];
                }
            }
            value.text = periodLabelText;
            return secondaryRemindersPeriodCell;
        }
        else // if indexPath.row == 2
        {
            UILabel* label = (UILabel *)[refreshAllRemindersCell viewWithTag:1];
            label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsRefreshAllRemindersButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Refresh All Reminders", @"The title of the settings button for refreshing all reminders"]);
            
            return refreshAllRemindersCell;
        }
	}
    else if (settingsSection == SettingsViewControllerSectionsSecurityPrivacy)
	{
        SettingsViewControllerSecurityPrivacySectionRows securityRow = (SettingsViewControllerSecurityPrivacySectionRows)[[tableViewSecurityPrivacySectionRows objectAtIndex:indexPath.row] intValue];
        
        if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsPrivacyMode)
        {
            UILabel* header = (UILabel *)[privacyModeCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsPrivacyMode", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Mode", @"The Privacy Mode label in the Settings view"]);
            
            UILabel* value = (UILabel *)[privacyModeCell viewWithTag:2];
            if (!dataModel.globalSettings.drugNamesDisplayedInNotifications)
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);
            
            return privacyModeCell;
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsChangePasscode)
        {
            UILabel* changePasscodeLabel = (UILabel *)[changePasscodeCell viewWithTag:1];
            changePasscodeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityChangePasscode", @"Dosecast", [DosecastUtil getResourceBundle], @"Change Passcode", @"The change password label in the Settings view"]);
            
            return changePasscodeCell;
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsDeleteAllData)
        {
            UILabel* deleteAllDataLabel = (UILabel *)[deleteAllDataCell viewWithTag:1];
            deleteAllDataLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsDeleteAllDataButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete All Data", @"The title of the settings button for deleting all data"]);
            
            return deleteAllDataCell;
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsLogging)
        {
            UILabel* header = (UILabel *)[loggingCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityLogging", @"Dosecast", [DosecastUtil getResourceBundle], @"Debug Logging", @"The Privacy Mode label in the Settings view"]);
            
            UILabel* value = (UILabel *)[loggingCell viewWithTag:2];
            if (dataModel.globalSettings.debugLoggingEnabled)
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDosesOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Log Missed Doses cell of the Drug Edit view"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDosesOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Log Missed Doses cell of the Drug Edit view"]);

            return loggingCell;
        }
        else
            return nil;
	}
    else if (settingsSection == SettingsViewControllerSectionsHistory)
	{
        if (indexPath.row == 0)
        {
            NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
            NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
            NSString* historyDurationUnit = nil;
            if ([DosecastUtil shouldUseSingularForInteger:dataModel.globalSettings.doseHistoryDays])
                historyDurationUnit = daySingular;
            else
                historyDurationUnit = dayPlural;		
            
            UILabel* historyHeader = (UILabel *)[historyDurationCell viewWithTag:1];
            historyHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryDuration", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose History Stored", @"The Dose History Stored label in the Settings view"]);
            UILabel* historyLabel = (UILabel *)[historyDurationCell viewWithTag:2];
            historyLabel.text = [NSString stringWithFormat:@"%d %@", dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
            return historyDurationCell;
        }
        else if (indexPath.row == 1)
        {
            UILabel* displayPostponeEventsHeader = (UILabel *)[displayPostponeEventsCell viewWithTag:1];
			displayPostponeEventsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryShowPostponeEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Postpone Events", @"The Show Postpone Events label in the Settings view"]);

            UILabel* displayPostponeEventsValue = (UILabel *)[displayPostponeEventsCell viewWithTag:2];
            if (dataModel.globalSettings.postponesDisplayed)
                displayPostponeEventsValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                displayPostponeEventsValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);

			return displayPostponeEventsCell;
        }
        else // indexPath.row == 2
        {
            BOOL flagLateDoses = (dataModel.globalSettings.lateDosePeriodSecs > 0);
            int lateDosePeriodSecs = dataModel.globalSettings.lateDosePeriodSecs;
            
            UILabel* lateDoseHeader = (UILabel *)[lateDoseCell viewWithTag:1];
			lateDoseHeader.text = NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsFlagLateDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Flag Doses Taken Late", @"The Flag Late Doses label in the Late Dose Settings view"]);
            UILabel* lateDoseValue = (UILabel *)[lateDoseCell viewWithTag:3];
            if (flagLateDoses)
                lateDoseValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                lateDoseValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);

            UILabel* lateDosePeriodHeader = (UILabel *)[lateDoseCell viewWithTag:2];
            UILabel* lateDosePeriodValue = (UILabel *)[lateDoseCell viewWithTag:4];
            if (flagLateDoses)
            {
                lateDosePeriodHeader.text = NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsLateDosePeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Late After", @"The Late Dose Period label in the Late Dose Settings view"]);
                
                int numMinutes = lateDosePeriodSecs/60;
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
                lateDosePeriodValue.text = periodLabelText;
            }
            lateDosePeriodHeader.hidden = !flagLateDoses;
            lateDosePeriodValue.hidden = !flagLateDoses;
            
			return lateDoseCell;
        }
	}
    else if (settingsSection == SettingsViewControllerSectionsGroups)
    {
        if (indexPath.row == [[DataModel getInstance].groups count]) // the add group cell
        {
            UILabel* addGroupLabel = (UILabel *)[addGroupCell viewWithTag:1];
            addGroupLabel.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsJoinGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Join Group", @"The Join Groups label in the Settings view"]);
            return addGroupCell;
        }
        else
        {
            static NSString *MyIdentifier = @"GroupCellIdentifier";
            
            UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
            if (cell == nil) {
                [[DosecastUtil getResourceBundle] loadNibNamed:@"GroupTableViewCell" owner:self options:nil];
                cell = groupCell;
                groupCell = nil;
            }
            
            UILabel* groupLabel = (UILabel*)[cell viewWithTag:1];
            Group* group = (Group*)[[DataModel getInstance].groups objectAtIndex:indexPath.row];
            groupLabel.text = group.displayName;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            return cell;
        }
    }
    else if (settingsSection == SettingsViewControllerSectionsSync)
    {
        if (indexPath.row == 0)
        {
            UILabel* label = (UILabel *)[syncAddDeviceCell viewWithTag:1];
            label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSyncAddDevice", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Another Device To This Account", @"The add device button label for sync in the Settings view"]);
            return syncAddDeviceCell;
        }
        else if (indexPath.row == 1)
        {
            UILabel* label = (UILabel *)[syncMoveDeviceCell viewWithTag:1];
            label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSyncMoveDevice", @"Dosecast", [DosecastUtil getResourceBundle], @"Move This Device To Another Account", @"The move device button label for sync in the Settings view"]);
            return syncMoveDeviceCell;
        }
        else // if (indexPath.row == 2)
        {
            UILabel* label = (UILabel *)[syncViewDevicesCell viewWithTag:1];
            label.text = NSLocalizedStringWithDefaultValue(@"ViewSettingsSyncViewDevices", @"Dosecast", [DosecastUtil getResourceBundle], @"View All Devices On This Account", @"The view devices button label for sync in the Settings view"]);
            return syncViewDevicesCell;
        }
    }
	else
		return nil;
}

- (void) handleDeviceDetached
{
    // Refresh the table's data
    [self.tableView reloadData];    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];
	DataModel* dataModel = [DataModel getInstance];

    if (settingsSection == SettingsViewControllerSectionsEdition)
    {
        AccountType accountType = dataModel.globalSettings.accountType;
        if (dataModel.globalSettings.subscriptionExpires &&
            ((accountType == AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] > 0) ||
             (accountType != AccountTypeSubscription && [dataModel.globalSettings.subscriptionExpires timeIntervalSinceNow] < 0)))
        {
            return 88;
        }
        else
            return 44;
    }
    else if (settingsSection == SettingsViewControllerSectionsScheduling)
	{
		if (indexPath.row == 0)
		{
			if (dataModel.globalSettings.bedtimeStart == -1 && dataModel.globalSettings.bedtimeEnd == -1)
				return 88 - BEDTIME_LABEL_HEIGHT;
			else
				return 88;
		}
		else
			return 44;
	}
    else if (settingsSection == SettingsViewControllerSectionsHistory)
    {
        if (indexPath.row == 0)
            return 44;
        else if (indexPath.row == 1)
            return 44;
        else // if (indexPath.row == 2)
        {
            if (dataModel.globalSettings.lateDosePeriodSecs > 0)
                return 88;
            else
                return 88 - LATE_DOSE_PERIOD_LABEL_HEIGHT;
        }
    }
	else
		return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (settingsSection == SettingsViewControllerSectionsDisplay)
    {
		return NSLocalizedStringWithDefaultValue(@"ViewSettingsDisplayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Display", @"The display header of the Settings view"]);
    }
    else if (settingsSection == SettingsViewControllerSectionsScheduling)
	{
		return NSLocalizedStringWithDefaultValue(@"ViewSettingsSchedulingHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Scheduling", @"The scheduling header of the Settings view"]);
	}
	else if (settingsSection == SettingsViewControllerSectionsReminders)
	{
		return NSLocalizedStringWithDefaultValue(@"ViewSettingsRemindersHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminders", @"The reminders header of the Settings view"]);
	}
	else if (settingsSection == SettingsViewControllerSectionsSecurityPrivacy)
	{
		return NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Security and Privacy", @"The security header in the Settings view"]);
	}
	else if (settingsSection == SettingsViewControllerSectionsHistory)
	{
		return NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"History", @"The history header of the Settings view"]);
	}
    else if (settingsSection == SettingsViewControllerSectionsGroups)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewSettingsGroups", @"Dosecast", [DosecastUtil getResourceBundle], @"Groups", @"The Groups label in the Settings view"]);
    }
    else if (settingsSection == SettingsViewControllerSectionsSync)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewSettingsSync", @"Dosecast", [DosecastUtil getResourceBundle], @"Cloud Sync", @"The Sync label in the Settings view"]);
    }
	else
		return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];
	DataModel* dataModel = [DataModel getInstance];

    if (settingsSection == SettingsViewControllerSectionsEdition)
    {
        if (dataModel.globalSettings.accountType != AccountTypeSubscription)
            return NSLocalizedStringWithDefaultValue(@"ViewSettingsEditionDemoFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Tap to learn more about features in the Pro edition with CloudSync.", @"The demo edition footer of the Settings view"]);
        else
            return nil;
    }
    else if (settingsSection == SettingsViewControllerSectionsGroups)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Groups enable you to join a cohort of other people who have similar conditions to you.", @"The Groups footer label in the Settings view"]);
    }
    else if (settingsSection == SettingsViewControllerSectionsSync)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewSettingsSyncFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Cloud Sync keeps all drug data up-to-date across multiple devices, and enables dose reminders to be delivered to all devices simultaneously.", @"The Sync footer label in the Settings view"]);
    }
	else
		return nil;
}

- (void)getRendezvousCodeServerProxyResponse:(ServerProxyStatus)status rendezvousCode:(NSString*)rendezvousCode expires:(NSDate*)expires errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
    
    if (status == ServerProxySuccess)
    {
        // Set Back button title
        NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
        UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
        backButton.style = UIBarButtonItemStylePlain;
        if (!backButton.image)
            backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
        self.navigationItem.backBarButtonItem = backButton;
                
        SyncAddDeviceViewController* controller = [[SyncAddDeviceViewController alloc]
                                                    initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"SyncAddDeviceViewController"]
                                                    bundle:[DosecastUtil getResourceBundle]
                                                   rendezvousCode:rendezvousCode
                                                   expires:expires];
        [self.navigationController pushViewController:controller animated:YES];
    }
    else if (status != ServerProxyDeviceDetached)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)getAttachedDevicesServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
    
    if (status == ServerProxySuccess)
    {
        // Set Back button title
        NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
        UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
        backButton.style = UIBarButtonItemStylePlain;
        if (!backButton.image)
            backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
        self.navigationItem.backBarButtonItem = backButton;
        
        SyncViewDevicesViewController* controller = [[SyncViewDevicesViewController alloc]
                                                   initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"SyncViewDevicesViewController"]
                                                   bundle:[DosecastUtil getResourceBundle]
                                                    syncDeviceList:syncDevices
                                                     delegate:self];
        [self.navigationController pushViewController:controller animated:YES];
    }
    else if (status != ServerProxyDeviceDetached)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)moveScheduledRemindersLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];
    [dataModel allowDosecastUserInteractionsWithMessage:YES];
    
    if (!result)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

// Callback for seconds value
// If value < 0, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetTimePeriodValue:(int)timePeriodSecs
                     forNibNamed:(NSString*)nibName
                      identifier:(int)uniqueID // a unique identifier for the current picker
{
    if (uniqueID == 0) // move scheduled reminders earlier/later
    {
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];

        NSTimeInterval timeInterval = timePeriodSecs;
        
        if (isMovingScheduledRemindersEarlier)
            timeInterval = -timePeriodSecs;
        
        [[LocalNotificationManager getInstance] moveScheduledReminders:timeInterval
                                                             respondTo:self
                                                                 async:YES];
        return YES;
    }
    else if (uniqueID == 1) // secondary reminder period
    {
        if (timePeriodSecs < 0)
            timePeriodSecs = 0;
        
        int currValue = [DataModel getInstance].globalSettings.secondaryReminderPeriodSecs;

        if (timePeriodSecs != currValue)
        {
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
            
            [setPreferencesDict removeAllObjects];
            
            [Preferences populatePreferenceInDictionary:setPreferencesDict key:SecondaryReminderPeriodSecsKey value:[NSString stringWithFormat:@"%d", timePeriodSecs] modifiedDate:[NSDate date] perDevice:NO];
            
            [[LocalNotificationManager getInstance] setPreferences:setPreferencesDict respondTo:self async:YES];
            
            return NO; // we will pop the view controller
        }
        else
            return YES;
    }
    else
        return YES;
}

- (void) handleDisplayPremiumFeatureAlert:(NSString*)message
{
    DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro Feature", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                               message:message
                                                                                 style:DosecastAlertControllerStyleAlert];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFeatureSubscriptionButtonSubscribe", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe", @"The Upgrade button of the alert appearing when a premium feature is accessed in demo edition"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action){
                                      // Push the account view controller
                                      
                                      // Set Back button title
                                      NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
                                      UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
                                      backButton.style = UIBarButtonItemStylePlain;
                                      if (!backButton.image)
                                          backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
                                      self.navigationItem.backBarButtonItem = backButton;
                                      
                                      // Display AccountViewController in new view
                                      AccountViewController* accountController = [[AccountViewController alloc]
                                                                                  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"AccountViewController"]
                                                                                  bundle:[DosecastUtil getResourceBundle] delegate:nil];
                                      [self.navigationController pushViewController:accountController animated:YES];
                                  }]];
    
    [alert showInViewController:self];
}

- (void) handleMoveScheduledReminders:(BOOL)moveEarlier
{
    isMovingScheduledRemindersEarlier = moveEarlier;
    
    NSString* cellHeader = nil;
    
    if (isMovingScheduledRemindersEarlier)
        cellHeader = NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersEarlierBy", @"Dosecast", [DosecastUtil getResourceBundle], @"Earlier By", @"The Late Dose Period label in the Late Dose Settings view"]);
    else
        cellHeader = NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersLaterBy", @"Dosecast", [DosecastUtil getResourceBundle], @"Later By", @"The Late Dose Period label in the Late Dose Settings view"]);
    
    // Display TimePeriodViewController in new view
    TimePeriodViewController* timePeriodController = [[TimePeriodViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TimePeriodViewController"]
                                                                                                bundle:[DosecastUtil getResourceBundle]
                                                                                 initialTimePeriodSecs:0
                                                                                        minuteInterval:PERIOD_MINUTE_INTERVAL
                                                                                              maxHours:PERIOD_MAX_HOURS
                                                                                            identifier:0
                                                                                             viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Move Scheduled Reminders", @"The title of the Late Dose Settings view"])
                                                                                            cellHeader:cellHeader
                                                                                          displayNever:NO
                                                                                            neverTitle:nil
                                                                                             allowZero:NO
                                                                                               nibName:@"TimePeriodTableViewCell"
                                                                                              delegate:self];
    
    [self.navigationController pushViewController:timePeriodController animated:YES];
}

- (void) handleRefreshAllReminders:(NSTimer*)theTimer
{
    [[LocalNotificationManager getInstance] refreshAllNotifications];
    
    DataModel* dataModel = [DataModel getInstance];
    [dataModel allowDosecastUserInteractionsWithMessage:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	DataModel* dataModel = [DataModel getInstance];

    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (settingsSection == SettingsViewControllerSectionsEdition)
	{			
        // Set Back button title
        NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
        UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
        backButton.style = UIBarButtonItemStylePlain;
        if (!backButton.image)
            backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
        self.navigationItem.backBarButtonItem = backButton;
        
        // Display AccountViewController in new view
        AccountViewController* accountController = [[AccountViewController alloc]
                                                    initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"AccountViewController"]
                                                             bundle:[DosecastUtil getResourceBundle] delegate:self];
        [self.navigationController pushViewController:accountController animated:YES];
	}
    else if (settingsSection == SettingsViewControllerSectionsDisplay)
	{
        SettingsViewControllerDisplaySectionRows displayRow = (SettingsViewControllerDisplaySectionRows)[[tableViewDisplaySectionRows objectAtIndex:indexPath.row] intValue];
        
        if (displayRow == SettingsViewControllerDisplaySectionRowsDrugSortOrder)
        {
            NSArray* items = [NSArray arrayWithObjects:
                              NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByNextDoseTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of next dose", @"The drug sort order by next dose time label in the Settings view"]),
                              NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByPerson", @"Dosecast", [DosecastUtil getResourceBundle], @"Person", @"The drug sort order by person label in the Settings view"]),
                              NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug name", @"The drug sort order by drug name label in the Settings view"]),
                              NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrderByDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug type", @"The drug sort order by drug type label in the Settings view"]),
                              nil];
            int selectedItem = (int)dataModel.globalSettings.drugSortOrder;
            
            PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                          bundle:[DosecastUtil getResourceBundle]
                                                          nonEditableItems:items
                                                          editableItems:nil
                                                          selectedItem:selectedItem
                                                          allowEditing:NO
                                                          viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsDisplayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Display", @"The display header of the Settings view"])
                                                          headerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsDrugSortOrder", @"Dosecast", [DosecastUtil getResourceBundle], @"Sort Drugs By", @"The drug sort order label in the Settings view"])
                                                          footerText:nil
                                                          addItemCellText:nil
                                                          addItemPlaceholderText:nil
                                                          displayNone:NO
                                                          identifier:DrugSortOrderPicklistId
                                                          subIdentifier:nil
                                                          delegate:self];
            [self.navigationController pushViewController:picklistController animated:YES];
        }
        else if (displayRow == SettingsViewControllerDisplaySectionRowsDisplayArchivedDrugs)
        {
            BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                        initialValue:dataModel.globalSettings.archivedDrugsDisplayed
                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsDisplayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Display", @"The display header of the Settings view"])
                                                        displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsShowArchivedDrugs", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Archived Drugs", @"The show archived drugs label in the Settings view"])
                                                        headerText:nil
                                                        footerText:nil
                                                        identifier:ArchivedDrugsDisplayedId
                                                        subIdentifier:nil
                                                        delegate:self];
            
            [self.navigationController pushViewController:booleanController animated:YES];
        }
        else if (displayRow == SettingsViewControllerDisplaySectionRowsDisplayDrugImages)
        {
            BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                        initialValue:dataModel.globalSettings.drugImagesDisplayed
                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsDisplayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Display", @"The display header of the Settings view"])
                                                        displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsShowDrugImages", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Drug Images", @"The show drug images label in the Settings view"])
                                                        headerText:nil
                                                        footerText:nil
                                                        identifier:DrugImagesDisplayedId
                                                        subIdentifier:nil
                                                        delegate:self];
            
            [self.navigationController pushViewController:booleanController animated:YES];
        }
	}
	else if (settingsSection == SettingsViewControllerSectionsScheduling)
	{
        if (indexPath.row == 0)
        {
            BedtimeSettingsViewController* bedtimeSettingsController = [[BedtimeSettingsViewController alloc]
                                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BedtimeSettingsViewController"]
                                                                                 bundle:[DosecastUtil getResourceBundle]
                                                                               delegate:self];
            [self.navigationController pushViewController:bedtimeSettingsController animated:YES];
        }
        else if (indexPath.row == 1)
        {
            BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                        initialValue:dataModel.globalSettings.preventEarlyDrugDoses
                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsSchedulingHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Scheduling", @"The scheduling header of the Settings view"])
                                                        displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsPreventEarlyDrugDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Prevent Early Drug Doses", @"The Prevent Early Drug Doses label in the Settings view"])
                                                        headerText:nil
                                                        footerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsSchedulingFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"This setting will display a warning when a dose is taken over 1 hour early.", @"The scheduling footer of the Settings view"])
                                                        identifier:PreventEarlyDrugDosesId
                                                        subIdentifier:nil
                                                        delegate:self];
            
            [self.navigationController pushViewController:booleanController animated:YES];
        }
        else // if (indexPath.row == 2)
        {
            isMovingScheduledRemindersEarlier = NO;
            
            DosecastAlertController* moveOptionController = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Move Scheduled Reminders", @"The title of the Late Dose Settings view"])
                                                                             message:nil
                                                                               style:DosecastAlertControllerStyleActionSheet];
            
            [moveOptionController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];
            
            [moveOptionController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersEarlier", @"Dosecast", [DosecastUtil getResourceBundle], @"Earlier", @"The text on the Cancel button in an alert"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action) {
                                              [self handleMoveScheduledReminders:YES];
                                          }]];

            [moveOptionController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsMoveScheduledRemindersLater", @"Dosecast", [DosecastUtil getResourceBundle], @"Later", @"The text on the Cancel button in an alert"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action) {
                                              [self handleMoveScheduledReminders:NO];
                                          }]];
            
            [moveOptionController showInViewController:self sourceView:[self.tableView cellForRowAtIndexPath:indexPath]];
        }
	}
	else if (settingsSection == SettingsViewControllerSectionsReminders)
	{
        if (indexPath.row == 0)
        {
            NSMutableArray* soundDisplayNames = [[NSMutableArray alloc] init];
            int numSounds = (int)[reminderSounds count];
            for (int i = 0; i < numSounds; i++)
            {
                ReminderSound* sound = [reminderSounds objectAtIndex:i];
                [soundDisplayNames addObject:sound.displayName];
            }

            PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                           initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                                    bundle:[DosecastUtil getResourceBundle]
                                                          nonEditableItems:soundDisplayNames
                                                             editableItems:nil
                                                              selectedItem:[self getCurrentReminderSoundIndex]
                                                              allowEditing:NO
                                                                 viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsRemindersHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminders", @"The reminders header of the Settings view"])
                                                                headerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsReminderSound", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminder Sound", @"The Reminder Sound label in the Settings view"])
                                                                footerText:nil
                                                           addItemCellText:nil
                                                    addItemPlaceholderText:nil
                                                               displayNone:NO
                                                                identifier:ReminderSoundPicklistId
                                                             subIdentifier:nil
                                                                  delegate:self];
            [self.navigationController pushViewController:picklistController animated:YES];
        }
        else if (indexPath.row == 1)
        {
            // Display TimePeriodViewController in new view
            TimePeriodViewController* timePeriodController = [[TimePeriodViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TimePeriodViewController"]
                                                                                                        bundle:[DosecastUtil getResourceBundle]
                                                                                         initialTimePeriodSecs:dataModel.globalSettings.secondaryReminderPeriodSecs
                                                                                                minuteInterval:PERIOD_MINUTE_INTERVAL
                                                                                                      maxHours:PERIOD_MAX_HOURS
                                                                                                    identifier:1
                                                                                                     viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsRemindersHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminders", @"The reminders header of the Settings view"])
                                                                                                    cellHeader:NSLocalizedStringWithDefaultValue(@"ViewSettingsSecondaryReminderAfter", @"Dosecast", [DosecastUtil getResourceBundle], @"Secondary Reminder After", @"The Secondary Reminder label in the Settings view"])
                                                                                                  displayNever:YES
                                                                                                    neverTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"])
                                                                                                     allowZero:NO
                                                                                                       nibName:@"TimePeriodTableViewCell"
                                                                                                      delegate:self];
            
            [self.navigationController pushViewController:timePeriodController animated:YES];
        }
        else // if indexPath.row == 2
        {
            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating reminders"])];

            [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleRefreshAllReminders:) userInfo:nil repeats:NO];
        }
    }
    else if (settingsSection == SettingsViewControllerSectionsSecurityPrivacy)
	{
        SettingsViewControllerSecurityPrivacySectionRows securityRow = (SettingsViewControllerSecurityPrivacySectionRows)[[tableViewSecurityPrivacySectionRows objectAtIndex:indexPath.row] intValue];
        
        if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsPrivacyMode)
        {
            BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                        initialValue:!dataModel.globalSettings.drugNamesDisplayedInNotifications
                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Security and Privacy", @"The security header in the Settings view"])
                                                        displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsPrivacyMode", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Mode", @"The Privacy Mode label in the Settings view"])
                                                        headerText:nil
                                                        footerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsPrivacyModeFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"When this setting is turned on, drug names will not be displayed in notifications.", @"The Privacy Mode label in the Settings view"])
                                                        identifier:PrivacyModeId
                                                        subIdentifier:nil
                                                        delegate:self];
            
            [self.navigationController pushViewController:booleanController animated:YES];
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsChangePasscode)
        {
            [dataModel handleChangePasscode];
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsDeleteAllData)
        {
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"AlertDeleteAllDataConfirmationTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete All Data", @"The title of the confirmation alert for deleting all data"])
                                                                                       message:NSLocalizedStringWithDefaultValue(@"AlertDeleteAllDataConfirmationMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Are you sure you want to delete all the data on this device?", @"The title of the confirmation alert for deleting all data"])
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNo", @"Dosecast", [DosecastUtil getResourceBundle], @"No", @"The text on the No button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];

            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonYes", @"Dosecast", [DosecastUtil getResourceBundle], @"Yes", @"The text on the Yes button in an alert"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action) {
                                              [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingAllData", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting all data", @"The message appearing in the spinner view when deleting all data"])];
                                              
                                              [[ServerProxy getInstance] detachDevice:dataModel.hardwareID
                                                                            respondTo:self];
                                          }]];

            [alert showInViewController:self];
        }
        else if (securityRow == SettingsViewControllerSecurityPrivacySectionRowsLogging)
        {
            BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                        initialValue:dataModel.globalSettings.debugLoggingEnabled
                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Security and Privacy", @"The security header in the Settings view"])
                                                        displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsSecurityLogging", @"Dosecast", [DosecastUtil getResourceBundle], @"Debug Logging", @"The Privacy Mode label in the Settings view"])
                                                        headerText:nil
                                                        footerText:nil
                                                        identifier:LoggingModeId
                                                        subIdentifier:nil
                                                        delegate:self];
            
            [self.navigationController pushViewController:booleanController animated:YES];
        }
	}
	else if (settingsSection == SettingsViewControllerSectionsHistory)
	{
        if (indexPath.row == 0)
        {
            // Premium-only feature
            if (dataModel.globalSettings.accountType == AccountTypeDemo)
            {
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoseHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
            }
            else
            {		
                NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
                                                                  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  sigDigits:3
                                                                  numDecimals:0
                                                                  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"History", @"The history header of the Settings view"])
                                                                  displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryDuration", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose History Stored", @"The Dose History Stored label in the Settings view"])
                                                                  initialVal:dataModel.globalSettings.doseHistoryDays
                                                                  initialUnit:DrugDosageUnitDays
                                                                  possibleUnits:[NSArray arrayWithObjects:DrugDosageUnitDays, nil]
                                                                  displayNone:NO
                                                                  allowZeroVal:YES
                                                                  identifier:nil
                                                                  subIdentifier:nil
                                                                  delegate:self];
                [self.navigationController pushViewController:numericController animated:YES];
            }
        }
        else if (indexPath.row == 1)
        {
            // Premium-only feature
            if (dataModel.globalSettings.accountType == AccountTypeDemo)
            {
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoseHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
            }
            else
            {
                BooleanViewController* booleanController = [[BooleanViewController alloc]
                                                            initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BooleanViewController"]
                                                            bundle:[DosecastUtil getResourceBundle]
                                                            initialValue:dataModel.globalSettings.postponesDisplayed
                                                            viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"History", @"The history header of the Settings view"])
                                                            displayTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryShowPostponeEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"Show Postpone Events", @"The Show Postpone Events label in the Settings view"])
                                                            headerText:nil
                                                            footerText:nil
                                                            identifier:PostponesDisplayedId
                                                            subIdentifier:nil
                                                            delegate:self];
                                                            
                [self.navigationController pushViewController:booleanController animated:YES];
            }
        }
        else if (indexPath.row == 2)
        {
            // Premium-only feature
            if (dataModel.globalSettings.accountType == AccountTypeDemo)
            {
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoseHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
            }
            else
            {		
                LateDoseSettingsViewController* lateDoseController = [[LateDoseSettingsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"LateDoseSettingsViewController"]
                                                                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                                                                    delegate:self];
                [self.navigationController pushViewController:lateDoseController animated:YES];
            }
        }
	}
    else if (settingsSection == SettingsViewControllerSectionsGroups)
    {
        if (indexPath.row == [[DataModel getInstance].groups count]) // add group
        {
            JoinGroupEnterGroupNameViewController* enterGroupNameController = [[JoinGroupEnterGroupNameViewController alloc]
                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"JoinGroupEnterGroupNameViewController"]
                                                          bundle:[DosecastUtil getResourceBundle]
                                                          delegate:self];
            [self.navigationController pushViewController:enterGroupNameController animated:YES];
        }
        else // view group
        {
            selectedGroup = (Group*)[[DataModel getInstance].groups objectAtIndex:indexPath.row];

            [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSearchingForGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Searching for group", @"The message appearing in the spinner view when updating the server"])];

            [[ServerProxy getInstance] groupInfoByID:selectedGroup.groupID respondTo:self];
        }
    }
    else if (settingsSection == SettingsViewControllerSectionsSync)
    {
        if (indexPath.row == 0)
        {
            AccountType accountType = [DataModel getInstance].globalSettings.accountType;
            // Subscription-only feature
            if (accountType != AccountTypeSubscription)
            {
                NSString* message = nil;
                if (accountType == AccountTypeDemo)
                    message = NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionSync", @"Dosecast", [DosecastUtil getResourceBundle], @"This feature is available in the Pro edition with CloudSync. To learn more about the features in the Pro edition with CloudSync, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"]);
                else if (accountType == AccountTypePremium)
                    message = NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionSyncPremium", @"Dosecast", [DosecastUtil getResourceBundle], @"This feature is not available in the Premium edition, and requires subscribing to the Pro edition with CloudSync. To learn more about the features in the Pro edition with CloudSync, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"]);
                [self handleDisplayPremiumFeatureAlert:message];
            }
            else
            {
                [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingAccount", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating account", @"The message appearing in the spinner view when updating the account"])];

                [[ServerProxy getInstance] getRendezvousCode:self];
            }
        }
        else if (indexPath.row == 1)
        {
            SyncMoveDeviceViewController* controller = [[SyncMoveDeviceViewController alloc]
                                                        initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"SyncMoveDeviceViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]];
            [self.navigationController pushViewController:controller animated:YES];
        }
        else // if (indexPath.row == 2)
        {
            AccountType accountType = [DataModel getInstance].globalSettings.accountType;
            // Subscription-only feature
            if (accountType != AccountTypeSubscription)
            {
                NSString* message = nil;
                if (accountType == AccountTypeDemo)
                    message = NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionSync", @"Dosecast", [DosecastUtil getResourceBundle], @"This feature is available in the Pro edition with CloudSync. To learn more about the features in the Pro edition with CloudSync, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"]);
                else if (accountType == AccountTypePremium)
                    message = NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionSyncPremium", @"Dosecast", [DosecastUtil getResourceBundle], @"This feature is not available in the Premium edition, and requires subscribing to the Pro edition with CloudSync. To learn more about the features in the Pro edition with CloudSync, tap the 'Subscribe' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"]);
                [self handleDisplayPremiumFeatureAlert:message];
            }
            else
            {
                [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSearchingForDevices", @"Dosecast", [DosecastUtil getResourceBundle], @"Searching for devices", @"The message appearing in the spinner view when updating the account"])];
                
                [[ServerProxy getInstance] getAttachedDevices:self];
            }
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (settingsSection == SettingsViewControllerSectionsGroups)
	{
        if (indexPath.row == [[DataModel getInstance].groups count]) // the add group cell
            return UITableViewCellEditingStyleInsert;
        else
            return UITableViewCellEditingStyleDelete;
	}
	else
		return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[LogManager sharedManager] endPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleInsert)
	{
        JoinGroupEnterGroupNameViewController* enterGroupNameController = [[JoinGroupEnterGroupNameViewController alloc]
                                                                           initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"JoinGroupEnterGroupNameViewController"]
                                                                           bundle:[DosecastUtil getResourceBundle]
                                                                           delegate:self];
        [self.navigationController pushViewController:enterGroupNameController animated:YES];
	}
	else if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        selectedGroup = (Group*)[[DataModel getInstance].groups objectAtIndex:indexPath.row];

        deletedGroupIndexPath = indexPath;
        
        [self handleLeaveGroup];
	}
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    SettingsViewControllerSections settingsSection = (SettingsViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];
    
	if (settingsSection == SettingsViewControllerSectionsGroups)
	{
        return YES;
	}
	else
		return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsLeave", @"Dosecast", [DosecastUtil getResourceBundle], @"Leave", @"The Leave label in the Settings view"]);
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}




@end
