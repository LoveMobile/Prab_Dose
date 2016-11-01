//
//  DosecastAPIImp.m
//  Dosecast
//
//  Created by Jonathan Levene on 9/26/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DosecastAPIImp.h"
#import "DosecastAPIDelegate.h"
#import "DataModel.h"
#import "PurchaseManager.h"

#import "PillNotificationManager.h"
#import "ReachabilityManager.h"
#import "DosecastUtil.h"
#import "HistoryManager.h"
#import "DosecastMainViewController.h"
#import "DosecastScheduleViewController.h"
#import "FlagDictionary.h"
#import "SettingsViewController.h"
#import "DrugHistoryViewController.h"
#import "AccountViewController.h"
#import "CustomNameIDList.h"
#import "ServerProxy.h"
#import "LocalNotificationManager.h"
#import "DrugDosageManager.h"
#import "LogManager.h"
#import "JSONConverter.h"
#import "Drug.h"
#import "HistoryEvent.h"
#import "DrugImageManager.h"
#import "DosecastDrugsViewController.h"
#import "VersionNumber.h"
#import "DrugDosageUnitManager.h"
#import "MedicationSearchManager.h"
#import "GlobalSettings.h"
#import "Reachability.h"
#import "ContactsHelper.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

// Name of DB data file
static NSString *DBDataFilename = @"DoseHistory.sqlite";

// Name of DB schema file
static NSString *DBSchemaFilename = @"DoseHistory";
static NSString *DBSchemaFilenameExt = @"momd";

static NSTimeInterval DEFAULT_MIN_BACKGROUND_FETCH_INTERNAL = 300;

// Dosecast API flags
NSString *DosecastAPIShowAccount = @"DosecastAPIShowAccount";          
NSString *DosecastAPIShowNativeUIOnIPad = @"DosecastAPIShowNativeUIOnIPad";
NSString *DosecastAPIMultiPersonSupport = @"DosecastAPIMultiPersonSupport";
NSString *DosecastAPITrackRemainingQuantities = @"DosecastAPITrackRemainingQuantities";
NSString *DosecastAPITrackRefillsRemaining = @"DosecastAPITrackRefillsRemaining";
NSString *DosecastAPIDoctorSupport = @"DosecastAPIDoctorSupport";
NSString *DosecastAPIPharmacySupport = @"DosecastAPIPharmacySupport";
NSString *DosecastAPIPrescriptionNumberSupport = @"DosecastAPIPrescriptionNumberSupport";
NSString *DosecastAPIShowMainToolbar = @"DosecastAPIShowMainToolbar";
NSString *DosecastAPIShowDrugInfoToolbar = @"DosecastAPIShowDrugInfoToolbar";
NSString *DosecastAPIShowHistoryToolbar = @"DosecastAPIShowHistoryToolbar";
NSString *DosecastAPIEnableDebugLog = @"DosecastAPIEnableDebugLog";
NSString *DosecastAPIEnablePasscodeSettings = @"DosecastAPIEnablePasscodeSettings";
NSString *DosecastAPIShowVersionInSettings = @"DosecastAPIShowVersionInSettings";
NSString *DosecastAPIEnableUSDrugDatabaseSearch = @"DosecastAPIEnableUSDrugDatabaseSearch";
NSString *DosecastAPIEnableUSDrugDatabaseTypes = @"DosecastAPIEnableUSDrugDatabaseTypes";
NSString *DosecastAPIEnableDeleteAllDataSettings = @"DosecastAPIEnableDeleteAllDataSettings";
NSString *DosecastAPIIdentifyServerAccountByUserData = @"DosecastAPIIdentifyServerAccountByUserData";
NSString *DosecastAPIEnableShowArchivedDrugs = @"DosecastAPIEnableShowArchivedDrugs";
NSString *DosecastAPIEnableShowDrugImages = @"DosecastAPIEnableShowDrugImages";
NSString *DosecastAPIWarnOnEmailingDrugInfo = @"DosecastAPIWarnOnEmailingDrugInfo";
NSString *DosecastAPIShowArchivedDrugsByDefault = @"DosecastAPIShowArchivedDrugsByDefault";
NSString *DosecastAPIEnableShowDrugNamesInNotifications = @"DosecastAPIEnableShowDrugNamesInNotifications";
NSString *DosecastAPIShowDrugNamesInNotificationsByDefault = @"DosecastAPIShowDrugNamesInNotificationsByDefault";
NSString *DosecastAPIDisplayUnarchivedDrugStatusInDrugInfo = @"DosecastAPIDisplayUnarchivedDrugStatusInDrugInfo";
NSString *DosecastAPIEnableGroups = @"DosecastAPIEnableGroups";
NSString *DosecastAPIEnableSync = @"DosecastAPIEnableSync";
NSString *DosecastAPIEnableSecondaryRemindersByDefault = @"DosecastAPIEnableSecondaryRemindersByDefault";

// Dosecast API notifications
NSString *DosecastAPIDisplayUserAlertsNotification = @"DosecastAPIDisplayUserAlertsNotification";

@implementation DosecastAPI

// Create an instance of the Dosecast API with delegate and launch options. After calling, the client must wait until the delegate's
// handleDosecastUIInitializationComplete method is called before displaying any of this object's view controllers.
+(DosecastAPI*) createDosecastAPIInstanceWithDelegate:(NSObject<DosecastAPIDelegate>*)delegate
                                                  launchOptions:(NSDictionary*)launchOptions                     // The launchOptions passed to the ApplicationDelegate's didFinishLaunchingWithOptions method
                                                       userData:(NSString*)userData                              // Optional custom data to be stored about the current user (such as an account ID)
                                                       apiFlags:(NSArray*)apiFlags                               // An array of Dosecast API flags to enable (if a flag is not included, it is considered disabled)
                                                persistentFlags:(NSArray*)persistentFlags                        // An array of strings corresponding to persistent flags to write to & read from the Dosecast data file
                                                 productVersion:(NSString*)productVersion                        // The version of the product that the API is running in
{
    return [[DosecastAPIImp alloc] initWithDelegate:delegate
                                      launchOptions:launchOptions
                                           userData:userData
                                           apiFlags:apiFlags
                                    persistentFlags:persistentFlags
                                     productVersion:productVersion];
}

