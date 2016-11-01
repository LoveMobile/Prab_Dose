//
//  DrugViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DrugViewController.h"
#import "DrugAddEditViewController.h"
#import "DataModel.h"
#import "Drug.h"
#import "DosecastUtil.h"
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "DrugHistoryViewController.h"
#import "HistoryManager.h"
#import "AsNeededDrugReminder.h"
#import "DrugDosage.h"
#import "LocalNotificationManager.h"
#import "LogManager.h"
#import "CustomNameIDList.h"
#import "AccountViewController.h"
#import "AddressBookContact.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DrugImageManager.h"
#import "ManagedDrugDosage.h"
#import "GlobalSettings.h"
#import "ContactsHelper.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int MAX_REMINDER_SCHEDULE_TIME_LABELS = 4;
static const int WEEKDAY_LABELS_MARGIN = 5;
static const int WARNING_IMAGE_HEADER_OFFSET = 7;
static const int REMINDER_TIME_LABEL_HEIGHT = 21;
static const int REMAINING_REFILL_LABEL_HEIGHT = 35;
static const int DOSE_LIMIT_LABEL_HEIGHT = 30;
static const CGFloat LABEL_BASE_HEIGHT = 17.0f;
static const CGFloat CELL_MIN_HEIGHT = 40.0f;
static float epsilon = 0.0001;

static double MIN_PER_DAY = 60*24;

// The different UI sections & rows
typedef enum {
	DrugViewControllerSectionsDrugName          = 0,
	DrugViewControllerSectionsDrugType          = 1,
    DrugViewControllerSectionsDrugImage         = 2,
    DrugViewControllerSectionsDosage            = 3,
    DrugViewControllerSectionsPerson            = 4,
    DrugViewControllerSectionsDirections        = 5,
    DrugViewControllerSectionsReminder          = 6,
    DrugViewControllerSectionsRemainingRefill   = 7,
    DrugViewControllerSectionsExpiration        = 8,
    DrugViewControllerSectionsDoctorPharmacy    = 9,
    DrugViewControllerSectionsNotes             = 10,
    DrugViewControllerSectionsReminderSwitch    = 11,
    DrugViewControllerSectionsLogMissedDoses    = 12,
    DrugViewControllerSectionsArchived          = 13
} DrugViewControllerSections;

typedef enum {
	DrugViewControllerDoctorPharmacyRowsDoctor          = 0,
	DrugViewControllerDoctorPharmacyRowsPharmacy        = 1,
    DrugViewControllerDoctorPharmacyRowsPrescriptionNum = 2
} DrugViewControllerDoctorPharmacyRows;

@implementation DrugViewController

@synthesize tableView;
@synthesize drugPlaceholderImageView;
@synthesize nameCell;
@synthesize typeCell;
@synthesize drugImageCell;
@synthesize dosageCell;
@synthesize directionsCell;
@synthesize takeDrugScheduledCell;
@synthesize takeDrugIntervalCell;
@synthesize takeDrugAsNeededCell;
@synthesize remindersCell;
@synthesize secondaryRemindersCell;
@synthesize remainingRefillCell;
@synthesize logMissedDosesCell;
@synthesize doctorCell;
@synthesize pharmacyCell;
@synthesize prescriptionNumCell;
@synthesize notesCell;
@synthesize personCell;
@synthesize archivedCell;
@synthesize notificationMessage;
@synthesize expirationCell;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil drugId:nil viewDate:nil allowEditing:NO delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               drugId:(NSString*)Id
             viewDate:(NSDate*)date
         allowEditing:(BOOL)allow
             delegate:(NSObject<DrugViewControllerDelegate>*) del
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		drugId = Id;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

        allowEditing = allow;
        if (!date)
            date = [NSDate date];
        viewDate = date;
		
		delegate = del;
        drugImage = nil;
        tableViewSections = [[NSMutableArray alloc] init];
        doctorPharmacyRows = [[NSMutableArray alloc] init];
        
        // Flag whether this is a managed new drug or existing drug requiring notification
        isNewManagedDrug = NO;
        isExistingManagedDrugRequiringNotification = NO;
        DataModel* dataModel = [DataModel getInstance];
        Drug* d = [dataModel findDrugWithId:drugId];
        if ([d isManaged])
        {
            ManagedDrugDosage* managedDrugDosage = (ManagedDrugDosage*)d.dosage;
            isNewManagedDrug = [managedDrugDosage isNew];
            isExistingManagedDrugRequiringNotification = [managedDrugDosage requiresUserNotification];
        }
        
        self.hidesBottomBarWhenPushed = !allow || ![dataModel.apiFlags getFlag:DosecastAPIShowDrugInfoToolbar];
                
        // Get notified when the history is edited by adding a notification observer
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:HistoryManagerHistoryEditedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDrugImageRefresh:)
                                                     name:DrugImageAvailableNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAddressBookAccessGranted:)
                                                     name:ContactsHelperAddressBookAccessGranted
                                                   object:nil];

    }
    return self;
}

// Called whenever the data model (re)builds from JSON
- (void)handleDataModelRefresh:(NSNotification *)notification
{
    NSMutableDictionary* notificationDict = (NSMutableDictionary*)notification.object;
    NSSet* deletedDrugIds = nil;
    if (notificationDict)
        deletedDrugIds = [notificationDict objectForKey:DataModelDataRefreshNotificationDeletedDrugIdsKey];

    // If this drug was deleted, get us out of here
    if (deletedDrugIds && [deletedDrugIds member:drugId])
    {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    else
        [self.tableView reloadData];
}

- (void)handleAddressBookAccessGranted:(NSNotification *)notification
{
    [tableView reloadData];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugViewTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Info", @"The title of the Drug View view"]);
		
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

    if (allowEditing)
    {
        // Set Edit button
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(handleEdit:)];
        self.navigationItem.rightBarButtonItem = editButton;
            
        DataModel* dataModel = [DataModel getInstance];
        if ([dataModel.apiFlags getFlag:DosecastAPIShowDrugInfoToolbar])
        {
            NSMutableArray* toolbarItems = [[NSMutableArray alloc] init];
            // Setup toolbar with log button
            UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            NSString *logIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Log.png"];
            UIImage* logIconImage = [[UIImage alloc] initWithContentsOfFile:logIconFilePath];
            UIBarButtonItem *logButton = [[UIBarButtonItem alloc] initWithImage:logIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleViewLog:)];
            UIBarButtonItem *flexSpaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];	
            [toolbarItems addObjectsFromArray:[NSArray arrayWithObjects:flexSpaceButton, logButton, flexSpaceButton2, nil]];
            
            if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining])
            {
                NSString *refillIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Refill.png"];
                UIImage* refillIconImage = [[UIImage alloc] initWithContentsOfFile:refillIconFilePath];
                UIBarButtonItem *refillButton = [[UIBarButtonItem alloc] initWithImage:refillIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleRefill:)];
                UIBarButtonItem *flexSpaceButton3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
                [toolbarItems addObjectsFromArray:[NSArray arrayWithObjects:refillButton, flexSpaceButton3, nil]];

            }
            self.toolbarItems = toolbarItems;                
        }
    }
    
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	tableView.allowsSelection = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    
    // Scroll the text view to the top
    UITextView* textView = (UITextView*)[notesCell viewWithTag:2];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];

    // Mark resolved new managed drugs & existing managed drugs requiring notification
    if (isNewManagedDrug || isExistingManagedDrugRequiringNotification)
    {
        DataModel* dataModel = [DataModel getInstance];
        Drug* d = [dataModel findDrugWithId:drugId];
        ManagedDrugDosage* newManagedDosage = [d.dosage mutableCopy];
        
        BOOL didChange = NO;
        if ((isNewManagedDrug && [newManagedDosage isNew]) ||
            (isExistingManagedDrugRequiringNotification && [newManagedDosage requiresUserNotification]))
        {
            [newManagedDosage markAsUserNotified];
            didChange = YES;
        }
        
        // Edit the drug
        if (didChange)
        {
            [[LocalNotificationManager getInstance] editPill:d.drugId
                                                    drugName:d.name
                                                   imageGUID:d.drugImageGUID
                                                    personId:d.personId
                                                  directions:d.directions
                                               doctorContact:d.doctorContact
                                             pharmacyContact:d.pharmacyContact
                                             prescriptionNum:d.prescriptionNum
                                                drugReminder:d.reminder
                                                  drugDosage:newManagedDosage
                                                       notes:d.notes
                                        undoHistoryEventGUID:d.undoHistoryEventGUID
                                                updateServer:YES
                                                   respondTo:nil
                                                       async:NO];
        }
    }
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
    nameCell.frame = CGRectMake(nameCell.frame.origin.x, nameCell.frame.origin.y, screenWidth, nameCell.frame.size.height);
    dosageCell.frame = CGRectMake(dosageCell.frame.origin.x, dosageCell.frame.origin.y, screenWidth, dosageCell.frame.size.height);
    directionsCell.frame = CGRectMake(directionsCell.frame.origin.x, directionsCell.frame.origin.y, screenWidth, directionsCell.frame.size.height);
    [nameCell layoutIfNeeded];
    [dosageCell layoutIfNeeded];
    [directionsCell layoutIfNeeded];
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

    if ( animated )
        [self.tableView reloadData];
    
    DataModel* dataModel = [DataModel getInstance];
	Drug* d = [dataModel findDrugWithId:drugId];
    
    // Fetch initial drug image.
    
    DrugImageManager *manager = [DrugImageManager sharedManager];
    
    drugImage = nil;
    if ( d.drugImageGUID.length > 0 )
    {
        BOOL imageExists = [manager doesImageExistForImageGUID:d.drugImageGUID];
        
        if ( imageExists )
        {
            drugImage = [manager imageForImageGUID:d.drugImageGUID];
            
            [self.tableView reloadData];
        }
    }
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (void)handleDrugImageRefresh:(NSNotification *)notification
{
    [self.tableView reloadData];
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

- (void)handleHistoryEditedNotification:(NSNotification *)notification
{
    // Reload all cells in case, after the history was edited, we need to refresh drugs that have dose limits set
    [self.tableView reloadData];
}

- (void)handleEditDrugComplete
{
    if (delegate && [delegate respondsToSelector:@selector(handleDrugEdited)])
	{
		[delegate handleDrugEdited];
	}					

    isNewManagedDrug = NO;
    isExistingManagedDrugRequiringNotification = NO;
    
	[self.tableView	reloadData];
}

- (void)handleEditDrugCancel
{
    // We still need to reload here because the user may have edited a picklist value and then cancelled out
	[self.tableView	reloadData];    
}

- (void)handleDrugDelete
{
	if (delegate && [delegate respondsToSelector:@selector(handleDrugDelete:)])
	{
		[delegate handleDrugDelete:drugId];
	}					
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

- (void)handleEdit:(id)sender
{	
	DrugAddEditViewController* drugAddEditController = [[DrugAddEditViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugAddEditViewController"]
																						   bundle:[DosecastUtil getResourceBundle]
																							 mode:DrugAddEditViewControllerModeEditDrug
																						   drugId:drugId
                                                                               treatmentStartDate:nil
																						 delegate:self];	
	[self.navigationController pushViewController:drugAddEditController animated:YES];
}

- (void)refillPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
    
    if (result)
    {
        DataModel* dataModel = [DataModel getInstance];
        Drug* d = [dataModel findDrugWithId:drugId];

        [tableView reloadData];
        
        // Check for whether the refills remaining are 0 and we should display an alert
        if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] && [dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining] && d && [d.dosage getRefillsRemaining] == 0 && [d.dosage isValidValueForRefillQuantity])
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"AlertDrugRefillTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The title on the refill alert"])
                                                                                               message:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"AlertDrugNoRefillsRemainingMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"There are no more refills remaining for %@.", @"The message on the refill alert when no more refills are remaining"]), d.name]];
            [alert showInViewController:self];
        }
    }
    else
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Edit Drug", @"The message in the alert appearing in the Drug Edit view when editing a drug fails"])
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }		
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