// Method to asyncronously register the current user. Will be notified of result in DosecastAPIDelegate's handleDosecastRegistrationComplete method
-(void)registerUser {}

// Factory methods for creating view controllers, as needed
- (UIViewController*) createMainViewController { return nil; }                               // Factory method for creating the main view
- (UIViewController*) createScheduleViewController { return nil; }                           // Factory method for creating the schedule view
- (UIViewController*) createDrugsViewController { return nil; }                               // Factory method for creating the drugs view
- (UIViewController*) createSettingsViewController { return nil; }                           // Factory method for creating the settings view
- (UIViewController*) createHistoryViewController:(NSString*)personId { return nil; }          // Factory method for creating the history view. personId is the ID of the person whose drugs should be displayed. If 'me', use nil.
- (UIViewController*) createAccountViewController{ return nil; }                             // Factory method for creating the account view

// A string containing an HTML description of the entire drug list
- (NSString*) getDrugListHTMLDescription { return nil; }
// Return the drug history as a string for the personID provided
- (NSString*) getDrugHistoryString:(NSString*)personId{ return nil; }
// Return the drug history as a CSV file for the personID provided
- (NSData*) getDrugHistoryCSVFile:(NSString*)personId{ return nil; }
// A string containing key diagnostic information
- (NSString*) getKeyDiagnostics{ return nil; }
// The debug log in the form of a CSV file (for attachment in an email)
- (NSData*) getDebugLogCSVFile{ return nil; }
// Perform a deletion of all data.
- (void) deleteAllData{}

// Returns the terms of service addenda from all groups the user joined
- (NSString*)getGroupTermsOfServiceAddenda{ return nil; }

// Returns whether any group gives a premium license away
- (BOOL)doesAnyGroupGivePremium{ return NO; }

- (void) getListOfPersonNames:(NSArray**)personNames andCorrespondingPersonIds:(NSArray**)personIds{} // returns an array of person names and a corresponding array of ids, sorted by name alphabetically

// Methods to get & set persistent flags. Flag names must have been passed into the list of persistent flags at initialization time.
-(BOOL)getPersistentFlag:(NSString*)flagName{ return NO; } // Returns NO if flag not found
-(void)setPersistentFlag:(NSString*)flagName value:(BOOL)val{}

// ----- Pass-through calls from App Delegate
-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken{}
-(void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings{}
-(void)didReceiveLocalNotification:(UILocalNotification *)notification{}
-(void)didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler{}
-(void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)err{}
-(void)applicationDidEnterBackground:(UIApplication *)application{}
-(void)applicationWillEnterForeground:(UIApplication *)application{}
-(void)applicationWillResignActive:(UIApplication *)application{}
-(void)applicationDidBecomeActive:(UIApplication *)application{}
-(void)applicationWillTerminate:(UIApplication *)application{}
-(void)applicationDidReceiveMemoryWarning:(UIApplication *)application{}
-(void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler{}

@end

@implementation DosecastAPIImp

@synthesize userRegistered;
@synthesize delegate;

/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

// Callback when audio route changes
- (void) handleAudioRouteChange:(NSNotification *)notification
{
    [self initializeAudio];
}

- (void)initializeAudio
{
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryAmbient error:nil];
    [audioSession setActive:YES error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message
{
    if (delegate && [delegate respondsToSelector:@selector(disallowDosecastUserInteractionsWithMessage:)])
        [delegate disallowDosecastUserInteractionsWithMessage:message];
}

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (delegate && [delegate respondsToSelector:@selector(updateDosecastMessageWhileUserInteractionsDisallowed:)])
        [delegate updateDosecastMessageWhileUserInteractionsDisallowed:message];
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation
{
    if (delegate && [delegate respondsToSelector:@selector(allowDosecastUserInteractionsWithMessage:)])
        [delegate allowDosecastUserInteractionsWithMessage:allowAnimation];
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress // A number between 0 and 1
{
    if (delegate && [delegate respondsToSelector:@selector(disallowDosecastUserInteractionsWithMessageAndProgress:progress:)])
        [delegate disallowDosecastUserInteractionsWithMessageAndProgress:message progress:progress];
}

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress // A number between 0 and 1
{
    if (delegate && [delegate respondsToSelector:@selector(updateDosecastProgressWhileUserInteractionsDisallowed:)])
        [delegate updateDosecastProgressWhileUserInteractionsDisallowed:progress];
}

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    if (delegate && [delegate respondsToSelector:@selector(updateDosecastProgressMessageWhileUserInteractionsDisallowed:)])
        [delegate updateDosecastProgressMessageWhileUserInteractionsDisallowed:message];
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation
{
    if (delegate && [delegate respondsToSelector:@selector(allowDosecastUserInteractionsWithMessageAndProgress:)])
        [delegate allowDosecastUserInteractionsWithMessageAndProgress:allowAnimation];
}

// Callback for when user attempts to change the passcode
- (void)handleChangePasscode
{
    if (delegate && [delegate respondsToSelector:@selector(handleChangePasscode)])
        [delegate handleChangePasscode];
}

- (BOOL) userInteractionsAllowed
{
    return [DataModel getInstance].userInteractionsAllowed;
}

// Get any modified terms of service needed to allow users to join a group
- (NSString*)getGroupTermsOfService
{
    if (delegate && [delegate respondsToSelector:@selector(getGroupTermsOfService)])
        return [delegate getGroupTermsOfService];
    else
        return nil;
}

// Get the main navigation controller
- (UINavigationController*)getUINavigationController
{
    if (delegate && [delegate respondsToSelector:@selector(getUINavigationController)])
		return [delegate getUINavigationController];
    else
        return nil;
}

// Callback for when the Dosecast component must be made visible. If Dosecast is embedded in a UITabBarController
// or other UI component, this component must be made visible at the time of this call if it is not already.
- (void)displayDosecastComponent
{
	if (delegate && [delegate respondsToSelector:@selector(displayDosecastComponent)])
		[delegate displayDosecastComponent];
}

// Callback to find out if the Dosecast component is visible. If Dosecast is embedded in a UITabBarController
// or other UI component, return whether the component is active/selected.
- (BOOL)isDosecastComponentVisible
{
	if (delegate && [delegate respondsToSelector:@selector(isDosecastComponentVisible)])
		return [delegate isDosecastComponentVisible];
    else
        return NO;
}

// Method to asyncronously register the current user
-(void)registerUser
{
    if (userRegistered)
        return;
    
    DebugLog(@"register user start");
    
    // If we're using local notifications, suppress any overdue dose alerts. This is because we will just be fetching data from the server and will refresh all drugs afterwards anyway.
    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];
    pillNotificationManager.suppressOverdueDoseAlert = YES;
    
	// Send registration to server via CreateUser request
	ServerProxy* ppProxy = [ServerProxy getInstance];
	[ppProxy createUser:self];
}

- (void) handleRegistrationError:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage
{
    [[DrugImageManager sharedManager] clearAllImages];
    
    NSString* errorCategory = nil;
    if (status == ServerProxyCommunicationsError)
        errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerUnavailableTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Unavailable", @"The title on the alert appearing when the server is unavailable"]);
    else if (status == ServerProxyServerError)
        errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalErrorTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Error", @"The title on the alert appearing when the server experiences an internal error"]);
    else if (status == ServerProxyInputError)
        errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerRegistrationFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Register", @"The title on the alert appearing when registration fails"]);
    
    if (status == ServerProxyDeviceDetached)
    {
        DebugLog(@"register user: detect device detach");

        errorMessage = NSLocalizedStringWithDefaultValue(@"ViewDevicesDeviceRemovedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This device has been removed from your account and all data has been deleted from the device.", @"The message appearing when a device has been removed from a user's account"]);
        DataModel* dataModel = [DataModel getInstance];
        dataModel.wasDetached = NO; // clear the wasDetached flag since we are displaying the error message to the user
        [dataModel writeToFile:nil];
    }
    
    // Make sure we aren't suppressing overdue dose alerts anymore
    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];
    pillNotificationManager.suppressOverdueDoseAlert = NO;
    
    NSMutableString* finalErrorMessage = [NSMutableString stringWithString:@""];
    if (errorCategory)
        [finalErrorMessage appendFormat:@"%@: ", errorCategory];
    [finalErrorMessage appendString:errorMessage];
    
    if (delegate && [delegate respondsToSelector:@selector(handleDosecastRegistrationComplete:)])
    {
        [delegate handleDosecastRegistrationComplete:finalErrorMessage];
    }
    
    DebugLog(@"register user end: error (%@)", finalErrorMessage);
}

- (void)createUserServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage
{
	if (status == ServerProxySuccess)
	{
		// Make a GetState request
		ServerProxy* ppProxy = [ServerProxy getInstance];
		[ppProxy sync:self];
	}
	else
	{
        [self handleRegistrationError:status errorMessage:errorMessage];
	}
}

-(void) syncServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage
{
	if (status == ServerProxySuccess)
	{
        [self handleRegistrationComplete];
	}
	else
        [self handleRegistrationError:status errorMessage:errorMessage];
}

- (void)handleRegistrationComplete
{
    DataModel* dataModel = [DataModel getInstance];
    
    if ([dataModel.apiFlags getFlag:DosecastAPIShowAccount])
    {
        // Tell the purchase manager it's now OK to start processing transactions. We need to make sure we have a valid UserID.
        [[PurchaseManager getInstance] startProcessingTransactions];
    }
    
    // Make sure we aren't suppressing overdue dose alerts anymore
    [PillNotificationManager getInstance].suppressOverdueDoseAlert = NO;
    
    userRegistered = YES;
    
    if (delegate && [delegate respondsToSelector:@selector(handleDosecastRegistrationComplete:)])
    {
        [delegate handleDosecastRegistrationComplete:nil];
    }
    
    DebugLog(@"register user end");
}

// Turn off file protection on all existing files
- (void) removeFileProtectionOnAllFiles
{
    // Look for all files and make sure the NSFileProtectionKey attribute is set properly
    
    NSError* error = nil;
	NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self applicationDocumentsDirectory] error:&error];
    
    if (filenames)
    {
        for (NSString* filename in filenames)
        {
            NSString* fullPathToFile = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:filename];
            NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPathToFile error:&error];
            if (attribs)
            {
                NSString* fileProtectionValue = [attribs objectForKey:NSFileProtectionKey];
                if (!fileProtectionValue ||
                    [fileProtectionValue compare:NSFileProtectionNone options:NSLiteralSearch] != NSOrderedSame)
                {
                    NSMutableDictionary* newAttribs = [NSMutableDictionary dictionaryWithDictionary:attribs];
                    [newAttribs setObject:NSFileProtectionNone forKey:NSFileProtectionKey];
                    [[NSFileManager defaultManager] setAttributes:newAttribs ofItemAtPath:fullPathToFile error:&error];
                }
            }
        }
    }
}