- (void)handleRefill:(id)sender
{
	// Premium-only feature
	DataModel* dataModel = [DataModel getInstance];
	if (dataModel.globalSettings.accountType == AccountTypeDemo)
	{
        [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionRefills", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
	}
	else
	{		
        Drug* d = [dataModel findDrugWithId:drugId];
        if (![d.dosage isValidValueForRefillQuantity])
        {
            NSString* refillLabel = [d.dosage getLabelForRefillQuantity];
            NSString* alertTitle = NSLocalizedStringWithDefaultValue(@"ErrorDrugRefillNoRefillQuantityTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Refill Drug", @"The title of the alert appearing in the Drug View when the refill button is pressed and no refill quantity is set"]);
            NSString* alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugRefillNoRefillQuantityMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug cannot be refilled because the %@ has not been set. To refill it, edit it first and set the %@.", @"The message of the alert appearing in the Drug View when the refill button is pressed and no refill quantity is set"]);
            
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:alertTitle
                                                                                               message:[NSString stringWithFormat:alertMessage, refillLabel, refillLabel]];
            [alert showInViewController:self];
        }
        else
        {
            DosecastAlertController* confirmRefillController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
            
            [confirmRefillController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];

            [confirmRefillController addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertRefillDrugConfirmationButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Drug", @"The confirmation button on the alert confirming whether the user wants to refill a drug"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action) {
                                              [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerRefillingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Refilling drug", @"The message appearing in the spinner view when refilling a drug"])];
                                              
                                              [[LocalNotificationManager getInstance] refillPill:drugId
                                                                                       respondTo:self
                                                                                           async:YES];
                                          }]];

            [confirmRefillController showInViewController:self sourceBarButtonItem:(UIBarButtonItem*)sender];
        }
	}
}