-(id)init
{
	return [self initWithDelegate:nil launchOptions:nil userData:nil apiFlags:[[NSArray alloc] init] persistentFlags:[[NSArray alloc] init] productVersion:nil];
}

// Initializer with delegate
 -(id)initWithDelegate:(NSObject<DosecastAPIDelegate>*)del
         launchOptions:(NSDictionary*)launchOptions
              userData:(NSString*)userData                                     // Custom data to be stored about the current user (such as an account ID) 
              apiFlags:(NSArray*)apiFlags                                      // An array of Dosecast API flags to enable (if a flag is not included, it is considered disabled)
       persistentFlags:(NSArray*)persistentFlags                               // An array of strings corresponding to persistent flags to write to & read from the Dosecast data file
        productVersion:(NSString*)productVersion                               // The version of the product that the API is running in
{
	if ((self = [super init]))
    {
        [self removeFileProtectionOnAllFiles];
        
		delegate = del;
		isActive = NO;
        registeredForRemoteNotifications = NO;
        backgroundFetchCompletionHandler = nil;
        
		// Finish initializing the data model before all others (since they are dependent on it)
		DataModel* dataModel = [DataModel getInstanceWithAPIFlags:apiFlags];

        // Initialize all persistent flags
        if (persistentFlags)
        {
            for (NSString* flag in persistentFlags)
                [dataModel.persistentFlags setFlag:flag value:NO];            
        }
        
		dataModel.globalSettings.userData = userData;
        dataModel.clientVersion = productVersion;
				
        // Initialize important singletons
        [ServerProxy getInstance];
		[PurchaseManager getInstance];
		[PillNotificationManager getInstance];
		[ReachabilityManager getInstance];
		[LocalNotificationManager getInstance];
		[HistoryManager getInstance];
		[DrugDosageManager getInstance];
        [DrugImageManager sharedManager];
        [LogManager sharedManager];
        [DrugDosageUnitManager getInstance];
        [MedicationSearchManager sharedManager];

        [PillNotificationManager getInstance].delegate = self;
        [DataModel getInstance].delegate = self;
  
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:DEFAULT_MIN_BACKGROUND_FETCH_INTERNAL];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSubscriptionPurchased:)
                                                     name:PurchaseManagerSubscriptionPurchased
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleReachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSyncComplete:)
                                                     name:LogSyncCompleteNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSyncFail:)
                                                     name:LogSyncFailedNotification
                                                   object:nil];

        // Perform the rest of initialization asynchronously to avoid slowing down app startup (since iOS will shut the app down if we take too long)
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(finishAppInitialization:) userInfo:userData repeats:NO];
	}
	return self;			
}

#pragma mark -
#pragma mark Application lifecycle

// Methods to get & set persistent flags. Flag names must have been passed into the list of persistent flags at initialization time.
-(BOOL)getPersistentFlag:(NSString*)flagName // Returns NO if flag not found
{
    if (!flagName)
        return NO;
    
    return [[DataModel getInstance].persistentFlags getFlag:flagName];
}

-(void)setPersistentFlag:(NSString*)flagName value:(BOOL)val
{
    if (!flagName)
        return;

    DebugLog(@"setting persistent flag (%@)", flagName);

    DataModel* dataModel = [DataModel getInstance];
    [dataModel.persistentFlags setFlag:flagName value:val];
    [dataModel writeToFile:nil];
}

-(void) finishAppInitialization:(NSTimer*)theTimer
{
    DataModel* dataModel = [DataModel getInstance];
   
    NSString* userData = theTimer.userInfo;
    
    // Initialize audio played in the app
    [self initializeAudio];
    
    NSURL *storeURL = [NSURL fileURLWithPath:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:DBDataFilename]];
    dbDataFile = [[DosecastDBDataFile alloc] initWithURL:storeURL
                                          schemaFilename:DBSchemaFilename
                                       schemaFilenameExt:DBSchemaFilenameExt
                                                delegate:self];
    
    // Instantiate the managed object context now & pass the db data file to the HistoryManager.
    [dbDataFile managedObjectContext];
    HistoryManager* historyManager = [HistoryManager getInstance];
    historyManager.dbDataFile = dbDataFile;
    
    DebugLog(@"App running start");

    // Read the data file, if available
    NSString *errorMessage = nil;
    userRegistered = [dataModel readFromFile:&errorMessage];
    
    if (errorMessage)
    {
        NSString* errorTitle = NSLocalizedStringWithDefaultValue(@"ErrorReadFileErrorTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Read Drug File", @"The title of the alert appearing on startup if the data file can't be read"]);
        NSString* errorBody = NSLocalizedStringWithDefaultValue(@"ErrorReadFileErrorMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not read the drug file due to the following error: %@", @"The message in the alert appearing on startup if the data file can't be read"]);
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:errorTitle
                                                                                           message:[NSString stringWithFormat:errorBody, errorMessage]];
        UINavigationController* mainNavigationController = [self getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        
        [alert showInViewController:topNavController.topViewController];
    }
    
    // Let the history manager do some startup tasks now.
    [historyManager handleStartupTasks];
    
    // If the client changed the user data, update it and write it to disk if the file already exists
    if (userRegistered)
    {
        dataModel.globalSettings.userData = userData;
        
        if ([dataModel.apiFlags getFlag:DosecastAPIShowAccount])
        {
            // Tell the purchase manager it's now OK to start processing transactions. We need to make sure we have a valid UserID.
            [[PurchaseManager getInstance] startProcessingTransactions];
        }
        
        [[LogManager sharedManager] uploadLogs];
        [[DrugImageManager sharedManager] syncImages];
    }
    
    if ([DosecastUtil getOSVersionFloat] >= 8.0f)
    {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert) categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    else
        [self attemptRegistrationForRemoteNotifications];

    [self checkBackgroundRefreshSettings];

    // Tell the client that we're ready to display any UI
    if (delegate && [delegate respondsToSelector:@selector(handleDosecastUIInitializationComplete)])
    {
        [delegate handleDosecastUIInitializationComplete];
    }
    
    if (dataModel.wasDetached)
    {
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyUserOfDeviceDetach:) userInfo:nil repeats:NO];
    }
    
    if (userRegistered)
    {
        // In this case, tell the pill notification manager to perform the initial getState call now
        [[PillNotificationManager getInstance] refreshDrugState:NO];
    }
    
    if ([dataModel.apiFlags getFlag:DosecastAPIDoctorSupport] || [dataModel.apiFlags getFlag:DosecastAPIPharmacySupport])
    {
        [dataModel.contactsHelper checkAddressBookAccess];
    }
}

- (void) checkLegacyRemoteNotificationSettings
{
    if ([DosecastUtil getOSVersionFloat] < 8.0f && [DataModel getInstance].globalSettings.accountType == AccountTypeSubscription)
    {
        // Warn the user if all notification settings are off
        if ([[UIApplication sharedApplication] enabledRemoteNotificationTypes] == UIRemoteNotificationTypeNone)
        {
            NSString* warningMessage = nil;
            
            warningMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNotificationsOffMessageIOS7", @"Dosecast", [DosecastUtil getResourceBundle], @"To deliver dose reminders properly, %@ requires that all notification settings are enabled. However, some notification settings are currently disabled. Please open the Settings app, tap on the Notification Center option, select %@, and ensure that all options are enabled.", @"The text on the OK button in an alert"]), [DosecastUtil getProductAppName], [DosecastUtil getProductAppName]];
            
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorNotificationsOffTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Enable Notifications", @"The text on the OK button in an alert"])
                                                                                               message:warningMessage];
            UINavigationController* mainNavigationController = [self getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            
            [alert showInViewController:topNavController.topViewController];
        }
    }
}

- (void) checkBackgroundRefreshSettings
{
#if !TARGET_IPHONE_SIMULATOR
    
    if ([DataModel getInstance].globalSettings.accountType == AccountTypeSubscription)
    {
        if ([[UIApplication sharedApplication] backgroundRefreshStatus] != UIBackgroundRefreshStatusAvailable)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorBackgroundRefreshOffTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Enable Background App Refresh", @"The text on the OK button in an alert"])
                                                                                               message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorBackgroundRefreshOffMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"To deliver dose reminders properly, %@ requires that the background app refresh setting is enabled. However, it is currently disabled. Please open the Settings app, tap on the General option, tap on the Background App Refresh option, and ensure that Background App Refresh is enabled and the %@ switch is on.", @"The text on the OK button in an alert"]), [DosecastUtil getProductAppName], [DosecastUtil getProductAppName]]];
            UINavigationController* mainNavigationController = [self getUINavigationController];
            UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
            
            [alert showInViewController:topNavController.topViewController];
        }
    }
    
#endif
}

-(void) notifyUserOfDeviceDetach:(NSTimer*)theTimer
{
    if (delegate && [delegate respondsToSelector:@selector(displayAlertMessageToUser:)])
    {
        DebugLog(@"device detach: notified user");

        DataModel* dataModel = [DataModel getInstance];
        
        [delegate displayAlertMessageToUser:
         NSLocalizedStringWithDefaultValue(@"ViewDevicesDeviceRemovedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This device has been removed from your account and all data has been deleted from the device.", @"The message appearing when a device has been removed from a user's account"])];
        dataModel.wasDetached = NO; // clear the wasDetached flag since we are displaying the error message to the user
        [dataModel writeToFile:nil];
    }
}

-(void) didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
#if !TARGET_IPHONE_SIMULATOR

    // Warn the user if all notification settings are off
    if (notificationSettings.types == UIUserNotificationTypeNone)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorNotificationsOffTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Enable Notifications", @"The text on the OK button in an alert"])
                                                                                           message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorNotificationsOffMessageIOS8", @"Dosecast", [DosecastUtil getResourceBundle], @"To deliver dose reminders properly, %@ requires that all notification settings are enabled. However, some notification settings are currently disabled. Please open the Settings app, tap on the Notifications option, select %@, and ensure that all options are enabled.", @"The text on the OK button in an alert"]), [DosecastUtil getProductAppName], [DosecastUtil getProductAppName]]];
        UINavigationController* mainNavigationController = [self getUINavigationController];
        UINavigationController* topNavController = [DosecastUtil getTopNavigationController:mainNavigationController];
        
        [alert showInViewController:topNavController.topViewController];
    }
    
#endif
    
    [self attemptRegistrationForRemoteNotifications];
}

-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{    
    NSString* encodedDevToken = [DosecastUtil getDeviceTokenAsString:devToken];
    registeredForRemoteNotifications = (encodedDevToken && [encodedDevToken length] > 0);
    DataModel* dataModel = [DataModel getInstance];
    
    // Set it in the data model. This will send it to the server on the next sync.
    if (registeredForRemoteNotifications)
    {
        dataModel.deviceToken = encodedDevToken;
    }
    
    [self checkLegacyRemoteNotificationSettings];
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
    [self checkLegacyRemoteNotificationSettings];

    // Don't inform the user, as responding to remote notifications isn't absolutely required for the app. We registered
    // for a reachability notification, so we'll try again once the reachability status changes.
}