- (void)handleViewLog:(id)sender
{
	// Premium-only feature
	DataModel* dataModel = [DataModel getInstance];
	if (dataModel.globalSettings.accountType == AccountTypeDemo)
	{
        [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoseHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"The dose history is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
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
		DrugHistoryViewController* drugHistoryController = [[DrugHistoryViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugHistoryViewController"]
                                                                                                       bundle:[DosecastUtil getResourceBundle]
                                                                                                     personId:nil
                                                                                                       drugId:drugId];
		[self.navigationController pushViewController:drugHistoryController animated:YES];
	}
}

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
    return YES; // Let the user select properties when viewing
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcDynamicCellWidths];
    
    DataModel* dataModel = [DataModel getInstance];
    
    // Determine the inclusion & order of table view sections
    Drug* d = [dataModel findDrugWithId:drugId];
    
    [tableViewSections removeAllObjects];

    if (drugImage)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDrugImage]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDrugName]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDrugType]];
    
    NSString* dosage = [d.dosage getDescriptionForDrugDose:nil];
    if ([dosage length] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDosage]];
    if ([dataModel.apiFlags getFlag:DosecastAPIMultiPersonSupport])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsPerson]];
    if ([d.directions length] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDirections]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsReminder]];

    float remainingQuantity = 0.0f;
    [d.dosage getValueForRemainingQuantity:&remainingQuantity];
    BOOL showRefillQuantityValue = [d.dosage isValidValueForRefillQuantity];
    BOOL showRefillsRemainingValue = ([dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining] && ([d.dosage isValidValueForRefillQuantity] || [d.dosage getRefillsRemaining] > 0));
    BOOL showRefillAlertOptions = ([d.reminder getRefillAlertOptionNum] >= 0);
    BOOL showQuantityRemainingValue = ([d.reminder getRefillAlertOptionNum] >= 0 || remainingQuantity > epsilon);
    
    if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities] &&
        (showRefillQuantityValue || showRefillsRemainingValue || showRefillAlertOptions || showQuantityRemainingValue))
    {
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsRemainingRefill]];
    }

    if (d.reminder.expirationDate)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsExpiration]];
    
    [doctorPharmacyRows removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPIPrescriptionNumberSupport] && [d.prescriptionNum length] > 0)
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugViewControllerDoctorPharmacyRowsPrescriptionNum]];
    if ([dataModel.apiFlags getFlag:DosecastAPIDoctorSupport] && dataModel.contactsHelper.accessGranted && d.doctorContact.recordID != kABRecordInvalidID)
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugViewControllerDoctorPharmacyRowsDoctor]];
    if ([dataModel.apiFlags getFlag:DosecastAPIPharmacySupport] && dataModel.contactsHelper.accessGranted && d.pharmacyContact.recordID != kABRecordInvalidID)
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugViewControllerDoctorPharmacyRowsPharmacy]];
    if ([doctorPharmacyRows count] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsDoctorPharmacy]];
    
    if ([d.notes length] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsNotes]];

    [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsArchived]];

    // Display the reminders cell for interval or scheduled drugs only
    if (!d.reminder.archived && ![d.reminder isKindOfClass:[AsNeededDrugReminder class]])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsReminderSwitch]];
    // Display the logMissedDoses cellfor scheduled drugs only
    if (!d.reminder.archived && [d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugViewControllerSectionsLogMissedDoses]];

	return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DataModel* dataModel = [DataModel getInstance];    
    Drug* d = [dataModel findDrugWithId:drugId];

	DrugViewControllerSections controllerSection = (DrugViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];
    if (controllerSection == DrugViewControllerSectionsDoctorPharmacy)
        return [doctorPharmacyRows count];
    else if (controllerSection == DrugViewControllerSectionsReminderSwitch)
    {
        if (d.reminder.remindersEnabled)
            return 2;
        else
            return 1;
    }
    else
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	DataModel* dataModel = [DataModel getInstance];
	Drug* d = [dataModel findDrugWithId:drugId];
	UIColor* drugViewLabelColor = [DosecastUtil getDrugViewLabelColor];
	UIColor* normalTextColor = (d.reminder.archived ? [UIColor lightGrayColor] : [UIColor blackColor]);
    UIColor* warningTextColor = (d.reminder.archived ? [UIColor lightGrayColor] : [DosecastUtil getDrugWarningLabelColor]);
    BOOL allowWarningImageDisplay = !d.reminder.archived;

	DrugViewControllerSections section = (DrugViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];
    if (section == DrugViewControllerSectionsDrugName)
	{
		UILabel* header = (UILabel*)[nameCell viewWithTag:1];
		UILabel* value = (UILabel*)[nameCell viewWithTag:2];

		header.textColor = drugViewLabelColor;
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);
		value.text = d.name;
        value.textColor = normalTextColor;
		return nameCell;
	}
    else if (section == DrugViewControllerSectionsPerson)    
	{
		UILabel* header = (UILabel*)[personCell viewWithTag:1];
		UILabel* value = (UILabel*)[personCell viewWithTag:2];
        
		header.textColor = drugViewLabelColor;
        header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonTakenBy", @"Dosecast", [DosecastUtil getResourceBundle], @"For", @"The Person For label in the Drug Edit view"]);
        if ([d.personId length] == 0)
            value.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]);
        else
            value.text = [dataModel.globalSettings.personNames nameForGuid:d.personId];
        value.textColor = normalTextColor;
		return personCell;
	}
	else if (section == DrugViewControllerSectionsDrugType)
	{
		UILabel* header = (UILabel*)[typeCell viewWithTag:1];
		UILabel* value = (UILabel*)[typeCell viewWithTag:2];

		header.textColor = drugViewLabelColor;
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type", @"The Drug Type label in the Drug Edit view"]);
		value.text = [d.dosage getTypeName];
        value.textColor = normalTextColor;
		return typeCell;
	}	
    else if (section == DrugViewControllerSectionsDrugImage)
	{
        UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
        backView.backgroundColor = [UIColor clearColor];
        drugImageCell.backgroundView = backView;
        drugImageCell.backgroundColor = [UIColor clearColor];

        UIView* containerView = [self.drugImageCell viewWithTag:1];
        containerView.backgroundColor = [UIColor clearColor];

        UIImageView *thumb = (UIImageView *)[containerView viewWithTag:2];
        thumb.backgroundColor = [DosecastUtil getDrugImagePlaceholderColor];
        
        UIActivityIndicatorView *activity = (UIActivityIndicatorView *)[containerView viewWithTag:4];
        [activity startAnimating];
        activity.layer.zPosition += 1; // Make sure this appears on top of everything else

        UILabel *noDrugLabel = (UILabel *)[containerView viewWithTag:3];
        noDrugLabel.text = NSLocalizedStringWithDefaultValue(@"NoDrugImagePlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"No drug image", @"The default placeholder string when no image has been set throughout the client "]);

        if ( drugImage != nil )
        {
            thumb.image = drugImage;
            noDrugLabel.hidden = YES;
        }
        else
        {
            BOOL hasPlaceholderImage = self.drugPlaceholderImageView.image != nil;
            
            thumb.image = hasPlaceholderImage ? self.drugPlaceholderImageView.image : nil;
            
            noDrugLabel.hidden = hasPlaceholderImage;
        }
        
        [activity stopAnimating];
        
		return drugImageCell;
    }
	else if (section == DrugViewControllerSectionsDosage)
	{
		UILabel* header = (UILabel*)[dosageCell viewWithTag:1];
		UILabel* value = (UILabel*)[dosageCell viewWithTag:2];

		header.textColor = drugViewLabelColor;
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"]);
		value.text = [d.dosage getDescriptionForDrugDose:nil];
        value.textColor = normalTextColor;
        value.hidden = NO;
        
		return dosageCell;
	}
	else if (section == DrugViewControllerSectionsDirections)
	{
		UILabel* header = (UILabel*)[directionsCell viewWithTag:1];
		UILabel* value = (UILabel*)[directionsCell viewWithTag:2];

		header.textColor = drugViewLabelColor;
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirections", @"Dosecast", [DosecastUtil getResourceBundle], @"Directions", @"The Directions label in the Drug Edit view"]);
		value.text = d.directions;
        value.textColor = normalTextColor;
        value.hidden = NO;
		return directionsCell;
	}
	else if (section == DrugViewControllerSectionsReminder)			 
	{
		if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
		{
			ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)d.reminder;

			UILabel* takeDrugLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:1];
			takeDrugLabel.textColor = drugViewLabelColor;
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);

			UILabel* scheduleIntervalLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:2];
			scheduleIntervalLabel.textColor = drugViewLabelColor;
			scheduleIntervalLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequency", @"Dosecast", [DosecastUtil getResourceBundle], @"Frequency", @"The Frequency label for scheduled drugs in the Drug Edit view"]);

			UILabel* remindText = (UILabel*)[takeDrugScheduledCell viewWithTag:6];
			remindText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduled", @"Dosecast", [DosecastUtil getResourceBundle], @"On a schedule", @"The Take Drug value for scheduled drugs in the Drug Edit view"]);
            remindText.textColor = normalTextColor;

			UILabel* scheduleIntervalText = (UILabel*)[takeDrugScheduledCell viewWithTag:7];
            scheduleIntervalText.textColor = normalTextColor;
            
			if (scheduledReminder.frequency == ScheduledDrugFrequencyDaily)
				scheduleIntervalText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyDaily", @"Dosecast", [DosecastUtil getResourceBundle], @"Daily", @"The Frequency value for daily scheduled drugs in the Drug Edit view"]);
			else if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly)
            {
                scheduleIntervalText.text = [NSString stringWithFormat:@"%@, %@:",
                                       NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeeklyLocal", @"Dosecast", [DosecastUtil getResourceBundle], @"Weekly", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]),
                                       [NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeekdayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Every", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]) lowercaseString]];
            }
			else if (scheduledReminder.frequency == ScheduledDrugFrequencyMonthly)
                scheduleIntervalText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyMonthly", @"Dosecast", [DosecastUtil getResourceBundle], @"Monthly", @"The Frequency value for monthly scheduled drugs in the Drug Edit view"]);
            else // ScheduledDrugFrequencyCustom
            {
                NSString* daysPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
                NSString* daysSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);		
                NSString* weeksPlural = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"weeks", @"The plural name for week in scheduled drug descriptions"]);
                NSString* weeksSingular = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"week", @"The singular name for week in scheduled drug descriptions"]);		
                
                NSString* unitName = nil;
                if (scheduledReminder.customFrequencyPeriod == ScheduledDrugFrequencyCustomPeriodDays)
                {
                    if ([DosecastUtil shouldUseSingularForInteger:scheduledReminder.customFrequencyNum])
                        unitName = daysSingular;
                    else
                        unitName = daysPlural;
                }
                else // ScheduleRepeatPeriodWeeks
                {
                    if ([DosecastUtil shouldUseSingularForInteger:scheduledReminder.customFrequencyNum])
                        unitName = weeksSingular;
                    else
                        unitName = weeksPlural;        
                }
                
                scheduleIntervalText.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ScheduleRepeatPeriodPhraseDetail", @"Dosecast", [DosecastUtil getResourceBundle], @"Every %d %@", @"The detailed phrase for describing schedule repeat periods for scheduled drugs"]), scheduledReminder.customFrequencyNum, unitName];
            }
						
            // Start tracking the last variable-position label in the cell
            int lastLabelPos = scheduleIntervalText.frame.origin.y + scheduleIntervalText.frame.size.height;

            BOOL showWeekdayLabels = (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly);
            
            // Set the weekday label values & visibility
            int numWeekdays = 0;
            if (showWeekdayLabels && scheduledReminder.weekdays)
                numWeekdays = (int)[scheduledReminder.weekdays count];
            int numWeekdaysDisplayed = (((float)numWeekdays) / 2.0) + 0.5;

            NSArray* weekdayNames = [dateFormatter weekdaySymbols];
            NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            int firstWeekday = (int)[cal firstWeekday];

            NSMutableArray* weekdayTextLabels = [[NSMutableArray alloc] init];
			for (int i = 0; i < 4; i++)
			{
				[weekdayTextLabels addObject:[takeDrugScheduledCell viewWithTag:8+i]];
			}

            for (int i = 0; i < [weekdayTextLabels count]; i++)
            {
                BOOL isHidden = i > (numWeekdaysDisplayed-1);
                UILabel* l = (UILabel*)[weekdayTextLabels objectAtIndex:i];
                l.hidden = isHidden;
                if (!isHidden)
                    lastLabelPos += l.frame.size.height;
            }

            NSMutableString* weekdayListStr = [NSMutableString stringWithString:@""];
            for (int labelNum = 0; labelNum < numWeekdaysDisplayed; labelNum++)
            {
                [weekdayListStr setString:@""];
                int numPositions = (numWeekdays >= (labelNum+1)*2) ? 2 : 1;
                for (int pos = 0; pos < numPositions; pos++)
                {
                    if (pos > 0)
                        [weekdayListStr appendString:@" "];
                    int weekday = [[scheduledReminder.weekdays objectAtIndex:((labelNum*2)+pos)] intValue];

                    [weekdayListStr appendString:[weekdayNames objectAtIndex:weekday-firstWeekday]];
                    if (labelNum != (numWeekdaysDisplayed-1) || (pos != (numPositions-1)))
                        [weekdayListStr appendString:@","];
                }
                UILabel* weeklyLabel = (UILabel*)[weekdayTextLabels objectAtIndex:labelNum];
                weeklyLabel.text = weekdayListStr;
                weeklyLabel.textColor = normalTextColor;
            }
            
            // Add a margin under the weekdays (if any)
            lastLabelPos += WEEKDAY_LABELS_MARGIN;

            UILabel* treatmentStartsHeader = (UILabel*)[takeDrugScheduledCell viewWithTag:3];
			treatmentStartsHeader.textColor = drugViewLabelColor;
			treatmentStartsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
            treatmentStartsHeader.frame = CGRectMake(treatmentStartsHeader.frame.origin.x, lastLabelPos, treatmentStartsHeader.frame.size.width, treatmentStartsHeader.frame.size.height);

			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			UILabel* treatmentStartsLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:12];
			treatmentStartsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentStartDate], [dateFormatter stringFromDate:d.reminder.treatmentStartDate]];
            treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, lastLabelPos, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
            treatmentStartsLabel.textColor = normalTextColor;

            lastLabelPos += treatmentStartsLabel.frame.size.height + WEEKDAY_LABELS_MARGIN;

            UILabel* treatmentEndsHeader = (UILabel*)[takeDrugScheduledCell viewWithTag:4];
			treatmentEndsHeader.textColor = drugViewLabelColor;
			treatmentEndsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
            treatmentEndsHeader.frame = CGRectMake(treatmentEndsHeader.frame.origin.x, lastLabelPos, treatmentEndsHeader.frame.size.width, treatmentEndsHeader.frame.size.height);
            
			UILabel* treatmentEndsLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:13];
			if (d.reminder.treatmentEndDate != nil)
				treatmentEndsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentEndDate], [dateFormatter stringFromDate:d.reminder.treatmentEndDate]];
			else
				treatmentEndsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
            treatmentEndsLabel.frame = CGRectMake(treatmentEndsLabel.frame.origin.x, lastLabelPos, treatmentEndsLabel.frame.size.width, treatmentEndsLabel.frame.size.height);
            treatmentEndsLabel.textColor = normalTextColor;

            lastLabelPos += treatmentEndsLabel.frame.size.height + WEEKDAY_LABELS_MARGIN;
            
            UILabel* timeOfDayLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:5];
			timeOfDayLabel.textColor = drugViewLabelColor;
			timeOfDayLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduleTimes", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Day", @"The Time of Day label for scheduled drugs in the Drug Edit view"]);
            timeOfDayLabel.frame = CGRectMake(timeOfDayLabel.frame.origin.x, lastLabelPos, timeOfDayLabel.frame.size.width, timeOfDayLabel.frame.size.height);

            lastLabelPos += WEEKDAY_LABELS_MARGIN;
            
            NSMutableArray* scheduleIntervalTextLabels = [[NSMutableArray alloc] init];
			for (int i = 0; i < MAX_REMINDER_SCHEDULE_TIME_LABELS; i++)
			{
				[scheduleIntervalTextLabels addObject:[takeDrugScheduledCell viewWithTag:14+i]];
			}
			
			int numTimes = (int)[scheduledReminder.reminderTimes count];
			if (numTimes == 0)
			{
                UILabel* l = (UILabel*)[scheduleIntervalTextLabels objectAtIndex:0];
                l.textColor = normalTextColor;
				l.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditScheduleTimesNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The none value in the Take Drug cell for scheduled reminders of the Drug Edit view"]);
                l.frame = CGRectMake(l.frame.origin.x, lastLabelPos, l.frame.size.width, l.frame.size.height);
				for (int i = 1; i < [scheduleIntervalTextLabels count]; i++)
					((UILabel*)[scheduleIntervalTextLabels objectAtIndex:i]).hidden = YES;
			}
			else
			{
                UILabel* l = (UILabel*)[scheduleIntervalTextLabels objectAtIndex:0];
                l.frame = CGRectMake(l.frame.origin.x, lastLabelPos, l.frame.size.width, l.frame.size.height);
                lastLabelPos += l.frame.size.height;

				int numLabelsDisplayed = (((float)numTimes) / 2.0) + 0.5;
				for (int i = 1; i < [scheduleIntervalTextLabels count]; i++)
                {
                    BOOL isHidden = i > (numLabelsDisplayed-1);
                    l = (UILabel*)[scheduleIntervalTextLabels objectAtIndex:i];
                    l.hidden = isHidden;
                    if (!isHidden)
                    {
                        l.frame = CGRectMake(l.frame.origin.x, lastLabelPos, l.frame.size.width, l.frame.size.height);
                        lastLabelPos += l.frame.size.height;
                    }
                }
				
				// Populate the schedule times
				NSMutableString* timeListStr = [NSMutableString stringWithString:@""];
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				for (int labelNum = 0; labelNum < numLabelsDisplayed; labelNum++)
				{
					[timeListStr setString:@""];
					int numPositions = (numTimes >= (labelNum+1)*2) ? 2 : 1;
					for (int pos = 0; pos < numPositions; pos++)
					{
						if (pos > 0)
							[timeListStr appendString:@" "];
						[timeListStr appendString:[dateFormatter stringFromDate:[scheduledReminder getReminderTime:((labelNum*2)+pos)]]];
						if (labelNum != (numLabelsDisplayed-1) || (pos != (numPositions-1)))
							[timeListStr appendString:@","];
					}
                    UILabel* scheduleLabel = (UILabel*)[scheduleIntervalTextLabels objectAtIndex:labelNum];
					scheduleLabel.text = timeListStr;
                    scheduleLabel.textColor = normalTextColor;
				}				
			}
			
			return takeDrugScheduledCell;			
		}
		else if ([d.reminder isKindOfClass:[IntervalDrugReminder class]])
		{
			UILabel* takeDrugLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:1];			
			takeDrugLabel.textColor = drugViewLabelColor;
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);

			UILabel* scheduleIntervalLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:2];
			scheduleIntervalLabel.textColor = drugViewLabelColor;
			scheduleIntervalLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalPeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval", @"The Interval label for interval drugs in the Drug Edit view"]);
			
            IntervalDrugReminder* intervalReminder = (IntervalDrugReminder*)d.reminder;
            int numMinutes = intervalReminder.interval/60;			
            BOOL showDoseLimit = (numMinutes < MIN_PER_DAY);
            BOOL showDosesTaken = (showDoseLimit && intervalReminder.limitType != IntervalDrugReminderDrugLimitTypeNever);
            BOOL showDosesTakenWarning = (showDosesTaken && [d wouldExceedDoseLimitIfTakenAtDate:viewDate nextAvailableDoseTime:nil] && allowWarningImageDisplay);

            UILabel* dosesTakenHeader = (UILabel*)[takeDrugIntervalCell viewWithTag:3];
            UIImageView* dosesTakenWarningImage = (UIImageView*)[takeDrugIntervalCell viewWithTag:13];
            dosesTakenHeader.textColor = drugViewLabelColor;
            dosesTakenHeader.hidden = !showDosesTaken;
            if (dosesTakenWarningImage)
                dosesTakenWarningImage.hidden = !showDosesTakenWarning;
            if (showDosesTaken)
                dosesTakenHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Doses Taken", @"The Doses Taken label in the Drug View view"]);
                        
            UILabel* doseLimitHeader = (UILabel*)[takeDrugIntervalCell viewWithTag:4];
            doseLimitHeader.textColor = drugViewLabelColor;
            doseLimitHeader.hidden = !showDoseLimit;
            if (showDoseLimit)
            {
                doseLimitHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
                if (showDosesTaken)
                    doseLimitHeader.frame = CGRectMake(doseLimitHeader.frame.origin.x, dosesTakenHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitHeader.frame.size.width, doseLimitHeader.frame.size.height);
                else
                    doseLimitHeader.frame = CGRectMake(doseLimitHeader.frame.origin.x, scheduleIntervalLabel.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitHeader.frame.size.width, doseLimitHeader.frame.size.height);                    
            }

			UILabel* treatmentStartsHeader = (UILabel*)[takeDrugIntervalCell viewWithTag:5];
			treatmentStartsHeader.textColor = drugViewLabelColor;
			treatmentStartsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
			if (showDoseLimit)
                treatmentStartsHeader.frame = CGRectMake(treatmentStartsHeader.frame.origin.x, doseLimitHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsHeader.frame.size.width, treatmentStartsHeader.frame.size.height);
            else
                treatmentStartsHeader.frame = CGRectMake(treatmentStartsHeader.frame.origin.x, scheduleIntervalLabel.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsHeader.frame.size.width, treatmentStartsHeader.frame.size.height);
            
			UILabel* treatmentEndsHeader = (UILabel*)[takeDrugIntervalCell viewWithTag:6];
			treatmentEndsHeader.textColor = drugViewLabelColor;
			treatmentEndsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
            treatmentEndsHeader.frame = CGRectMake(treatmentEndsHeader.frame.origin.x, treatmentStartsHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentEndsHeader.frame.size.width, treatmentEndsHeader.frame.size.height);

			UILabel* remindText = (UILabel*)[takeDrugIntervalCell viewWithTag:7];
			if (dataModel.globalSettings.bedtimeStart != -1 && dataModel.globalSettings.bedtimeEnd != -1)
				remindText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalBedtime", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals until bedtime", @"The Take Drug value for interval drugs in the Drug Edit view when bedtime is defined"]);
			else
				remindText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugInterval", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals", @"The Take Drug value for interval drugs in the Drug Edit view"]);
			remindText.textColor = normalTextColor;
            
			UILabel* scheduleIntervalText = (UILabel*)[takeDrugIntervalCell viewWithTag:8];
			scheduleIntervalText.text = [IntervalDrugReminder intervalDescription:numMinutes];
            scheduleIntervalText.textColor = normalTextColor;
            
            UILabel* dosesTakenValue = (UILabel*)[takeDrugIntervalCell viewWithTag:9];
            dosesTakenValue.hidden = !showDosesTaken;
            if (showDosesTaken)
            {
                if (showDosesTakenWarning)
                    dosesTakenValue.textColor = warningTextColor;
                else
                    dosesTakenValue.textColor = normalTextColor;
                
                int dailyDoseCount= [d getDailyDoseCountAsOfDate:viewDate];
                if (intervalReminder.limitType == IntervalDrugReminderDrugLimitTypePerDay)
                {
                    if ([DosecastUtil shouldUseSingularForInteger:dailyDoseCount])
                        dosesTakenValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePerDaySingular", @"Dosecast", [DosecastUtil getResourceBundle], @"1 dose taken today", @"The singular Doses Taken phrase for per-day dose limits in the Drug View view"]);
                    else
                        dosesTakenValue.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePerDayPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"%d doses taken today", @"The plural Doses Taken phrase for per-day dose limits in the Drug View view"]), dailyDoseCount];
                }
                else // IntervalDrugReminderDrugLimitTypePer24Hours
                {
                    if ([DosecastUtil shouldUseSingularForInteger:dailyDoseCount])
                        dosesTakenValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePer24HoursSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"1 dose taken in 24 hrs", @"The singular Doses Taken phrase for per-24-hour dose limits in the Drug View view"]);
                    else
                        dosesTakenValue.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePer24HoursPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"%d doses taken in 24 hrs", @"The plural Doses Taken phrase for per-24-hour dose limits in the Drug View view"]), dailyDoseCount];   
                }
            }
            
            UILabel* doseLimitValue = (UILabel*)[takeDrugIntervalCell viewWithTag:10];
            doseLimitValue.hidden = !showDoseLimit;
            if (showDoseLimit)
            {
                doseLimitValue.text = [intervalReminder getDoseLimitDescription];
                doseLimitValue.textColor = normalTextColor;
                if (showDosesTaken)
                    doseLimitValue.frame = CGRectMake(doseLimitValue.frame.origin.x, dosesTakenValue.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitValue.frame.size.width, doseLimitValue.frame.size.height);
                else
                    doseLimitValue.frame = CGRectMake(doseLimitValue.frame.origin.x, scheduleIntervalText.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitValue.frame.size.width, doseLimitValue.frame.size.height);                    
            }
            
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			UILabel* treatmentStartsLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:11];
			treatmentStartsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentStartDate], [dateFormatter stringFromDate:d.reminder.treatmentStartDate]];
            treatmentStartsLabel.textColor = normalTextColor;
			if (showDoseLimit)
                treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, doseLimitValue.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
            else
                treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, scheduleIntervalText.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);

			UILabel* treatmentEndsLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:12];
			if (d.reminder.treatmentEndDate != nil)
				treatmentEndsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentEndDate], [dateFormatter stringFromDate:d.reminder.treatmentEndDate]];
			else
				treatmentEndsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
            treatmentEndsLabel.textColor = normalTextColor;
            treatmentEndsLabel.frame = CGRectMake(treatmentEndsLabel.frame.origin.x, treatmentStartsLabel.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentEndsLabel.frame.size.width, treatmentEndsLabel.frame.size.height);
			
			return takeDrugIntervalCell;			
		}
		else // AsNeededDrugReminder
		{
			UILabel* takeDrugLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:1];
			takeDrugLabel.textColor = drugViewLabelColor;
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
            
            AsNeededDrugReminder* asNeededReminder = (AsNeededDrugReminder*)d.reminder;
            BOOL showDosesTaken = (asNeededReminder.limitType != AsNeededDrugReminderDrugLimitTypeNever);
            BOOL showDosesTakenWarning = (showDosesTaken && [d wouldExceedDoseLimitIfTakenAtDate:viewDate nextAvailableDoseTime:nil] && allowWarningImageDisplay);
            UILabel* dosesTakenHeader = (UILabel*)[takeDrugAsNeededCell viewWithTag:2];
            UIImageView* dosesTakenWarningImage = (UIImageView*)[takeDrugAsNeededCell viewWithTag:11];
            dosesTakenHeader.textColor = drugViewLabelColor;
            dosesTakenHeader.hidden = !showDosesTaken;
            if (dosesTakenWarningImage)
                dosesTakenWarningImage.hidden = !showDosesTakenWarning;
            if (showDosesTaken)
                dosesTakenHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Doses Taken", @"The Doses Taken label in the Drug View view"]);
            
            UILabel* doseLimitHeader = (UILabel*)[takeDrugAsNeededCell viewWithTag:3];
            doseLimitHeader.textColor = drugViewLabelColor;
            doseLimitHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
            if (showDosesTaken)
                doseLimitHeader.frame = CGRectMake(doseLimitHeader.frame.origin.x, dosesTakenHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitHeader.frame.size.width, doseLimitHeader.frame.size.height);
            else
                doseLimitHeader.frame = CGRectMake(doseLimitHeader.frame.origin.x, takeDrugLabel.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitHeader.frame.size.width, doseLimitHeader.frame.size.height);
            
            UILabel* treatmentStartsHeader = (UILabel*)[takeDrugAsNeededCell viewWithTag:4];
			treatmentStartsHeader.textColor = drugViewLabelColor;
			treatmentStartsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
            treatmentStartsHeader.frame = CGRectMake(treatmentStartsHeader.frame.origin.x, doseLimitHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsHeader.frame.size.width, treatmentStartsHeader.frame.size.height);

			UILabel* treatmentEndsHeader = (UILabel*)[takeDrugAsNeededCell viewWithTag:5];
			treatmentEndsHeader.textColor = drugViewLabelColor;
			treatmentEndsHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
            treatmentEndsHeader.frame = CGRectMake(treatmentEndsHeader.frame.origin.x, treatmentStartsHeader.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentEndsHeader.frame.size.width, treatmentEndsHeader.frame.size.height);

			UILabel* remindText = (UILabel*)[takeDrugAsNeededCell viewWithTag:6];
			remindText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugAsNeeded", @"Dosecast", [DosecastUtil getResourceBundle], @"As needed", @"The Take Drug value for as-needed drugs in the Drug Edit view"]);
            remindText.textColor = normalTextColor;
            
            UILabel* dosesTakenValue = (UILabel*)[takeDrugAsNeededCell viewWithTag:7];
            dosesTakenValue.hidden = !showDosesTaken;
            if (showDosesTaken)
            {
                if (showDosesTakenWarning)
                    dosesTakenValue.textColor = warningTextColor;
                else
                    dosesTakenValue.textColor = normalTextColor;
                int dailyDoseCount= [d getDailyDoseCountAsOfDate:viewDate];
                if (asNeededReminder.limitType == AsNeededDrugReminderDrugLimitTypePerDay)
                {
                    if ([DosecastUtil shouldUseSingularForInteger:dailyDoseCount])
                        dosesTakenValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePerDaySingular", @"Dosecast", [DosecastUtil getResourceBundle], @"1 dose taken today", @"The singular Doses Taken phrase for per-day dose limits in the Drug View view"]);
                    else
                        dosesTakenValue.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePerDayPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"%d doses taken today", @"The plural Doses Taken phrase for per-day dose limits in the Drug View view"]), dailyDoseCount];
                }
                else // AsNeededDrugReminderDrugLimitTypePer24Hours
                {
                    if ([DosecastUtil shouldUseSingularForInteger:dailyDoseCount])
                        dosesTakenValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePer24HoursSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"1 dose taken in 24 hrs", @"The singular Doses Taken phrase for per-24-hour dose limits in the Drug View view"]);
                    else
                        dosesTakenValue.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosesTakenPhrasePer24HoursPlural", @"Dosecast", [DosecastUtil getResourceBundle], @"%d doses taken in 24 hrs", @"The plural Doses Taken phrase for per-24-hour dose limits in the Drug View view"]), dailyDoseCount];   
                }
            }
            
            UILabel* doseLimitValue = (UILabel*)[takeDrugAsNeededCell viewWithTag:8];
            doseLimitValue.text = [asNeededReminder getDoseLimitDescription];
            doseLimitValue.textColor = normalTextColor;
            if (showDosesTaken)
                doseLimitValue.frame = CGRectMake(doseLimitValue.frame.origin.x, dosesTakenValue.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitValue.frame.size.width, doseLimitValue.frame.size.height);
            else
                doseLimitValue.frame = CGRectMake(doseLimitValue.frame.origin.x, remindText.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, doseLimitValue.frame.size.width, doseLimitValue.frame.size.height);

            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			UILabel* treatmentStartsLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:9];
			treatmentStartsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentStartDate], [dateFormatter stringFromDate:d.reminder.treatmentStartDate]];			
            treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, doseLimitValue.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
            treatmentStartsLabel.textColor = normalTextColor;
            
			UILabel* treatmentEndsLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:10];
			if (d.reminder.treatmentEndDate != nil)
				treatmentEndsLabel.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.treatmentEndDate], [dateFormatter stringFromDate:d.reminder.treatmentEndDate]];
			else
				treatmentEndsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
            treatmentEndsLabel.textColor = normalTextColor;
            treatmentEndsLabel.frame = CGRectMake(treatmentEndsLabel.frame.origin.x, treatmentStartsLabel.frame.origin.y + DOSE_LIMIT_LABEL_HEIGHT, treatmentEndsLabel.frame.size.width, treatmentEndsLabel.frame.size.height);

			return takeDrugAsNeededCell;			
		}		
	}
	else if (section == DrugViewControllerSectionsRemainingRefill)
	{
		UILabel* quantityRemainingHeader = (UILabel*)[remainingRefillCell viewWithTag:1];
		UILabel* refillQuantityHeader = (UILabel*)[remainingRefillCell viewWithTag:2];
		UILabel* refillsRemainingHeader = (UILabel*)[remainingRefillCell viewWithTag:3];        
		UILabel* refillAlertHeader = (UILabel*)[remainingRefillCell viewWithTag:4];
		UILabel* quantityRemainingValue = (UILabel*)[remainingRefillCell viewWithTag:5];
		UILabel* refillQuantityValue = (UILabel*)[remainingRefillCell viewWithTag:6];	
        UILabel* refillsRemainingValue = (UILabel*)[remainingRefillCell viewWithTag:7];	
		UILabel* refillAlertValue = (UILabel*)[remainingRefillCell viewWithTag:8];	
		UIImageView* quantityRemainingWarningImage = (UIImageView*)[remainingRefillCell viewWithTag:9];
		UIImageView* refillsRemainingWarningImage = (UIImageView*)[remainingRefillCell viewWithTag:10];
		
		// Display the quantity remaining warning, if necessary
		if ([d isEmpty] || [d isRunningLow])
		{
            if (quantityRemainingWarningImage)
                quantityRemainingWarningImage.hidden = !allowWarningImageDisplay;
			quantityRemainingValue.textColor = warningTextColor;
		}
		else
		{
            if (quantityRemainingWarningImage)
                quantityRemainingWarningImage.hidden = YES;
			quantityRemainingValue.textColor = normalTextColor;
		}
        
		// Display the refill remaining warning, if necessary
		if ([dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining] && [d.dosage getRefillsRemaining] == 0 && [d.dosage isValidValueForRefillQuantity])
		{
            if (refillsRemainingWarningImage)
                refillsRemainingWarningImage.hidden = !allowWarningImageDisplay;
			refillsRemainingValue.textColor = warningTextColor;
		}
		else
		{
            if (refillsRemainingWarningImage)
                refillsRemainingWarningImage.hidden = YES;
			refillsRemainingValue.textColor = normalTextColor;
		}

        int nextY = quantityRemainingHeader.frame.origin.y;

		// Display the remaining/refill labels
        float remainingQuantity = 0.0f;
        [d.dosage getValueForRemainingQuantity:&remainingQuantity];

		BOOL showQuantityRemainingValue = ([d.reminder getRefillAlertOptionNum] >= 0 || remainingQuantity > epsilon);
		quantityRemainingHeader.hidden = !showQuantityRemainingValue;
		quantityRemainingValue.hidden = !showQuantityRemainingValue;
		if (showQuantityRemainingValue)
		{
			quantityRemainingHeader.textColor = drugViewLabelColor;
			quantityRemainingHeader.text = [d.dosage getLabelForRemainingQuantity];
			
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([d.dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
			{
				quantityRemainingValue.text = [d.dosage getDescriptionForRemainingQuantity:numDecimals];
			}
			else
				quantityRemainingValue.text = nil;
            
            nextY += REMAINING_REFILL_LABEL_HEIGHT;
		}
		
		BOOL showRefillQuantityValue = [d.dosage isValidValueForRefillQuantity];
		refillQuantityHeader.hidden = !showRefillQuantityValue;
		refillQuantityValue.hidden = !showRefillQuantityValue;
		if (showRefillQuantityValue)
		{
            refillQuantityHeader.frame = CGRectMake(refillQuantityHeader.frame.origin.x, nextY, refillQuantityHeader.frame.size.width, refillQuantityHeader.frame.size.height);
            refillQuantityValue.frame = CGRectMake(refillQuantityValue.frame.origin.x, nextY, refillQuantityValue.frame.size.width, refillQuantityValue.frame.size.height);
			
			refillQuantityHeader.textColor = drugViewLabelColor;
			refillQuantityHeader.text = [d.dosage getLabelForRefillQuantity];
			
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([d.dosage getRefillQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
			{
				refillQuantityValue.text = [d.dosage getDescriptionForRefillQuantity:numDecimals];
			}
			else
				refillQuantityValue.text = nil;		
            
            refillQuantityValue.textColor = normalTextColor;
            
            nextY += REMAINING_REFILL_LABEL_HEIGHT;
		}
        
        BOOL showRefillsRemainingValue = ([dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining] && ([d.dosage isValidValueForRefillQuantity] || [d.dosage getRefillsRemaining] > 0));
		refillsRemainingHeader.hidden = !showRefillsRemainingValue;
		refillsRemainingValue.hidden = !showRefillsRemainingValue;
		if (showRefillsRemainingValue)
		{
            refillsRemainingHeader.frame = CGRectMake(refillsRemainingHeader.frame.origin.x, nextY, refillsRemainingHeader.frame.size.width, refillsRemainingHeader.frame.size.height);
            refillsRemainingValue.frame = CGRectMake(refillsRemainingValue.frame.origin.x, nextY, refillsRemainingValue.frame.size.width, refillsRemainingValue.frame.size.height);
            if (refillsRemainingWarningImage)
                refillsRemainingWarningImage.frame = CGRectMake(refillsRemainingWarningImage.frame.origin.x, nextY+WARNING_IMAGE_HEADER_OFFSET, refillsRemainingWarningImage.frame.size.width, refillsRemainingWarningImage.frame.size.height);
            
			refillsRemainingHeader.textColor = drugViewLabelColor;
			refillsRemainingHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillsRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills Remaining", @"The Refills Remaining label in the Drug Edit view"]);
			
            refillsRemainingValue.text = [NSString stringWithFormat:@"%d", [d.dosage getRefillsRemaining]];
            
            nextY += REMAINING_REFILL_LABEL_HEIGHT;
		}
        
		BOOL showRefillAlertOptions = ([d.reminder getRefillAlertOptionNum] >= 0);
		refillAlertHeader.hidden = !showRefillAlertOptions;
		refillAlertValue.hidden = !showRefillAlertOptions;
		if (showRefillAlertOptions)
		{
            refillAlertHeader.frame = CGRectMake(refillAlertHeader.frame.origin.x, nextY, refillAlertHeader.frame.size.width, refillAlertHeader.frame.size.height);
            refillAlertValue.frame = CGRectMake(refillAlertValue.frame.origin.x, nextY, refillAlertValue.frame.size.width, refillAlertValue.frame.size.height);
			
			refillAlertHeader.textColor  = drugViewLabelColor;
			NSArray* refillAlertOptions = [d.reminder getRefillAlertOptions];
			refillAlertHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The Refill Alert label in the Drug Edit view"]);
			refillAlertValue.text = [refillAlertOptions objectAtIndex:[d.reminder getRefillAlertOptionNum]];
            refillAlertValue.textColor = normalTextColor;
		}
		
		return remainingRefillCell;
	}
    else if (section == DrugViewControllerSectionsExpiration)
    {
		UILabel* expirationDateHeader = (UILabel*)[expirationCell viewWithTag:1];
		UILabel* expirationAlertHeader = (UILabel*)[expirationCell viewWithTag:2];
		UILabel* expirationDateValue = (UILabel*)[expirationCell viewWithTag:3];
		UILabel* expirationAlertValue = (UILabel*)[expirationCell viewWithTag:4];
		UIImageView* expirationDateWarningImage = (UIImageView*)[expirationCell viewWithTag:5];
		
		// Display the expiration warning, if necessary
		if ([d.reminder isExpired] || [d.reminder isExpiringSoon])
		{
            if (expirationDateWarningImage)
                expirationDateWarningImage.hidden = !allowWarningImageDisplay;
			expirationDateValue.textColor = warningTextColor;
		}
		else
		{
            if (expirationDateWarningImage)
                expirationDateWarningImage.hidden = YES;
			expirationDateValue.textColor = normalTextColor;
		}
        
        if (d.reminder.expirationDate)
        {
            expirationDateHeader.textColor = drugViewLabelColor;
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            expirationDateHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationDate", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Date", @"The Expiration Date label in the Drug Edit view"]);
            expirationDateValue.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:d.reminder.expirationDate], [dateFormatter stringFromDate:d.reminder.expirationDate]];
        }
        
        if ([d.reminder getExpirationAlertOptionNum] >= 0)
        {
            expirationAlertHeader.textColor = drugViewLabelColor;
            expirationAlertHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Alert", @"The Expiration Alert label in the Drug Edit view"]);
            NSArray* expirationAlertOptions = [d.reminder getExpirationAlertOptions];
            expirationAlertValue.text = [expirationAlertOptions objectAtIndex:[d.reminder getExpirationAlertOptionNum]];
            expirationAlertHeader.hidden = NO;
            expirationAlertValue.hidden = NO;
        }
        else
        {
            expirationAlertHeader.hidden = YES;
            expirationAlertValue.hidden = YES;
        }
		
		return expirationCell;
    }
    else if (section == DrugViewControllerSectionsDoctorPharmacy)
    {
        DrugViewControllerDoctorPharmacyRows row = (DrugViewControllerDoctorPharmacyRows)[[doctorPharmacyRows objectAtIndex:indexPath.row] intValue];

        if (row == DrugViewControllerDoctorPharmacyRowsDoctor)
        {
            UILabel* titleText = (UILabel*)[doctorCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[doctorCell viewWithTag:2];
            titleText.textColor = drugViewLabelColor;
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDoctor", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor", @"The Doctor label in the Drug Edit view"]);            
            labelText.text = [d.doctorContact getDisplayName];
            labelText.textColor = normalTextColor;
            
            return doctorCell;
        }
        else if (row == DrugViewControllerDoctorPharmacyRowsPharmacy)
        {
            UILabel* titleText = (UILabel*)[pharmacyCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[pharmacyCell viewWithTag:2];
            titleText.textColor = drugViewLabelColor;
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Pharmacy", @"The Pharmacy label in the Drug Edit view"]);
            labelText.text = [d.pharmacyContact getDisplayName];
            labelText.textColor = normalTextColor;

            return pharmacyCell;
        }
        else if (row == DrugViewControllerDoctorPharmacyRowsPrescriptionNum)
        {
            UILabel* titleText = (UILabel*)[prescriptionNumCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[prescriptionNumCell viewWithTag:2];
            titleText.textColor = drugViewLabelColor;
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPrescriptionNumber", @"Dosecast", [DosecastUtil getResourceBundle], @"Prescription #", @"The Prescription Number label in the Drug Edit view"]);
            
            labelText.text = d.prescriptionNum;
            labelText.textColor = normalTextColor;

            return prescriptionNumCell;
        }
        else
            return nil;
    }
	else if (section == DrugViewControllerSectionsNotes)			 		
    {
        UILabel* header = (UILabel*)[notesCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditNotes", @"Dosecast", [DosecastUtil getResourceBundle], @"Notes", @"The Notes label in the Drug Edit view"]);
        header.textColor = drugViewLabelColor;
		UITextView* textView = (UITextView*)[notesCell viewWithTag:2];
        
        // Initialize the properties of the cell
        textView.text = d.notes;
        textView.editable = NO;
        textView.dataDetectorTypes = UIDataDetectorTypeAll;        
        textView.textColor = normalTextColor;
        
        return notesCell;
    }
    else if (section == DrugViewControllerSectionsArchived)
    {
        UILabel* header = (UILabel*)[archivedCell viewWithTag:1];
        header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditArchived", @"Dosecast", [DosecastUtil getResourceBundle], @"Archived", @"The Archived label in the Drug Edit view"]);
        header.textColor = drugViewLabelColor;
        UILabel* value = (UILabel*)[archivedCell viewWithTag:2];
        
        if ([dataModel.apiFlags getFlag:DosecastAPIDisplayUnarchivedDrugStatusInDrugInfo])
        {
            if (!d.reminder.archived)
                value.text = NSLocalizedStringWithDefaultValue(@"AlertButtonYes", @"Dosecast", [DosecastUtil getResourceBundle], @"Yes", @"The text on the Yes button in an alert"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"AlertButtonNo", @"Dosecast", [DosecastUtil getResourceBundle], @"No", @"The text on the No button in an alert"]);
        }
        else
        {
            if (d.reminder.archived)
                value.text = NSLocalizedStringWithDefaultValue(@"AlertButtonYes", @"Dosecast", [DosecastUtil getResourceBundle], @"Yes", @"The text on the Yes button in an alert"]);
            else
                value.text = NSLocalizedStringWithDefaultValue(@"AlertButtonNo", @"Dosecast", [DosecastUtil getResourceBundle], @"No", @"The text on the No button in an alert"]);
        }
        
        value.textColor = normalTextColor;

        return archivedCell;
    }
	else if (section == DrugViewControllerSectionsReminderSwitch)
	{
        if (indexPath.row == 0)
        {
            UILabel* remindersHeader = (UILabel*)[remindersCell viewWithTag:1];
            remindersHeader.textColor = drugViewLabelColor;
            remindersHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminders", @"The Reminders label in the Drug Edit view"]);
            UILabel* remindersValue = (UILabel*)[remindersCell viewWithTag:2];
            if (d.reminder.remindersEnabled)
                remindersValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                remindersValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);
            remindersValue.textColor = normalTextColor;
            
            return remindersCell;
        }
        else // if indexPath.row == 1
        {
            UILabel* remindersHeader = (UILabel*)[secondaryRemindersCell viewWithTag:1];
            remindersHeader.textColor = drugViewLabelColor;
            remindersHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditSecondaryReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Secondary Reminders", @"The Secondary Reminders label in the Drug Edit view"]);
            UILabel* remindersValue = (UILabel*)[secondaryRemindersCell viewWithTag:2];
            if (d.reminder.secondaryRemindersEnabled)
                remindersValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Reminders cell of the Drug Edit view"]);
            else
                remindersValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemindersOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Reminders cell of the Drug Edit view"]);
            remindersValue.textColor = normalTextColor;
            
            return secondaryRemindersCell;
        }
	}
    else if (section == DrugViewControllerSectionsLogMissedDoses)
	{
        if ([d.reminder isKindOfClass:[ScheduledDrugReminder class]])
        {
            UILabel* logMissedDosesHeader = (UILabel*)[logMissedDosesCell viewWithTag:1];
            logMissedDosesHeader.textColor = drugViewLabelColor;
            logMissedDosesHeader.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Log Missed Doses", @"The Log Missed Doses label in the Drug Edit view"]);
            UILabel* logMissedDosesValue = (UILabel*)[logMissedDosesCell viewWithTag:2];
            ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*) d.reminder;
            if (scheduledReminder && scheduledReminder.logMissedDoses)
                logMissedDosesValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDosesOn", @"Dosecast", [DosecastUtil getResourceBundle], @"On", @"The on value in the Log Missed Doses cell of the Drug Edit view"]);
            else
                logMissedDosesValue.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDosesOff", @"Dosecast", [DosecastUtil getResourceBundle], @"Off", @"The off value in the Log Missed Doses cell of the Drug Edit view"]);
            logMissedDosesValue.textColor = normalTextColor;

            return logMissedDosesCell;
        }
        else
            return nil;
	}
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

	DrugViewControllerSections section = (DrugViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (section == DrugViewControllerSectionsDoctorPharmacy)
    {
        Drug* d = [[DataModel getInstance] findDrugWithId:drugId];

        DrugViewControllerDoctorPharmacyRows row = (DrugViewControllerDoctorPharmacyRows)[[doctorPharmacyRows objectAtIndex:indexPath.row] intValue];

        if (row == DrugViewControllerDoctorPharmacyRowsDoctor)
        {
            if ([DataModel getInstance].contactsHelper.addressBook != NULL)
            {
                ABRecordID doctorRecord = d.doctorContact.recordID;
                            
                ABRecordRef person = ABAddressBookGetPersonWithRecordID([DataModel getInstance].contactsHelper.addressBook, doctorRecord);
                ABPersonViewController *viewController = [[ABPersonViewController alloc] init];
                viewController.personViewDelegate = self;
                viewController.displayedPerson = person;
                viewController.allowsEditing = NO;
                NSArray *displayedProperties = [NSArray arrayWithObjects:
                                                [NSNumber numberWithInt:kABPersonFirstNameProperty],
                                                [NSNumber numberWithInt:kABPersonLastNameProperty],
                                                [NSNumber numberWithInt:kABPersonMiddleNameProperty],
                                                [NSNumber numberWithInt:kABPersonPrefixProperty],
                                                [NSNumber numberWithInt:kABPersonSuffixProperty],
                                                [NSNumber numberWithInt:kABPersonOrganizationProperty],
                                                [NSNumber numberWithInt:kABPersonJobTitleProperty],
                                                [NSNumber numberWithInt:kABPersonDepartmentProperty],
                                                [NSNumber numberWithInt:kABPersonEmailProperty],
                                                [NSNumber numberWithInt:kABPersonAddressProperty],
                                                [NSNumber numberWithInt:kABPersonPhoneProperty],
                                                [NSNumber numberWithInt:kABPersonURLProperty],
                                                [NSNumber numberWithInt:kABPersonNoteProperty], nil];
                viewController.displayedProperties = displayedProperties;

                // Set Back button title
                NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
                UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
                backButton.style = UIBarButtonItemStylePlain;
                if (!backButton.image)
                    backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
                self.navigationItem.backBarButtonItem = backButton;
                
                viewController.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDoctor", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor", @"The Doctor label in the Drug Edit view"]);
                
                viewController.edgesForExtendedLayout = UIRectEdgeNone;
                viewController.automaticallyAdjustsScrollViewInsets = NO;

                [self.navigationController pushViewController:viewController animated:YES];
                [viewController.navigationController setToolbarHidden:YES animated:YES];
            }
        }
        else if (row == DrugViewControllerDoctorPharmacyRowsPharmacy)
        {
            if ([DataModel getInstance].contactsHelper.addressBook != NULL)
            {
                ABRecordID pharmacyRecord = d.pharmacyContact.recordID;
                
                ABRecordRef person = ABAddressBookGetPersonWithRecordID([DataModel getInstance].contactsHelper.addressBook, pharmacyRecord);
                ABPersonViewController *viewController = [[ABPersonViewController alloc] init];
                viewController.personViewDelegate = self;
                viewController.displayedPerson = person;
                viewController.allowsEditing = NO;
                NSArray *displayedProperties = [NSArray arrayWithObjects:
                                                [NSNumber numberWithInt:kABPersonOrganizationProperty],
                                                [NSNumber numberWithInt:kABPersonDepartmentProperty],
                                                [NSNumber numberWithInt:kABPersonEmailProperty],
                                                [NSNumber numberWithInt:kABPersonAddressProperty],
                                                [NSNumber numberWithInt:kABPersonPhoneProperty],
                                                [NSNumber numberWithInt:kABPersonURLProperty],
                                                [NSNumber numberWithInt:kABPersonNoteProperty], nil];
                viewController.displayedProperties = displayedProperties;

                // Set Back button title
                NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
                UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
                backButton.style = UIBarButtonItemStylePlain;
                if (!backButton.image)
                    backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
                self.navigationItem.backBarButtonItem = backButton;
                
                viewController.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Pharmacy", @"The Pharmacy label in the Drug Edit view"]);
                
                viewController.edgesForExtendedLayout = UIRectEdgeNone;
                viewController.automaticallyAdjustsScrollViewInsets = NO;

                [self.navigationController pushViewController:viewController animated:YES];
                [viewController.navigationController setToolbarHidden:YES animated:YES];                
            }
        }
    }    
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
	DataModel* dataModel = [DataModel getInstance];
	Drug* d = [dataModel findDrugWithId:drugId];

    DrugViewControllerSections section = (DrugViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (section == DrugViewControllerSectionsReminder)
	{
		if ([d.reminder isKindOfClass:[AsNeededDrugReminder class]])
        {
            int baseHeight = 130;
            BOOL showDosesTaken = (((AsNeededDrugReminder*)d.reminder).limitType != AsNeededDrugReminderDrugLimitTypeNever);
            if (showDosesTaken)
                baseHeight += DOSE_LIMIT_LABEL_HEIGHT;
			return baseHeight;
        }
		else if ([d.reminder isKindOfClass:[IntervalDrugReminder class]])
        {
            int baseHeight = 130;
            int numMinutes = ((IntervalDrugReminder*)d.reminder).interval/60;			
            BOOL showDoseLimit = (numMinutes < MIN_PER_DAY);
            if (showDoseLimit)
            {
                baseHeight += DOSE_LIMIT_LABEL_HEIGHT;
                BOOL showDosesTaken = (((IntervalDrugReminder*)d.reminder).limitType != IntervalDrugReminderDrugLimitTypeNever);
                if (showDosesTaken)
                    baseHeight += DOSE_LIMIT_LABEL_HEIGHT;
            }
            return baseHeight;
        }
		else // ScheduledDrugReminder
		{
            int totalHeight = 319;
			ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*) d.reminder;

            int numWeekdays = 0;
            // The cell height may vary depending on the number of weekdays
            if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly &&
                scheduledReminder.weekdays)
            {
                numWeekdays = (int)[scheduledReminder.weekdays count];
            }
            int numWeekdaysDisplayed = (((float)numWeekdays) / 2.0) + 0.5;
            totalHeight -= REMINDER_TIME_LABEL_HEIGHT * (4 - numWeekdaysDisplayed);

			int numLabelsDisplayed = 1; // Always display the first label ('None' if no times defined)
			if ([scheduledReminder.reminderTimes count] > 0)
				numLabelsDisplayed = (((float)[scheduledReminder.reminderTimes count]) / 2.0) + 0.5;
			
			int heightToSubtract = (MAX_REMINDER_SCHEDULE_TIME_LABELS-numLabelsDisplayed)*REMINDER_TIME_LABEL_HEIGHT;
			if (numLabelsDisplayed == 1)
				heightToSubtract -= 9; // The Time of Day header is taller than the reminder time label, so leave extra room if there aren't any more times
			totalHeight -= heightToSubtract;
            return totalHeight;
		}
	}
	else if (section == DrugViewControllerSectionsRemainingRefill)
	{
        float remainingQuantity = 0.0f;
        [d.dosage getValueForRemainingQuantity:&remainingQuantity];

        BOOL showRefillQuantityValue = [d.dosage isValidValueForRefillQuantity];
        BOOL showRefillsRemainingValue = ([dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining] && ([d.dosage isValidValueForRefillQuantity] || [d.dosage getRefillsRemaining] > 0));
        BOOL showRefillAlertOptions = ([d.reminder getRefillAlertOptionNum] >= 0);
        BOOL showQuantityRemainingValue = ([d.reminder getRefillAlertOptionNum] >= 0 || remainingQuantity > epsilon);
		
        int totalHeight = 5;
        if (showQuantityRemainingValue)
            totalHeight += REMAINING_REFILL_LABEL_HEIGHT;
        if (showRefillQuantityValue)
            totalHeight += REMAINING_REFILL_LABEL_HEIGHT;
        if (showRefillsRemainingValue)
            totalHeight += REMAINING_REFILL_LABEL_HEIGHT;
        if (showRefillAlertOptions)
            totalHeight += REMAINING_REFILL_LABEL_HEIGHT;
        
        return totalHeight;
	}
    else if (section == DrugViewControllerSectionsExpiration)
    {
        int totalHeight = 41;
        if ([d.reminder getExpirationAlertOptionNum] >= 0)
            totalHeight += REMAINING_REFILL_LABEL_HEIGHT;
        return totalHeight;
    }
    else if (section == DrugViewControllerSectionsNotes)
        return 157;
    else if (section == DrugViewControllerSectionsDrugImage)
        return 81;
    else if (section == DrugViewControllerSectionsDrugName)
        return (int)ceilf([self getHeightForCellLabel:nameCell tag:2 withString:d.name]);
    else if (section == DrugViewControllerSectionsDosage)
        return (int)ceilf([self getHeightForCellLabel:dosageCell tag:2 withString:[d.dosage getDescriptionForDrugDose:nil]]);
    else if (section == DrugViewControllerSectionsDirections)
        return (int)ceilf([self getHeightForCellLabel:directionsCell tag:2 withString:d.directions]);
	else
		return 40;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
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

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0 && (isNewManagedDrug || isExistingManagedDrugRequiringNotification))
    {
        notificationMessage.backgroundColor = [UIColor clearColor];

        UIView* container = (UIView*)[notificationMessage viewWithTag:1];
        container.backgroundColor = [DosecastUtil getDrugViewManagedDrugNotificationBackgroundColor];
        
        UILabel* title = (UILabel*)[container viewWithTag:2];
        if (isNewManagedDrug)
            title.text = NSLocalizedStringWithDefaultValue(@"ViewDrugNewManagedDrugNotificationTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"New Drug", @"The notification title text to display in the Drug View view for new managed drugs"]);
        else if (isExistingManagedDrugRequiringNotification)
            title.text = NSLocalizedStringWithDefaultValue(@"ViewDrugExistingManagedDrugNotificationTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Changed Drug", @"The notification title text to display in the Drug View view for new managed drugs"]);
        title.textColor = [DosecastUtil getDrugViewManagedDrugNotificationColor];
        
        UILabel* message = (UILabel*)[container viewWithTag:3];
        if (isNewManagedDrug)
            message.text = NSLocalizedStringWithDefaultValue(@"ViewDrugNewManagedDrugNotification", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug was newly prescribed by your doctor. Please review it and tap Edit to set the reminder schedule.", @"The notification text to display in the Drug View view for new managed drugs"]);
        else if (isExistingManagedDrugRequiringNotification)
            message.text = NSLocalizedStringWithDefaultValue(@"ViewDrugExistingManagedDrugNotification", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug was changed by your doctor. Please review it and, if necessary, tap Edit to change the reminder schedule.", @"The notification text to display in the Drug View view for existing managed drugs"]);
        message.textColor = [DosecastUtil getDrugViewManagedDrugNotificationColor];
        
        return notificationMessage;
    }
    else
        return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0 && (isNewManagedDrug || isExistingManagedDrugRequiringNotification))
        return 96;
    else
        return 0;
}

- (void)dealloc {
    
    // Remove our notification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HistoryManagerHistoryEditedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ContactsHelperAddressBookAccessGranted object:nil];
}


@end