- (void)didReceiveLocalNotification:(UILocalNotification *)notification
{
	DebugLog(@"Received local notification");

	// If we have a user ID, that means we aren't registering.
	// In this case, inform the pill notification manager
    //
    // Only do this if we're active, because when we become active we'll refresh the drug state
	if (userRegistered && isActive)
		[[PillNotificationManager getInstance] handlePillNotification];	
}

- (void) handleSyncComplete:(NSNotification *)notification
{
    if (backgroundFetchCompletionHandler)
    {
        DebugLog(@"making background push complete CB");

        backgroundFetchCompletionHandler(UIBackgroundFetchResultNewData);
        backgroundFetchCompletionHandler = nil;
    }
}

- (void) handleSyncFail:(NSNotification *)notification
{
    if (backgroundFetchCompletionHandler)
    {
        DebugLog(@"making background push failed CB");

        backgroundFetchCompletionHandler(UIBackgroundFetchResultFailed);
        backgroundFetchCompletionHandler = nil;
    }
}

-(void)didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    if (!userRegistered)
    {
        handler(UIBackgroundFetchResultNoData);
        return;
    }
    
    DebugLog(@"Received background push notification");
    
    backgroundFetchCompletionHandler = handler;
    
    [DataModel getInstance].syncNeeded = YES;
    [[DataModel getInstance] writeToFile:nil];
    BOOL success = [[LogManager sharedManager] startUploadLogsImmediately];
    
    // handler will be called when sync completes or fails

    if (!success)
    {
        handler(UIBackgroundFetchResultNoData);
        backgroundFetchCompletionHandler = nil;
    }
}

-(void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    if (!userRegistered || [DataModel getInstance].globalSettings.accountType != AccountTypeSubscription)
    {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
    
    // Do a getState to refresh all drug internal state
    [[LocalNotificationManager getInstance] getState:NO respondTo:nil async:NO];
    
    // See if any doses are within 2x the background fetch interval. If so, do a sync.
    NSDate* nextReminderHorizon = [DosecastUtil addTimeIntervalToDate:[NSDate date] timeInterval:DEFAULT_MIN_BACKGROUND_FETCH_INTERNAL*2];
    if ([[DataModel getInstance] willDoseBeDueBefore:nextReminderHorizon])
    {
        DebugLog(@"Received background fetch request");

        backgroundFetchCompletionHandler = completionHandler;
        
        [DataModel getInstance].syncNeeded = YES;
        [[DataModel getInstance] writeToFile:nil];
        BOOL success = [[LogManager sharedManager] startUploadLogsImmediately];
        
        // handler will be called when sync completes or fails
        
        if (!success)
        {
            completionHandler(UIBackgroundFetchResultNoData);
            backgroundFetchCompletionHandler = nil;
        }
    }
    else
    {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

// Factory method for creating the main view
- (UIViewController*) createMainViewController
{
    return [[DosecastMainViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DosecastMainViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]];

}

// Factory method for creating the schedule view
- (UIViewController*) createScheduleViewController
{
    return [[DosecastScheduleViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DosecastScheduleViewController"]
                                                             bundle:[DosecastUtil getResourceBundle]];
    
}

// Factory method for creating the drugs view
- (UIViewController*) createDrugsViewController
{
    return [[DosecastDrugsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DosecastDrugsViewController"]
                                                             bundle:[DosecastUtil getResourceBundle]];
    
}

// Factory method for creating the settings view
- (UIViewController*) createSettingsViewController
{
    return [[SettingsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"SettingsViewController"]
                                                     bundle:[DosecastUtil getResourceBundle]];
}

// Factory method for creating the history view. personId is the ID of the person whose drugs should be displayed. If 'me', use nil.
- (UIViewController*) createHistoryViewController:(NSString*)personId
{
    if (!personId)
        personId = @"";
    return [[DrugHistoryViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugHistoryViewController"]
                                                        bundle:[DosecastUtil getResourceBundle]
                                                      personId:personId
                                                        drugId:nil];

}

// Factory method for creating the account view
- (UIViewController*) createAccountViewController
{
    return [[AccountViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"AccountViewController"]
                                                    bundle:[DosecastUtil getResourceBundle] delegate:nil];

}

- (void) getListOfPersonNames:(NSArray**)personNames andCorrespondingPersonIds:(NSArray**)personIds // returns an array of person names and a corresponding array of ids, sorted by name alphabetically
{
    [[DataModel getInstance].globalSettings.personNames getSortedListOfNames:personNames andCorrespondingGuids:personIds];
}

- (int) doseHistoryDays
{
    DataModel* dataModel = [DataModel getInstance];
    return dataModel.globalSettings.doseHistoryDays;
}

- (NSDate*) subscriptionExpires
{
    DataModel* dataModel = [DataModel getInstance];
    return dataModel.globalSettings.subscriptionExpires;
}

// Returns whether any group gives a premium license away
- (BOOL)doesAnyGroupGivePremium
{
    DataModel* dataModel = [DataModel getInstance];
    return [dataModel doesAnyGroupGivePremium];
}

-(void)applicationDidEnterBackground:(UIApplication *)application
{
    //Finish any unfinished uploads before quitting
    
    //Verify we can run in the background
    if(userRegistered)
    {
        __block UIBackgroundTaskIdentifier bgLogTask;
        bgLogTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [application endBackgroundTask:bgLogTask];
            bgLogTask = UIBackgroundTaskInvalid;
        }];
        
        LogManager* logManager = [LogManager sharedManager];
        [logManager setBackgroundTaskID:bgLogTask];
        
        // If we are about to start a sync, do it now.
        if (![logManager isWaitingForResponse] && [DataModel getInstance].syncNeeded)
            [logManager startUploadLogsImmediately];
        
        //See if we are waiting for a response from the server
        if([logManager isWaitingForResponse]){
            //Add a KVO to watch for the response from the server
            [logManager addObserver:self forKeyPath:@"isWaitingForResponse" options:NSKeyValueObservingOptionNew context:NULL];
        }else{
            [application endBackgroundTask:bgLogTask];
            bgLogTask = UIBackgroundTaskInvalid;
        }
    
        //Check if DrugImageManager is uploading
        __block UIBackgroundTaskIdentifier bgImageTask;
        bgImageTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [application endBackgroundTask:bgImageTask];
            bgImageTask = UIBackgroundTaskInvalid;
        }];
        
        DrugImageManager* drugImageManager = [DrugImageManager sharedManager];
        [drugImageManager setBackgroundTaskID:bgImageTask];
        
        //See if we are waiting for a response from the server
        if([drugImageManager isWaitingForResponse]){
            //Add a KVO to watch for the response from the server
            [drugImageManager addObserver:self forKeyPath:@"isWaitingForResponse" options:NSKeyValueObservingOptionNew context:NULL];
        }else{
            [application endBackgroundTask:bgImageTask];
            bgImageTask = UIBackgroundTaskInvalid;
        }
    }
    
    DebugLog(@"App did enter background");
}

-(void)applicationWillEnterForeground:(UIApplication *)application
{
	DebugLog(@"App will enter foreground");
    //Start the DrugImage Manager
    if (userRegistered)
    {
        [[LogManager sharedManager] uploadLogs];
        [[DrugImageManager sharedManager] syncImages];
    }
}

-(void)applicationWillResignActive:(UIApplication *)application
{
	DebugLog(@"App will resign active");
	isActive = NO;
    
    // Refresh the drug list
    if (userRegistered)
        [[PillNotificationManager getInstance] hideOverduePillAlertIfVisible:NO];
}

-(void)applicationDidBecomeActive:(UIApplication *)application
{
	DebugLog(@"App did become active");
    
    isActive = YES;
		
    // Refresh the drug list
    if (userRegistered)
        [[PillNotificationManager getInstance] refreshDrugState:YES];
    
    if ([DataModel getInstance].wasDetached)
    {
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyUserOfDeviceDetach:) userInfo:nil repeats:NO];
    }
}

-(void)applicationWillTerminate:(UIApplication *)application
{
    DebugLog(@"App running end");
    
    // Try to save any pending db data file changes, if any.
    if ([dbDataFile.managedObjectContext hasChanges])
        [dbDataFile saveChanges];
}

- (void) applicationDidReceiveMemoryWarning:(UIApplication*)application
{
    DebugLog(@"Memory warning");
    
    // Try to save any pending db data file changes, if any.
    if ([dbDataFile.managedObjectContext hasChanges])
        [dbDataFile saveChanges];
}

//Monitors for any pending log upload to finish
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    
    DrugImageManager* drugImageManager = [DrugImageManager sharedManager];
    LogManager* logManager = [LogManager sharedManager];

    if ([keyPath isEqual:@"isWaitingForResponse"])
    {
        if (object == logManager && [logManager isWaitingForResponse]==NO)
        {
            if (logManager.backgroundTaskID != UIBackgroundTaskInvalid)
            {
                [[UIApplication sharedApplication] endBackgroundTask:[logManager backgroundTaskID]];
                [logManager setBackgroundTaskID:UIBackgroundTaskInvalid];
            }
            [logManager removeObserver:self forKeyPath:@"isWaitingForResponse" context:NULL];
        }
        else if (object == drugImageManager && [drugImageManager isWaitingForResponse]==NO)
        {
            if (drugImageManager.backgroundTaskID != UIBackgroundTaskInvalid)
            {
                [[UIApplication sharedApplication] endBackgroundTask:[drugImageManager backgroundTaskID]];
                [drugImageManager setBackgroundTaskID:UIBackgroundTaskInvalid];
            }
            [drugImageManager removeObserver:self forKeyPath:@"isWaitingForResponse" context:NULL];
        }
    }
}

// The date the account was created
- (NSDate*) accountCreated
{
    return [DataModel getInstance].accountCreated;
}

- (NSDate*) appLastOpened
{
    return [DataModel getInstance].appLastOpened;
}

- (NSDate*) lastManagedUpdate
{
    return [DataModel getInstance].globalSettings.lastManagedUpdate;
}

// Called to get the version string
-(NSString*)productVersion
{
	return [DataModel getInstance].clientVersion;
}

// The type of account (demo or premium)
-(AccountType) accountType
{
    return [DataModel getInstance].globalSettings.accountType;
}

// Called to get custom data stored about the current user (such as an account ID)
- (NSString*)userData
{
	return [DataModel getInstance].globalSettings.userData;
}

-(void)setUserData:(NSString *)userData
{
    if (!userData)
        userData = @"";
    if (userRegistered && ![self.userData isEqualToString:userData])
    {
        [DataModel getInstance].globalSettings.userData = userData;
        [DataModel getInstance].syncNeeded = YES;
    }
}

// An abbreviation of the user ID for displaying to the user
- (NSString*) userIDAbbrev
{
    return [DataModel getInstance].userIDAbbrev;
}

// A string containing key diagnostic information
- (NSString*) getKeyDiagnostics
{
    return [[DataModel getInstance] getKeyDiagnosticsString];
}

// The debug log in the form of a CSV file (for attachment in an email)
- (NSData*) getDebugLogCSVFile
{
    return [[HistoryManager getInstance] getDebugLogAsCSVFile];    
}

// A string containing an HTML description of the entire drug list
- (NSString*) getDrugListHTMLDescription
{
    return [[DataModel getInstance] getDrugListHTMLString];
}

// Return the drug history as a string for the personID provided
- (NSString*) getDrugHistoryString:(NSString*)personId
{
    if (!personId)
        personId = @"";
    return [[DataModel getInstance] getDrugHistoryStringForPersonId:personId];
}

// Return the drug history as a CSV file for the personID provided
- (NSData*) getDrugHistoryCSVFile:(NSString*)personId
{
    if (!personId)
        personId = @"";
    NSArray* drugIds = [[DataModel getInstance] findDrugIdsForPersonId:personId];
    return [[HistoryManager getInstance] getDoseHistoryAsCSVFileForDrugIds:drugIds includePostponeEvents:[DataModel getInstance].globalSettings.postponesDisplayed errorMessage:nil];
}

// Whether or not the device has an internet connection
-(BOOL) internetConnection
{
	return [[ReachabilityManager getInstance] canReachInternet];
}

// The Dosecast API version
-(NSString*) apiVersion
{
	return [DataModel getInstance].globalSettings.apiVersion.versionString;
}

// Whether overdue dose notifications should be paused temporarily
- (BOOL) notificationsPaused
{
    return [PillNotificationManager getInstance].notificationsPaused;
}

// Whether overdue dose notifications should be paused temporarily
- (void) setNotificationsPaused:(BOOL)notificationsPaused
{
    PillNotificationManager* pillNotificationManager = [PillNotificationManager getInstance];
    pillNotificationManager.notificationsPaused = notificationsPaused;
    pillNotificationManager.suppressOverdueDoseAlert = notificationsPaused;
}

// Returns whether the user is resolving an overdue dose alert
- (BOOL) isResolvingOverdueDoseAlert
{
    return [[PillNotificationManager getInstance] isResolvingOverdueDoseAlert];
}

- (void)detachDeviceServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage
{
    if (status == ServerProxySuccess)
    {
        [[DataModel getInstance] performDeleteAllData];
    }
    else
    {
        NSString* errorCategory = nil;
        if (status == ServerProxyCommunicationsError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerUnavailableTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Unavailable", @"The title on the alert appearing when the server is unavailable"]);
        else if (status == ServerProxyServerError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalErrorTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Error", @"The title on the alert appearing when the server experiences an internal error"]);
        
        if (status == ServerProxyDeviceDetached)
        {
            DebugLog(@"detachDevice: device detach detected");

            errorMessage = NSLocalizedStringWithDefaultValue(@"ViewDevicesDeviceRemovedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This device has been removed from your account and all data has been deleted from the device.", @"The message appearing when a device has been removed from a user's account"]);
            DataModel* dataModel = [DataModel getInstance];
            dataModel.wasDetached = NO; // clear the wasDetached flag since we are displaying the error message to the user
            [dataModel writeToFile:nil];
        }
        
        NSMutableString* finalErrorMessage = [NSMutableString stringWithString:@""];
        if (errorCategory)
            [finalErrorMessage appendFormat:@"%@: ", errorCategory];
        [finalErrorMessage appendString:errorMessage];
        
        if (delegate && [delegate respondsToSelector:@selector(handleDeleteAllData:)])
        {
            [delegate handleDeleteAllData:finalErrorMessage];
        }
    }
}

// Perform a deletion of all data.
- (void) deleteAllData
{
    if (userRegistered)
    {
        [[ServerProxy getInstance] detachDevice:[DataModel getInstance].hardwareID
                                      respondTo:self];
    }
    else
        [self handleDeleteAllData];
}

- (void)handleDeleteAllData
{
    userRegistered = NO;
    
    // Force the badge number to be the number of overdue pills
	[UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    if (delegate && [delegate respondsToSelector:@selector(handleDeleteAllData:)])
    {
        [delegate handleDeleteAllData:nil];
    }
    
    if (isActive && [DataModel getInstance].wasDetached)
    {
        [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(notifyUserOfDeviceDetach:) userInfo:nil repeats:NO];
    }
}

- (void) handleDataModelRefresh:(NSNotification *)notification
{
    DataModel* dataModel = [DataModel getInstance];
    
    // Force the badge number to be the number of overdue pills
    int numOverdue = [dataModel numOverdueDrugs];
    if ([dataModel isExceedingMaxLocalNotifications])
        numOverdue += 1;
    [UIApplication sharedApplication].applicationIconBadgeNumber = (numOverdue > 0 ? 1 : 0);
    
    DebugLog(@"Updating app badge number to %d", (numOverdue > 0 ? 1 : 0));
}

- (void) handleSubscriptionPurchased:(NSNotification *)notification
{
    if (delegate && [delegate respondsToSelector:@selector(handleSubscriptionPurchased)])
    {
        [delegate handleSubscriptionPurchased];
    }
}

- (void) attemptRegistrationForRemoteNotifications
{
#if !TARGET_IPHONE_SIMULATOR

    if (!registeredForRemoteNotifications && [[ReachabilityManager getInstance] canReachInternet])
    {
        // Try to re-register again
        if ([DosecastUtil getOSVersionFloat] >= 8.0f)
        {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
        else
        {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
        }
    }
    
#endif
    
}

- (void) handleReachabilityChanged:(NSNotification *)notification
{
    DebugLog(@"Internet connectivity changed: now is %@", ([[ReachabilityManager getInstance] canReachInternet] ? @"on" : @"off"));

    [self attemptRegistrationForRemoteNotifications];
}

// Returns the terms of service addenda from all groups the user joined
- (NSString*)getGroupTermsOfServiceAddenda
{
    return [[DataModel getInstance] getGroupTermsOfServiceAddenda];
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc
{
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PurchaseManagerSubscriptionPurchased object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncFailedNotification object:nil];
}

@end




