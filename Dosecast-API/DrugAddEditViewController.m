//
//  DrugAddEditViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DrugAddEditViewController.h"

#import "ReminderAddEditViewController.h"
#import "DataModel.h"
#import "Drug.h"
#import "LocalNotificationManager.h"
#import "TextEntryViewController.h"
#import "HistoryManager.h"
#import "DosecastUtil.h"
#import "NumericPickerViewController.h"
#import "ScheduledDrugReminder.h"
#import "PicklistViewController.h"
#import "DrugDosageManager.h"
#import "AccountViewController.h"
#import "AddressBookContact.h"
#import "AddressBook/ABPerson.h"
#import "CustomNameIDList.h"
#import "CustomDrugDosage.h"
#import "PicklistEditedItem.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "DrugDosageUnitManager.h"
#import "DrugNameViewController.h"
#import "DrugChooseImageViewController.h"
#import "UIImage+Resize.h"
#import "DrugImage.h"
#import "DrugImageManager.h"
#import "Medication.h"
#import "MedicationConstants.h"
#import "DatabaseDrugDosage.h"
#import "DrugImagePickerController.h"
#import "TSQMonthPickerViewController.h"
#import "GlobalSettings.h"
#import "ContactsHelper.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

#define DRUG_IMAGE_CROP_SIZE CGSizeMake( 150.0f, 150.0f )

// The different UI sections & rows
typedef enum {
	DrugAddEditViewControllerSectionsDrugName        = 0,
	DrugAddEditViewControllerSectionsDrugType        = 1,
    DrugAddEditViewControllerSectionsDrugImage       = 2,
    DrugAddEditViewControllerSectionsDosage          = 3,
    DrugAddEditViewControllerSectionsPerson          = 4,
    DrugAddEditViewControllerSectionsDirections      = 5,
    DrugAddEditViewControllerSectionsReminder        = 6,
    DrugAddEditViewControllerSectionsRemainingRefill = 7,
    DrugAddEditViewControllerSectionsExpiration      = 8,
    DrugAddEditViewControllerSectionsDoctorPharmacy  = 9,
    DrugAddEditViewControllerSectionsNotes           = 10,
    DrugAddEditViewControllerSectionsReminderSwitch  = 11,
    DrugAddEditViewControllerSectionsLogMissedDoses  = 12,
    DrugAddEditViewControllerSectionsArchive         = 13,
    DrugAddEditViewControllerSectionsDelete          = 14
} DrugAddEditViewControllerSections;

typedef enum {
	DrugAddEditViewControllerRemainingRefillRowsQuantityRemaining = 0,
	DrugAddEditViewControllerRemainingRefillRowsRefillQuantity    = 1,
    DrugAddEditViewControllerRemainingRefillRowsRefillsRemaining  = 2,
    DrugAddEditViewControllerRemainingRefillRowsRefillAlert       = 3
} DrugAddEditViewControllerRemainingRefillRows;

typedef enum {
	DrugAddEditViewControllerDoctorPharmacyRowsDoctor          = 0,
	DrugAddEditViewControllerDoctorPharmacyRowsPharmacy        = 1,
    DrugAddEditViewControllerDoctorPharmacyRowsPrescriptionNum = 2
} DrugAddEditViewControllerDoctorPharmacyRows;

static const int REMINDER_TIME_LABEL_HEIGHT = 21;
static const int FREQUENCY_WEEKDAY_LABEL_MARGIN = 9;
static const int HEADER_LABEL_HEIGHT = 43;
static const int MAX_REMINDER_SCHEDULE_TIMES = 8;
static const CGFloat LABEL_BASE_HEIGHT = 19.0f;
static const CGFloat CELL_MIN_HEIGHT = 44.0f;

static double MIN_PER_DAY = 60*24;

static NSString *PersonPicklistId = @"person";
static NSString *DrugDosageTypePicklistId = @"drugDosageType";
static NSString *RefillAlertOptionsPicklistId = @"refillAlertOptions";
static NSString *ExpirationAlertOptionsPicklistId = @"expirationAlertOptions";
static NSString *RemainingQuantityId = @"remainingQuantity";
static NSString *RefillQuantityId = @"refillQuantity";
static NSString *RefillsRemainingId = @"refillsRemaining";
static NSString *DoctorAddressBookContactName = @"doctor";
static NSString *PharmacyAddressBookContactName = @"pharmacy";
static NSString *TextEntryDosageId = @"dosage";
static NSString *TextEntryDirectionsId = @"directions";
static NSString *TextEntryPrescriptionNumId = @"prescriptionNum";
static NSString *TextEntryNotesId = @"notes";

static NSString *DatabaseAmountQuantityName = @"databaseAmount";
static NSString *DatabaseStrengthQuantityName = @"databaseStrength";

static float epsilon = 0.0001;

@implementation DrugAddEditViewController

@synthesize tableView;
@synthesize drugPlaceholderImageView;
@synthesize drugNameCell;
@synthesize drugTypeCell;
@synthesize drugImageCell;
@synthesize doseInputCell;
@synthesize doseInputTextCell;
@synthesize directionsCell;
@synthesize remainingCell;
@synthesize refillCell;
@synthesize refillsRemainingCell;
@synthesize refillAlertCell;
@synthesize takeDrugScheduledCell;
@synthesize takeDrugIntervalCell;
@synthesize takeDrugAsNeededCell;
@synthesize doctorCell;
@synthesize pharmacyCell;
@synthesize prescriptionNumCell;
@synthesize remindersCell;
@synthesize secondaryRemindersCell;
@synthesize logMissedDosesCell;
@synthesize notesCell;
@synthesize deleteButtonCell;
@synthesize personCell;
@synthesize archiveButtonCell;
@synthesize unarchiveButtonCell;
@synthesize expirationAlertCell;
@synthesize expirationDateCell;

@synthesize sharedPopover = _sharedPopover;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil mode:DrugAddEditViewControllerModeAddDrug drugId:nil treatmentStartDate:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
				 mode:(DrugAddEditViewControllerMode)mode
			   drugId:(NSString*)Id
   treatmentStartDate:(NSDate*)treatmentStartDate
			 delegate:(NSObject<DrugAddEditViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{
        DataModel* dataModel = [DataModel getInstance];

		drugId = Id;
		controllerDelegate = del;
		controllerMode = mode;
        pickingDoctor = YES;
        
		if (controllerMode == DrugAddEditViewControllerModeAddDrug)
			self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugAddTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"New Drug", @"The title of the Drug Add view"]);
		else // DrugAddEditViewControllerModeEditDrug
			self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Edit Drug", @"The title of the Drug Edit view"]);
		
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		// Populate defaults for all drug data
		if (drugId == nil)
		{
			DrugDosageManager* dosageManager = [DrugDosageManager getInstance];
			dosage = [dosageManager createDrugDosageWithTypeName:dosageManager.defaultTypeName];
			reminder = [[ScheduledDrugReminder alloc] init];
            if (treatmentStartDate)
                reminder.treatmentStartDate = treatmentStartDate;
			drugName = [[NSMutableString alloc] initWithString:@""];
            drugImageGUID = [[NSMutableString alloc] initWithString:@""];
            tempDrugImageGUID = [[NSMutableString alloc] initWithString:@""];
			directions = [[NSMutableString alloc] initWithString:@""];
            prescriptionNum = [[NSMutableString alloc] initWithString:@""];
            notes = [[NSMutableString alloc] initWithString:@""];
            personId = [[NSMutableString alloc] initWithString:@""];
            doctorContact = [[AddressBookContact alloc] init:DoctorAddressBookContactName contactType:AddressBookContactTypePerson];
            pharmacyContact = [[AddressBookContact alloc] init:PharmacyAddressBookContactName contactType:AddressBookContactTypeOrganization];
		}
		else
		{
			Drug* d = [dataModel findDrugWithId:drugId];
			dosage = [d.dosage mutableCopy];
			reminder = [d.reminder mutableCopy];
            if (d.name)
                drugName = [[NSMutableString alloc] initWithString:d.name];
            else
                drugName = [[NSMutableString alloc] initWithString:@""];
            drugImageGUID = ( d.drugImageGUID.length > 0 ) ? [[NSMutableString alloc] initWithString:d.drugImageGUID] : [[NSMutableString alloc] initWithString:@""];
            tempDrugImageGUID = [[NSMutableString alloc] initWithString:@""];
            personId = [[NSMutableString alloc] initWithString:d.personId];
			directions = [[NSMutableString alloc] initWithString:d.directions];
            doctorContact = [d.doctorContact mutableCopy];
            pharmacyContact = [d.pharmacyContact mutableCopy];
            prescriptionNum = [[NSMutableString alloc] initWithString:d.prescriptionNum];
            notes = [[NSMutableString alloc] initWithString:d.notes];
		}
        
        drugImage = nil;
        shouldClearDrugImage = NO;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        tableViewSections = [[NSMutableArray alloc] init];
        remainingRefillRows = [[NSMutableArray alloc] init];
        doctorPharmacyRows = [[NSMutableArray alloc] init];
        
        preferencesDict = [[NSMutableDictionary alloc] init];      
        deletedItems = [[NSMutableArray alloc] init];
        renamedItems = [[NSMutableArray alloc] init];
        createdItems = [[NSMutableArray alloc] init];
        chooseImageViewController = nil;
        exampleDoseInputTextCell = nil;
        self.hidesBottomBarWhenPushed = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDrugImageRefresh:)
                                                     name:DrugImageAvailableNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAddressBookAccessGranted:)
                                                     name:ContactsHelperAddressBookAccessGranted
                                                   object:nil];
    }
    return self;
}

- (void)handleAddressBookAccessGranted:(NSNotification *)notification
{
    [tableView reloadData];
}

- (void)handleNotesTap:(UIGestureRecognizer *)gestureRecognizer
{
    TextEntryViewController* textController = [[TextEntryViewController alloc]
                                               initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                               bundle:[DosecastUtil getResourceBundle]
                                               viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditNotes", @"Dosecast", [DosecastUtil getResourceBundle], @"Notes", @"The Notes label in the Drug Edit view"])
                                               numTextFields:1
                                               multiline:YES
                                               initialValues:[NSArray arrayWithObject:[NSString stringWithString:notes]]
                                               placeholderStrings:nil
                                               capitalizationType:UITextAutocapitalizationTypeSentences
                                               correctionType:UITextAutocorrectionTypeYes
                                               keyboardType:UIKeyboardTypeDefault
                                               secureTextEntry:NO
                                               identifier:TextEntryNotesId
                                               subIdentifier:nil
                                               delegate:self];
    [self.navigationController pushViewController:textController animated:YES];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
    
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Setup callback for remindersEnabled switch
	UISwitch* remindersEnabledSwitch = (UISwitch *)[remindersCell viewWithTag:2];
	[remindersEnabledSwitch addTarget:self action:@selector(handleRemindersEnabledSwitch:) forControlEvents:UIControlEventValueChanged];

    // Setup callback for secondaryRemindersEnabled switch
	UISwitch* secondaryRemindersEnabledSwitch = (UISwitch *)[secondaryRemindersCell viewWithTag:2];
	[secondaryRemindersEnabledSwitch addTarget:self action:@selector(handleSecondaryRemindersEnabledSwitch:) forControlEvents:UIControlEventValueChanged];

    // Setup callback for logMissedDosesEnabled switch
	UISwitch* logMissedDosesEnabled = (UISwitch *)[logMissedDosesCell viewWithTag:2];
	[logMissedDosesEnabled addTarget:self action:@selector(handleLogMissedDosesEnabledSwitch:) forControlEvents:UIControlEventValueChanged];	    
    
	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	
	
    // Set callback for tap on the notes
    UITextView* textView = (UITextView*)[notesCell viewWithTag:2];
    UITapGestureRecognizer *notesTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleNotesTap:)];
    [textView addGestureRecognizer:notesTap];
    
    // Set glossy button backgrounds.
    
    [self updateClientSpecificButtonImages];
    
    // Fetch initial drug image.
            
    DrugImageManager *manager = [DrugImageManager sharedManager];

    if ( drugImageGUID.length > 0 )
    {
        BOOL imageExists = [manager doesImageExistForImageGUID:drugImageGUID];

        if ( imageExists )
        {
            drugImage = [manager imageForImageGUID:drugImageGUID];
        }
    }
    
    [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugAddEditDoseInputTextTableViewCell" owner:self options:nil];
    exampleDoseInputTextCell = doseInputTextCell;
    doseInputTextCell = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    
    // Scroll the text view to the top
    UITextView* textView = (UITextView*)[notesCell viewWithTag:2];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];
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
    drugNameCell.frame = CGRectMake(drugNameCell.frame.origin.x, drugNameCell.frame.origin.y, screenWidth, drugNameCell.frame.size.height);
    exampleDoseInputTextCell.frame = CGRectMake(exampleDoseInputTextCell.frame.origin.x, exampleDoseInputTextCell.frame.origin.y, screenWidth, exampleDoseInputTextCell.frame.size.height);
    directionsCell.frame = CGRectMake(directionsCell.frame.origin.x, directionsCell.frame.origin.y, screenWidth, directionsCell.frame.size.height);
    [drugNameCell layoutIfNeeded];
    [exampleDoseInputTextCell layoutIfNeeded];
    [directionsCell layoutIfNeeded];
}

- (void)handleDrugImageRefresh:(NSNotification *)notification
{
    [self.tableView reloadData];
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
    
    [self.tableView reloadData];
    
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

- (void)updateClientSpecificButtonImages
{
    UIButton *addImageButton = (UIButton *)[self.drugImageCell viewWithTag:4];
    UIButton *editImageButton = (UIButton *)[self.drugImageCell viewWithTag:5];
    UIButton *clearImageButton = (UIButton *)[self.drugImageCell viewWithTag:6];

    if ( addImageButton.currentImage == nil )
    {
        [addImageButton setTitle:NSLocalizedStringWithDefaultValue( @"AddImageButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Drug Image", @"The default button title for the add image button in the add/edit view" ) forState:UIControlStateNormal];
        [DosecastUtil setBackgroundColorForButton:addImageButton color:[DosecastUtil getNavigationBarColor]];
    }
    
    if ( editImageButton.currentImage == nil )
    {
        [editImageButton setTitle:NSLocalizedStringWithDefaultValue( @"EditImageButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Edit", @"The default button title for the edit image button in the add/edit view" ) forState:UIControlStateNormal];
        [DosecastUtil setBackgroundColorForButton:editImageButton color:[DosecastUtil getNavigationBarColor]];
    }
    
    if ( clearImageButton.currentImage == nil )
    {
        [clearImageButton setTitle:NSLocalizedStringWithDefaultValue( @"ClearImageButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Clear", @"The default button title for the clear image button in the add/edit view" ) forState:UIControlStateNormal];
        [DosecastUtil setBackgroundColorForButton:clearImageButton color:[DosecastUtil getNavigationBarColor]];
    }
}

- (void)handleArchivedButtonTap
{
    reminder.archived = !reminder.archived;

    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerEditingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Editing drug", @"The message appearing in the spinner view when editing a drug"])];
    
    [[LocalNotificationManager getInstance] editPill:drugId
                                            drugName:drugName
                                           imageGUID:[self getImageGUIDForServerProxyCall]
                                            personId:personId
                                          directions:directions
                                       doctorContact:doctorContact
                                     pharmacyContact:pharmacyContact
                                     prescriptionNum:prescriptionNum
                                        drugReminder:reminder
                                          drugDosage:dosage
                                               notes:notes
                                undoHistoryEventGUID:(drugId ? ((Drug*)[[DataModel getInstance] findDrugWithId:drugId]).undoHistoryEventGUID : nil)
                                        updateServer:YES
                                           respondTo:self
                                               async:YES];
}

- (void)handleRemindersEnabledSwitch:(id)sender
{
	reminder.remindersEnabled = !reminder.remindersEnabled;
    
    int remindersSwitchSection = -1;
    int numSections = (int)[tableViewSections count];
    for (int i =0; i < numSections; i++)
    {
        DrugAddEditViewControllerSections section = (DrugAddEditViewControllerSections)[[tableViewSections objectAtIndex:i] intValue];
        if (section == DrugAddEditViewControllerSectionsReminderSwitch)
            remindersSwitchSection = i;
    }
    if (reminder.remindersEnabled)
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:remindersSwitchSection]] withRowAnimation:UITableViewRowAnimationRight];
    else
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:remindersSwitchSection]] withRowAnimation:UITableViewRowAnimationLeft];
}

- (void)handleSecondaryRemindersEnabledSwitch:(id)sender
{
	reminder.secondaryRemindersEnabled = !reminder.secondaryRemindersEnabled;
}

- (void)handleLogMissedDosesEnabledSwitch:(id)sender
{
    if ([reminder isKindOfClass:[ScheduledDrugReminder class]])
    {
        ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)reminder;
        scheduledReminder.logMissedDoses = !scheduledReminder.logMissedDoses;    
    }	
}

// Callback for entry of the drug name. Returns whether the new name is accepted.
- (void)handleDrugNameEntryDone:(NSString*)name
{
    // ********* If editing the name of a database drug, and it differs enough, may want to clear the NDC
    
    if ([name length] == 0)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoNameTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name Required", @"The title of the alert appearing in the Drug Add view when no name has been entered and the user clicks Done"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoNameMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a drug name.", @"The message in the alert appearing in the Drug Add view when no name has been entered and the user clicks Done"])];
        [alert showInViewController:self];
    }
    else
    {
        [self.navigationController popViewControllerAnimated:YES];

        [drugName setString:name];
    
		[tableView reloadData];
    }
}

// Populates a dosage quantity using a database value
- (void) setDosageQuantityFromDatabaseValue:(NSString*)valueStr quantityName:(NSString*)quantityName
{
    if (valueStr && [valueStr length] > 0)
    {        
        // Find the position of the first non-digit
        int nonDigitPos = -1;
        int numChars = (int)[valueStr length];
        for (int i = 0; i < numChars && nonDigitPos < 0; i++)
        {
            unichar u = [valueStr characterAtIndex:i];
            if (!isdigit(u) && u != '.')
                nonDigitPos = i;
        }
        
        // Extract the value and the unit from the string
        NSString* value = nil;
        NSString* unit = nil;
        if (nonDigitPos < 0)
            value = valueStr;
        else if (nonDigitPos == 0)
            unit = valueStr;
        else
        {
            value = [valueStr substringToIndex:nonDigitPos];
            unit = [valueStr substringFromIndex:nonDigitPos];
        }
        
        // Save these to the dosage object
        DatabaseDrugDosage* databaseDosage = (DatabaseDrugDosage*)dosage;
        if (value)
            [databaseDosage setValue:[value floatValue] forDoseQuantity:quantityName];
        if (unit)
            [databaseDosage setUnit:unit forDoseQuantity:quantityName];        
    }
}

// Callback for entry of the drug from a database. Returns whether the new name is accepted.
- (void)handleDrugDatabaseEntryDone:(Medication*)drug resultMatch:(MedicationResultMatch)resultMatch
{
    if (resultMatch == MedicationResultMatchBrandName)
        [drugName setString:drug.brandName];
    else
        [drugName setString:drug.genericName];
    
    dosage = [[DatabaseDrugDosage alloc] init:drug.medForm
                                  medFormType:drug.medFormType
                                      medType:drug.medType
                                          ndc:drug.ndc
                                       amount:0.0f
                                   amountUnit:nil
                                     strength:-1.0f
                                 strengthUnit:nil
                                     location:nil
                                        route:drug.route
                                    remaining:0.0f
                                remainingUnit:nil
                                       refill:0.0f
                                   refillUnit:nil
                             refillsRemaining:0.0f];

    [self setDosageQuantityFromDatabaseValue:drug.unit quantityName:DatabaseAmountQuantityName];
    [self setDosageQuantityFromDatabaseValue:drug.strength quantityName:DatabaseStrengthQuantityName];

    [reminder setRefillAlertOptionNum:-1]; // Clear the refill alert options

    [self.navigationController popToViewController:self animated:YES];
    [tableView reloadData];
}

// Callback for text entry. Returns whether the new values are accepted.
- (BOOL)handleTextEntryDone:(NSArray*)textValues
                 identifier:(NSString*)Id // a unique identifier for the current text
              subIdentifier:(NSString*)subId // a unique identifier for the current text
{
	BOOL success = YES;
    NSString* newValue = [textValues objectAtIndex:0];
	if ([Id caseInsensitiveCompare:TextEntryDirectionsId] == NSOrderedSame) // directions
		[directions setString:newValue];
    else if ([Id caseInsensitiveCompare:TextEntryPrescriptionNumId] == NSOrderedSame) // prescription num
        [prescriptionNum setString:newValue];
    else if ([Id caseInsensitiveCompare:TextEntryDosageId] == NSOrderedSame) // dosage text value
    {        
        if ([newValue length] == 0)
        {
            success = NO;
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoDosageDescriptionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage Description Required", @"The title of the alert appearing in the Drug Add view when no dosage description has been entered and the user clicks Done"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoDosageDescriptionMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a description of the dosage.", @"The message in the alert appearing in the Drug Add view when no dosage description has been entered and the user clicks Done"])];
			[alert showInViewController:self];
        }
        if (success)
            [dosage setValue:newValue forDoseTextValue:subId];
    }
    else if ([Id caseInsensitiveCompare:TextEntryNotesId] == NSOrderedSame) // notes value
        [notes setString:newValue];
    
	if (success)
		[tableView reloadData];
	return success;
}

- (void)createPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
        // Drug image has changed.
        
        if ( tempDrugImageGUID.length > 0 )
        {
            [[DrugImageManager sharedManager]  uploadImageWithImageGUID:tempDrugImageGUID];
            if (drugImageGUID.length > 0)
                [[DrugImageManager sharedManager]  removeImageForImageGUID:drugImageGUID shouldRemoveServerImage:YES];
        }
        
        // Handle clearing an image.
        
        if (shouldClearDrugImage && drugImageGUID.length > 0)
        {
            [[DrugImageManager sharedManager]  removeImageForImageGUID:drugImageGUID shouldRemoveServerImage:YES];
        }
        
        
		[self.navigationController popViewControllerAnimated:YES];
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Add Drug", @"The message in the alert appearing in the Drug Add view when adding a drug fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}
}

- (void)editPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
        
        // Drug image has changed.
        
        if ( tempDrugImageGUID.length > 0 )
        {
            [[DrugImageManager sharedManager]  uploadImageWithImageGUID:tempDrugImageGUID];
            if (drugImageGUID.length > 0)
                [[DrugImageManager sharedManager]  removeImageForImageGUID:drugImageGUID shouldRemoveServerImage:YES];
        }
        
        // Handle clearing an image.
        
        if (shouldClearDrugImage && drugImageGUID.length > 0)
        {
            [[DrugImageManager sharedManager]  removeImageForImageGUID:drugImageGUID shouldRemoveServerImage:YES];
        }
        
        if ([controllerDelegate respondsToSelector:@selector(handleEditDrugComplete)])
		{
			[controllerDelegate handleEditDrugComplete];
		}
        
		[self.navigationController popViewControllerAnimated:YES];
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
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
		if ([controllerDelegate respondsToSelector:@selector(handleDrugDelete)])
		{
			[controllerDelegate handleDrugDelete];
		}				
        
		[self.navigationController popToRootViewControllerAnimated:YES];		
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditDeleteFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Delete Drug", @"The message in the alert appearing in the Drug Edit view when deleting a drug fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}	
}

- (void)setPreferencesLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{	
	if (result)
	{
        [preferencesDict removeAllObjects];
                
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

        // Find the picklist view controller in the view stack
        UIViewController* picklistController = nil;
        NSArray* viewControllers = self.navigationController.viewControllers;
        int numViewControllers = (int)[viewControllers count];
        for (int i = 0; i < (numViewControllers-1) && !picklistController; i++)
        {
            UIViewController* thisController = (UIViewController*)[viewControllers objectAtIndex:i];
            if ([thisController isKindOfClass:[DrugAddEditViewController class]])
            {
                UIViewController* topController = (UIViewController*)[viewControllers objectAtIndex:i+1];
                if ([topController isKindOfClass:[PicklistViewController class]])
                    picklistController = topController;
            }
        }
        
        // Commit the edits in the picklist view controller now
        if (picklistController)
        {
            PicklistViewController* controller = (PicklistViewController*)picklistController;
            [controller commitEdits:deletedItems renamedItems:renamedItems createdItems:createdItems];
        }
        [deletedItems removeAllObjects];
        [renamedItems removeAllObjects];
        [createdItems removeAllObjects];
	}
	else
	{
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugEditSetPreferencesFailedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Save Changes", @"The message in the alert appearing in the Drug Edit view when setting preferences fails"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}	
}

- (NSString*) getImageGUIDForServerProxyCall
{
    if (shouldClearDrugImage)
        return @"";
    
    if (tempDrugImageGUID.length > 0)
        return tempDrugImageGUID;
    else
        return drugImageGUID;
}

- (IBAction)handleDone:(id)sender
{
	if ([drugName length] == 0)
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoNameTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name Required", @"The title of the alert appearing in the Drug Add view when no name has been entered and the user clicks Done"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoNameMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a drug name.", @"The message in the alert appearing in the Drug Add view when no name has been entered and the user clicks Done"])];
		[alert showInViewController:self];
	}
	else
	{
		if (controllerMode == DrugAddEditViewControllerModeAddDrug)
		{
			[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerAddingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Adding new drug", @"The message appearing in the spinner view when adding a new drug"])];
			
			[[LocalNotificationManager getInstance] createPill:nil
                           drugName:drugName
                          imageGUID:[self getImageGUIDForServerProxyCall]
                           personId:personId
                         directions:directions
                      doctorContact:doctorContact
                    pharmacyContact:pharmacyContact
                    prescriptionNum:prescriptionNum
                       drugReminder:reminder
                         drugDosage:dosage
                              notes:notes
                          respondTo:self
                              async:YES];
		}
		else // DrugAddEditViewControllerModeEditDrug
		{
			[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerEditingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Editing drug", @"The message appearing in the spinner view when editing a drug"])];
			
			[[LocalNotificationManager getInstance] editPill:drugId
                         drugName:drugName
                        imageGUID:[self getImageGUIDForServerProxyCall]
                         personId:personId
					   directions:directions
                    doctorContact:doctorContact
                  pharmacyContact:pharmacyContact
                  prescriptionNum:prescriptionNum
					 drugReminder:reminder
					   drugDosage:dosage
                            notes:notes
             undoHistoryEventGUID:(drugId ? ((Drug*)[[DataModel getInstance] findDrugWithId:drugId]).undoHistoryEventGUID : nil)
                     updateServer:YES
						respondTo:self
                           async:YES];
        }
    }
}

- (IBAction)handleCancel:(id)sender
{
    if ([controllerDelegate respondsToSelector:@selector(handleEditDrugCancel)])
    {
        [controllerDelegate handleEditDrugCancel];
        
        if (tempDrugImageGUID.length > 0)
            [[DrugImageManager sharedManager] removeImageForImageGUID:tempDrugImageGUID shouldRemoveServerImage:NO];
    }				

	[self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)handleArchive:(id)sender
{
    NSString* buttonTitle = nil;
    if (reminder.archived)
        buttonTitle = NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonUnarchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Unarchive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"]);
    else
        buttonTitle = NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonArchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Archive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"]);
    
    DosecastAlertController* confirmArchiveController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [confirmArchiveController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [confirmArchiveController addAction:
     [DosecastAlertAction actionWithTitle:buttonTitle
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [self handleArchivedButtonTap];
                                  }]];
    
    [confirmArchiveController showInViewController:self sourceView:(UIButton*)sender];
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

- (IBAction)handleDelete:(id)sender
{
    DosecastAlertController* confirmDeleteController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [confirmDeleteController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [confirmDeleteController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"])
                                    style:DosecastAlertActionStyleDestructive
                                  handler:^(DosecastAlertAction *action) {
                                      DataModel* dataModel = [DataModel getInstance];
                                      
                                      // If any history exists (and it's a premium edition), ask the user what they want to do with it
                                      if ([[HistoryManager getInstance] eventsExistForDrugId:drugId] && dataModel.globalSettings.accountType != AccountTypeDemo)
                                      {
                                          if (reminder.archived)
                                          {
                                              DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmArchivedDrugDeleteTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The title on the confirmation alert when deleting an archived drug the Drug Edit view"])
                                                                                                                         message:NSLocalizedStringWithDefaultValue(@"ViewDrugEditConfirmArchivedDrugDeleteMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Warning: if you delete this drug, all dose history will be deleted. Are you sure you want to delete this drug?", @"The message on the confirmation alert when deleting an archived drug the Drug Edit view"])
                                                                                                                           style:DosecastAlertControllerStyleAlert];
                                              
                                              
                                              [alert addAction:
                                               [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                                                              style:DosecastAlertActionStyleCancel
                                                                            handler:nil]];
                                              
                                              [alert addAction:
                                               [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"])
                                                                              style:DosecastAlertActionStyleDefault
                                                                            handler:^(DosecastAlertAction *action){
                                                                                
                                                                                [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting drug", @"The message appearing in the spinner view when deleting a drug"])];
                                                                                
                                                                                [[LocalNotificationManager getInstance] deletePill:drugId
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
                                                                            handler:nil]];
                                              
                                              [alert addAction:
                                               [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonArchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Archive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"])
                                                                              style:DosecastAlertActionStyleDefault
                                                                            handler:^(DosecastAlertAction *action){
                                                                                [self handleArchivedButtonTap];
                                                                            }]];
                                              
                                              [alert addAction:
                                               [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"])
                                                                              style:DosecastAlertActionStyleDefault
                                                                            handler:^(DosecastAlertAction *action){
                                                                                [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerDeletingDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"Deleting drug", @"The message appearing in the spinner view when deleting a drug"])];
                                                                                
                                                                                [[LocalNotificationManager getInstance] deletePill:drugId
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
                                          
                                          [[LocalNotificationManager getInstance] deletePill:drugId
                                                                                updateServer:YES
                                                                                   respondTo:self
                                                                                       async:YES];
                                      }
                                  }]];
    
    [confirmDeleteController showInViewController:self sourceView:(UIButton*)sender];
}

- (IBAction)addDrugImage:(id)sender
{
    // Premium-only feature
    DataModel* dataModel = [DataModel getInstance];
    if (dataModel.globalSettings.accountType == AccountTypeDemo)
    {
        [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDrugImage", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug image support is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
    }
    else
    {
        // Only present the camera UI if the device has a camera.
        
        if ( [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] )
        {
            DrugImagePickerController *cameraUI = [[DrugImagePickerController alloc] init];
            cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
            cameraUI.cameraDevice = UIImagePickerControllerCameraDeviceRear;
            cameraUI.allowsEditing = YES;
            cameraUI.showsCameraControls = NO;
            
            // Overlay the library and cancel options with a custom toolbar.
            chooseImageViewController = [[DrugChooseImageViewController alloc]
                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugChooseImageViewController"]
                                          bundle:[DosecastUtil getResourceBundle]];
            chooseImageViewController.delegate = self;
            chooseImageViewController.picker = cameraUI;
            
            cameraUI.delegate = chooseImageViewController;
            cameraUI.cameraOverlayView = chooseImageViewController.view;
            chooseImageViewController.view.frame = CGRectMake(cameraUI.view.frame.origin.x, cameraUI.view.frame.origin.y, cameraUI.view.frame.size.width, cameraUI.view.frame.size.height);

            [self presentViewController:cameraUI animated:YES completion:nil];

        }
        else
        {
            // Present the saved photos library UI. On the iPad, we must use a
            // UIPopoverController to do so. On the iPhone/iPod, we can present
            // the photos array modally.
            
            DrugImagePickerController *libraryUI = [[DrugImagePickerController alloc] init];
            
            libraryUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            libraryUI.allowsEditing = YES;
            libraryUI.delegate = self;
            
            BOOL isiPadDevice = [DosecastUtil isIPad];
            
            if ( isiPadDevice)
            {
                // If the library popover is visible, do not display it again.
                
                if ( self.sharedPopover && [self.sharedPopover isPopoverVisible] )
                {
                    [self.sharedPopover dismissPopoverAnimated:YES];
                    return;
                }
                
                UIButton *senderButton = (UIButton *)sender;
                
                self.sharedPopover = [[UIPopoverController alloc] initWithContentViewController:libraryUI];
                [self.sharedPopover presentPopoverFromRect:senderButton.frame inView:self.drugImageCell.contentView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
            else
            {
                [self presentViewController:libraryUI animated:YES completion:nil];
            }
        }
    }
}

- (IBAction)editDrugImage:(id)sender
{
    // For now, the edit image button opens the default add image view.
    
    [self addDrugImage:sender];
}

- (IBAction)clearDrugImage:(id)sender
{
    // Premium-only feature
    DataModel* dataModel = [DataModel getInstance];
    if (dataModel.globalSettings.accountType == AccountTypeDemo)
    {
        [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDrugImage", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug image support is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
    }
    else
    {
        shouldClearDrugImage = YES;
        drugImage = nil;
        [self.tableView reloadData];
    }
}

- (void)handleSetReminder:(DrugReminder*)r
{
    BOOL isSameTypeOfScheduledReminder = ([r isKindOfClass:[reminder class]] && [r isKindOfClass:[ScheduledDrugReminder class]] && ((ScheduledDrugReminder*)r).frequency == ((ScheduledDrugReminder*)reminder).frequency);
    BOOL isSameTypeOfNonScheduledReminder = ([r isKindOfClass:[reminder class]] && ![r isKindOfClass:[ScheduledDrugReminder class]]);
    
	// If the reminder types are the same, copy the alert options from the old to the new reminder object
    if (isSameTypeOfScheduledReminder || isSameTypeOfNonScheduledReminder)
    {
		[r setRefillAlertOptionNum:[reminder getRefillAlertOptionNum]];
    }
	else // Otherwise, reset the alert option
    {
		[r setRefillAlertOptionNum:-1];
    }

    [r setExpirationAlertOptionNum:[reminder getExpirationAlertOptionNum]];
    [r setExpirationDate:reminder.expirationDate];

	reminder = r;
	[tableView reloadData];
}

- (BOOL)handleSetNumericQuantity:(float)val unit:(NSString*)unit identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
	float epsilon = 0.0001;
	
	if ([Id caseInsensitiveCompare:[dosage getTypeName]] == NSOrderedSame)
	{
		if ([subId caseInsensitiveCompare:RemainingQuantityId] == NSOrderedSame)
		{
			[dosage setValueForRemainingQuantity:val];
			[dosage setUnitForRemainingQuantity:unit];
			
			// If we just cleared the remaining quantity, also clear the refill alert
			if (val >= -1.0f-epsilon && val <= -1.0f+epsilon)
				[reminder setRefillAlertOptionNum:-1];
		}
		else if ([subId caseInsensitiveCompare:RefillQuantityId] == NSOrderedSame)
		{
			if (val <= epsilon) // don't allow 0 values
            {
				[dosage setValueForRefillQuantity:0.0f];
            }
			else
				[dosage setValueForRefillQuantity:val];
			[dosage setUnitForRefillQuantity:unit];
		}
		else
		{
            // ********* If editing the amount or strength of a database drug, and one of these differs enough, may want to clear the NDC
            
			if (val <= epsilon) // don't allow 0 values
				[dosage setValue:0.0f forDoseQuantity:subId];
			else
				[dosage setValue:val forDoseQuantity:subId];
			[dosage setUnit:unit forDoseQuantity:subId];
		}
	}
    else if ([Id caseInsensitiveCompare:RefillsRemainingId] == NSOrderedSame)
    {
        [dosage setRefillsRemaining:val];
    }
	
	[tableView reloadData];
    
    return YES;
}

- (BOOL)handleDonePickingItemInList:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId // Returns whether to allow the controller to be popped
{    
	// Pick a different drug dosage type
	if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
	{
        if (value && [value caseInsensitiveCompare:[dosage getTypeName]] != NSOrderedSame) // make sure we picked something new
        {
            DrugDosageManager* dosageManager = [DrugDosageManager getInstance];

			dosage = [dosageManager createDrugDosageWithTypeName:value];
			[reminder setRefillAlertOptionNum:-1]; // Clear the refill alert option
		}
	}
	// Pick a different person
	else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
	{        
        if (item == 0) // picked "me"
            [personId setString:@""]; // clear the person ID
        else // lookup custom type name
        {
            NSArray* personNames = nil;
            NSArray* personIds = nil;
            [[DataModel getInstance].globalSettings.personNames getSortedListOfNames:&personNames andCorrespondingGuids:&personIds];
            
            [personId setString:[personIds objectAtIndex:item-1]]; // set the person ID
        }        
	}
    // Pick a refill alert option
	else if ([Id caseInsensitiveCompare:RefillAlertOptionsPicklistId] == NSOrderedSame)
	{
		[reminder setRefillAlertOptionNum:item];
	}
    // Pick an expiration alert option
	else if ([Id caseInsensitiveCompare:ExpirationAlertOptionsPicklistId] == NSOrderedSame)
	{
		[reminder setExpirationAlertOptionNum:item];
	}
	// Pick a picklist value in the current drug dosage
	else if ([Id caseInsensitiveCompare:[dosage getTypeName]] == NSOrderedSame)
	{
        // ********* If editing the route of a database drug, and it differs enough, may want to clear the NDC

		if (item < 0 || !value)
			[dosage setValue:@"" forDosePicklist:subId];
		else
            [dosage setValue:value forDosePicklist:subId];
	}
	
	[tableView reloadData];
	return YES;
}

// Called when user hits cancel
- (void)handlePickCancel:(NSString*)Id subIdentifier:(NSString*)subId
{
    DataModel* dataModel = [DataModel getInstance];
    
    if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
    {
        // If we had a custom dosage, ensure it still exists. The user may have deleted it
        if ([dosage isKindOfClass:[CustomDrugDosage class]])
        {
            CustomDrugDosage* customDosage = (CustomDrugDosage*)dosage;
            NSString* customDosageID = [customDosage getCustomDosageID];
            // If it's deleted, replace it with the default type
            if (![dataModel.globalSettings.customDrugDosageNames nameForGuid:customDosageID])
            {
                DrugDosageManager* dosageManager = [DrugDosageManager getInstance];
                dosage = [dosageManager createDrugDosageWithTypeName:dosageManager.defaultTypeName];
                [reminder setRefillAlertOptionNum:-1]; // Clear the refill alert option
            }
        }
    }
	else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
    {
        // If we had a person set, ensure it still exists. The user may have deleted it
        if ([personId length] > 0 && ![dataModel.globalSettings.personNames nameForGuid:personId])
            [personId setString:@""]; // clear the person ID
    }
    
    // We still need to reload data because the user may have edited a picklist value and then cancelled out of the view
    [tableView reloadData];
}

// Called when an item is created. Returns whether should be allowed.
- (BOOL)allowItemCreation:(NSString*)itemName identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
    if (!itemName)
        return NO;
    
    if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
    {
        if ([itemName length] == 0)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoDrugTypeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter Drug Type Name", @"The title of the alert appearing in the Drug Add view when the user attempts to add a drug type with no name"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoDrugTypeMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a name for this drug type.", @"The message in the alert appearing in the Drug Add view when the user attempts to add a drug type with no name"])];
            [alert showInViewController:self];
            return NO;
        }
        else
            return YES;
    }
    else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
    {
        if ([itemName length] == 0)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoPersonNameTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter Person Name", @"The title of the alert appearing in the Drug Add view when the user attempts to add a person with no name"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddNoPersonNameMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a name for this person.", @"The message in the alert appearing in the Drug Add view when the user attempts to add a person with no name"])];
            [alert showInViewController:self];
            return NO;
        }
        else
            return YES;
    }
    else
        return NO;
}

// Called when an item is deleted. Returns whether should be allowed.
- (BOOL)allowItemDeletion:(int)item value:(NSString*)value identifier:(NSString*)Id subIdentifier:(NSString*)subId
{
    if (item < 0)
        return NO;
    
    if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
    {
        DataModel* dataModel = [DataModel getInstance];
        NSArray* drugList = dataModel.drugList;
        
        NSArray* customNames = nil;
        NSArray* customNameIds = nil;
        [[DataModel getInstance].globalSettings.customDrugDosageNames getSortedListOfNames:&customNames andCorrespondingGuids:&customNameIds];
        
        NSString* customNameID = [customNameIds objectAtIndex:item];
        
        // Look for any drugs that are using a custom drug type with this ID
        int numDrugs = (int)[drugList count];
        NSMutableString* drugNames = [NSMutableString stringWithString:@""];
        for (int i = 0; i < numDrugs; i++)
        {
            Drug* d = [drugList objectAtIndex:i];
            if ([d.dosage isKindOfClass:[CustomDrugDosage class]])
            {
                CustomDrugDosage* customDosage = (CustomDrugDosage*)d.dosage;
                if (customNameID && [customNameID caseInsensitiveCompare:[customDosage getCustomDosageID]] == NSOrderedSame)
                {
                    if ([drugNames length] > 0)
                        [drugNames appendString:@"\n"];
                    [drugNames appendString:d.name];
                }
            }
        }

        if ([drugNames length] > 0)
        {
            NSString* message = [NSString stringWithFormat:
                                 NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDrugTypeDeleteInUseMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This drug type can't be deleted because it is still being used by the following drugs:\n\n%@\n\nTo delete this drug type, either delete these drugs or change their drug type.", @"The message in the alert appearing in the Drug Add view when the user attempts to delete a drug type and it is in use"]),
                                 drugNames];
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDrugTypeDeleteInUseTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type In Use", @"The title of the alert appearing in the Drug Add view when the user attempts to delete a drug type and it is in use"])
                                                                                               message:message];
            [alert showInViewController:self];
            return NO;
        }
        else
            return YES;
    }
    else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
    {
        DataModel* dataModel = [DataModel getInstance];
        NSArray* drugList = dataModel.drugList;
        NSArray* personNames = nil;
        NSArray* personIds = nil;
        [dataModel.globalSettings.personNames getSortedListOfNames:&personNames andCorrespondingGuids:&personIds];
        
        NSString* personNameID = [personIds objectAtIndex:item];
        
        // Look for any drugs that are using this person ID
        int numDrugs = (int)[drugList count];
        NSMutableString* drugNames = [NSMutableString stringWithString:@""];
        for (int i = 0; i < numDrugs; i++)
        {
            Drug* d = [drugList objectAtIndex:i];
            if (personNameID && [personNameID caseInsensitiveCompare:d.personId] == NSOrderedSame)
            {
                if ([drugNames length] > 0)
                    [drugNames appendString:@"\n"];
                [drugNames appendString:d.name];
            }
        }
                    
        if ([drugNames length] > 0)
        {
            NSString* message = [NSString stringWithFormat:
                                 NSLocalizedStringWithDefaultValue(@"ErrorDrugAddPersonDeleteInUseMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This person can't be deleted because the following drugs are still assigned to them:\n\n%@\n\nTo delete this person, either delete these drugs or assign them to someone else.", @"The message in the alert appearing in the Drug Add view when the user attempts to delete a person and their ID is in use"]),
                                 drugNames];
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddPersonDeleteInUseTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Delete Person", @"The title of the alert appearing in the Drug Add view when the user attempts to delete a person and their ID is in use"])
                                                                                               message:message];
            [alert showInViewController:self];
            return NO;
        }
        else
            return YES;
    }
    else
        return NO;
}

// Called when a duplicate item is created. Returns whether should be allowed.
- (BOOL)handleDuplicateItemCreation:(NSString*)Id subIdentifier:(NSString*)subId
{    
    if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDuplicateDrugTypeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type Exists", @"The title of the alert appearing in the Drug Add view when the user attempts to add a duplicate drug type"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDuplicateDrugTypeMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"A drug type with this name already exists. Please pick another name.", @"The message in the alert appearing in the Drug Add view when the user attempts to add a duplicate drug type"])];
        [alert showInViewController:self];
        return NO;
    }
    else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDuplicatePersonTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Person Exists", @"The title of the alert appearing in the Drug Add view when the user attempts to add a duplicate person"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorDrugAddDuplicatePersonMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"A person with this name already exists. Please pick another name.", @"The message in the alert appearing in the Drug Add view when the user attempts to add a duplicate person"])];
        [alert showInViewController:self];
        return NO;
    }
    else
        return NO;
}

// Called to request item deletion, renaming, and creation. Items in each array are instances
// of PicklistEditedItem. Once changes have been made, must call PicklistViewController commitEdits
- (void)handleRequestEditItems:(NSArray*)deleted // deleted item indices are relative to the original editableItems list passed-in to PicklistViewController init
                  renamedItems:(NSArray*)renamed // renamed item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
                  createdItems:(NSArray*)created // created item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
                    identifier:(NSString*)Id
                 subIdentifier:(NSString*)subId
{    
    [deletedItems setArray:deleted];
    [renamedItems setArray:renamed];
    [createdItems setArray:created];

    if ([Id caseInsensitiveCompare:DrugDosageTypePicklistId] == NSOrderedSame)
    {
        CustomNameIDList* newCustomDrugDosageNames = [[DataModel getInstance].globalSettings.customDrugDosageNames mutableCopy];
        NSArray* customNames = nil;
        NSArray* customNameIds = nil;
        [newCustomDrugDosageNames getSortedListOfNames:&customNames andCorrespondingGuids:&customNameIds];
        NSMutableArray* mutableCustomNames = [NSMutableArray arrayWithArray:customNames];
        NSMutableArray* mutableCustomNameIds = [NSMutableArray arrayWithArray:customNameIds];

        // Remove deleted items
        int offsetIndex = 0;
        int numItems = (int)[deletedItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [deletedItems objectAtIndex:i];
            int index = item.index + offsetIndex;
            [newCustomDrugDosageNames removeNameForGuid:[mutableCustomNameIds objectAtIndex:index]];
            [mutableCustomNames removeObjectAtIndex:index];
            [mutableCustomNameIds removeObjectAtIndex:index];
            offsetIndex -= 1;
        }

        // Apply renamed items
        numItems = (int)[renamedItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [renamedItems objectAtIndex:i];
            [newCustomDrugDosageNames setName:item.value forGuid:[mutableCustomNameIds objectAtIndex:item.index]];
        }

        // Add created items
        numItems = (int)[createdItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [createdItems objectAtIndex:i];
            [newCustomDrugDosageNames setName:item.value forGuid:nil];
        }
        
        [preferencesDict removeAllObjects];
        [newCustomDrugDosageNames populateDictionary:preferencesDict forSyncRequest:NO];
        
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSavingChanges", @"Dosecast", [DosecastUtil getResourceBundle], @"Saving changes", @"The message appearing in the spinner view when saving changes"])];
        
        [[LocalNotificationManager getInstance] setPreferences:preferencesDict respondTo:self async:YES];
    }
    else if ([Id caseInsensitiveCompare:PersonPicklistId] == NSOrderedSame)
    {
        CustomNameIDList* newPersonNames = [[DataModel getInstance].globalSettings.personNames mutableCopy];
        NSArray* personNames = nil;
        NSArray* personNameIds = nil;
        [newPersonNames getSortedListOfNames:&personNames andCorrespondingGuids:&personNameIds];
        NSMutableArray* mutablePersonNames = [NSMutableArray arrayWithArray:personNames];
        NSMutableArray* mutablePersonNameIds = [NSMutableArray arrayWithArray:personNameIds];

        // Remove deleted items
        int offsetIndex = 0;
        int numItems = (int)[deletedItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [deletedItems objectAtIndex:i];
            int index = item.index + offsetIndex;
            
            [newPersonNames removeNameForGuid:[mutablePersonNameIds objectAtIndex:index]];
            [mutablePersonNames removeObjectAtIndex:index];
            [mutablePersonNameIds removeObjectAtIndex:index];
            offsetIndex -= 1;
        }
        
        // Apply renamed items
        numItems = (int)[renamedItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [renamedItems objectAtIndex:i];
            [newPersonNames setName:item.value forGuid:[mutablePersonNameIds objectAtIndex:item.index]];
        }
        
        // Add created items
        numItems = (int)[createdItems count];
        for (int i = 0; i < numItems; i++)
        {
            PicklistEditedItem* item = [createdItems objectAtIndex:i];
            [newPersonNames setName:item.value forGuid:nil];
        }
        
        [preferencesDict removeAllObjects];
        [newPersonNames populateDictionary:preferencesDict forSyncRequest:NO];
        
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSavingChanges", @"Dosecast", [DosecastUtil getResourceBundle], @"Saving changes", @"The message appearing in the spinner view when saving changes"])];
        
        [[LocalNotificationManager getInstance] setPreferences:preferencesDict respondTo:self async:YES];
    }
}

- (void)handlePickDoctor:(ABRecordID)pickedContact
{
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        return;
    
    // Check whether the selected contact is valid (i.e. a person for a doctor)
    if ([doctorContact isValidContact:pickedContact])
    {
        doctorContact.recordID = pickedContact;
        
        [self dismissViewControllerAnimated:YES completion:^() {

            // If there is a person viewer underneath, it means we're in the middle of a change of person. Update the selected person
            // in the viewer underneath.
            if ([self.navigationController.topViewController isKindOfClass:[ABPersonViewController class]])
            {
                [self.navigationController popViewControllerAnimated:NO];
                [self displayDoctorRecord:pickedContact animated:NO];
            }
        }];
        
        [self.tableView reloadData];
    }
    else
    {
        NSString* alertTitle = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditPickPersonTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Pick a Person", @"The title of the alert appearing in the Drug Edit page when an organization is selected instead of a person"]);
        NSString* alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditPickPersonMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please pick a contact with a first and/or last name.", @"The message of the alert appearing in the Drug Edit page when an organization is selected instead of a person"]);
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:alertTitle
                                                                                           message:alertMessage];
        [alert showInViewController:self];
    }
}

- (IBAction)displayDoctorPicker:(id)sender
{
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        return;

    pickingDoctor = YES; // we're going to pick a doctor now
    
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    picker.addressBook = [DataModel getInstance].contactsHelper.addressBook;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)handleViewDoctorNone:(id)sender
{
    doctorContact.recordID = kABRecordInvalidID;
    [self.navigationController popViewControllerAnimated:YES];
    [self.tableView reloadData];
}

- (void)handlePickPharmacy:(ABRecordID)pickedContact
{
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        return;
    
    // Check whether the selected contact is valid (i.e. a person for a doctor)
    if ([pharmacyContact isValidContact:pickedContact])
    {
        pharmacyContact.recordID = pickedContact;
        
        [self dismissViewControllerAnimated:YES completion:^() {
            
            // If there is a person viewer underneath, it means we're in the middle of a change of person. Update the selected person
            // in the viewer underneath.
            if ([self.navigationController.topViewController isKindOfClass:[ABPersonViewController class]])
            {
                [self.navigationController popViewControllerAnimated:NO];
                [self displayPharmacyRecord:pickedContact animated:NO];
            }
        }];
        
        [self.tableView reloadData];
    }
    else
    {
        NSString* alertTitle = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditPickOrganizationTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Pick an Organization", @"The title of the alert appearing in the Drug Edit page when a person is selected instead of an organization"]);
        NSString* alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditPickOrganizationMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please pick a contact with an organization or company name.", @"The message of the alert appearing in the Drug Edit page when a person is selected instead of an organization"]);
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:alertTitle
                                                                                           message:alertMessage];
        [alert showInViewController:self];
    }
}

- (IBAction)displayPharmacyPicker:(id)sender
{
    if ([DataModel getInstance].contactsHelper.addressBook == NULL)
        return;

    pickingDoctor = NO; // we're going to pick a pharmacy now
    
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    picker.addressBook = [DataModel getInstance].contactsHelper.addressBook;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)handleViewPharmacyNone:(id)sender
{
    pharmacyContact.recordID = kABRecordInvalidID;
    [self.navigationController popViewControllerAnimated:YES];
    [self.tableView reloadData];
}

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
    return NO; // Don't let the user select properties when viewing
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    ABRecordID pickedContact = ABRecordGetRecordID(person);
    
    if (pickingDoctor)
        [self handlePickDoctor:pickedContact];
    else
        [self handlePickPharmacy:pickedContact];
    
    return NO;
}

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
                         didSelectPerson:(ABRecordRef)person
{
    ABRecordID pickedContact = ABRecordGetRecordID(person);
    
    if (pickingDoctor)
        [self handlePickDoctor:pickedContact];
    else
        [self handlePickPharmacy:pickedContact];
    
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    return NO; // Don't let the user select properties when picking
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Camera delegate methods

- (void)didCancelImageSelection
{
    UIViewController* modalController = nil;
    modalController = self.navigationController.presentedViewController;

    if ( modalController )
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)didSelectImage:(UIImage *)img source:(DrugImageSource)source
{
#ifdef DEBUG
    NSLog(@"Selected Image Size: %@", NSStringFromCGSize(img.size));
#endif
        
    UIImageOrientation orientation = img.imageOrientation;
    UIImage *resultImage = nil;

    if ( source == DrugImageSourceCamera )
    {
        // Because image cropping requires the use of lower-level Core Graphics
        // functions that ignore UIImage's imageOrientation, we'll set the orientation
        // to the default (UIImageOrientationUp), perform the cropping and scaling,
        // and then rotate to the correct orientation.
        
        UIImage *ignoreRotationImage = [[UIImage alloc] initWithCGImage:img.CGImage scale:1.0f orientation:UIImageOrientationUp];

        UIImage *resizedImage = [ignoreRotationImage resizedImage:DRUG_IMAGE_CROP_SIZE interpolationQuality:kCGInterpolationHigh];
        
        if ( orientation != UIImageOrientationUp )
            resultImage = [[UIImage alloc] initWithCGImage:resizedImage.CGImage scale:1.0f orientation:orientation];
        else
            resultImage = resizedImage;
    }
    else if ( source == DrugImageSourcePhotoLibrary )
    {
        // Resize and crop from library selection
#ifdef DEBUG
        NSLog(@"Photo Library Image Orientation: %i", (int)orientation);
#endif
        
        UIImage *ignoreRotationImage = [[UIImage alloc] initWithCGImage:img.CGImage scale:1.0f orientation:UIImageOrientationUp];
        
        CGFloat aspectRatio = ignoreRotationImage.size.width / ignoreRotationImage.size.height;
        CGFloat cropSize = fminf( ignoreRotationImage.size.width, ignoreRotationImage.size.height );
        const float epsilon = 0.0001;
        UIImage *resizedImage = nil;
        
        if ( aspectRatio < 1.0f+epsilon && aspectRatio > 1.0f-epsilon )
        {
            // Image is already square.
            
            resizedImage = [img resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:DRUG_IMAGE_CROP_SIZE interpolationQuality:kCGInterpolationHigh];
        }
        else if ( aspectRatio > 1.0f )
        {
            // Image is landscape.
         
            CGFloat xInset = (ignoreRotationImage.size.width - cropSize) / 2;
            CGRect cropRect = CGRectMake( xInset , 0.0f, cropSize, cropSize );

            UIImage *croppedImage = [ignoreRotationImage croppedImage:cropRect];

            resizedImage = [croppedImage resizedImage:DRUG_IMAGE_CROP_SIZE interpolationQuality:kCGInterpolationHigh];
        }
        else
        {
            // Image is portrait.
            
            CGFloat yInset = (ignoreRotationImage.size.height - cropSize) / 2;
            CGRect cropRect = CGRectMake( 0.0f , yInset, cropSize, cropSize );
            
            UIImage *croppedImage = [ignoreRotationImage croppedImage:cropRect];
            
            resizedImage = [croppedImage resizedImage:DRUG_IMAGE_CROP_SIZE interpolationQuality:kCGInterpolationHigh];
        }

        resultImage = [[UIImage alloc] initWithCGImage:resizedImage.CGImage scale:1.0f orientation:orientation];
    }
    
#ifdef DEBUG
    NSLog(@"Final Image Size: %@", NSStringFromCGSize(resultImage.size));
#endif
    
    // Find the section containing the drug image
    int section = -1;
    for (int i = 0; i < [tableViewSections count] && section < 0; i++)
    {
        if ([[tableViewSections objectAtIndex:i] intValue] == DrugAddEditViewControllerSectionsDrugImage)
            section = i;
    }
    
    UITableViewCell *imageCell = (UITableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
    
    UIImageView *drugImageView = (UIImageView *)[imageCell.contentView viewWithTag:3];
    drugImageView.image = resultImage;
    
    DrugImageManager *manager = [DrugImageManager sharedManager];
    NSString *tempGUID = [manager imageGUIDWithImage:resultImage withImageGUID:nil shouldUploadImage:NO];
    [tempDrugImageGUID setString:tempGUID];
    drugImage = resultImage;
    
    shouldClearDrugImage = NO;
        
    UIViewController* modalController = nil;
    modalController = self.navigationController.presentedViewController;

    if ( modalController )
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.4f];
}

// Delegate method to tell the presenting view controller (self) to display
// the photo library picker instead of the camera picker.

- (void)didChooseModalPhotoLibraryFromCameraUI
{
    if ( self.navigationController.presentedViewController )
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            
            DrugImagePickerController *libraryUI = [[DrugImagePickerController alloc] init];
            libraryUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            libraryUI.allowsEditing = YES;
            libraryUI.delegate = self;
            
            [self presentViewController:libraryUI animated:YES completion:nil];
        }];
}

// In the special case where the user selects library from the modal camera view
// on iPhone/iPod, we must present the modal picker view again. The DrugAddEddViewController
// is the delegate method.

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *pickedImage;
    
    // Get the edited (scaled and cropped) image from the picker delegate,
    // if it exists.
    
    if ( [info valueForKey:UIImagePickerControllerEditedImage] )
        pickedImage = (UIImage *)[info valueForKey:UIImagePickerControllerEditedImage];
    else
        pickedImage = (UIImage *)[info valueForKey:UIImagePickerControllerOriginalImage];
    
    [self didSelectImage:pickedImage source:DrugImageSourcePhotoLibrary];
    
    if ([DosecastUtil isIPad])
    {
        if ( self.sharedPopover && [self.sharedPopover isPopoverVisible] )
        {
            [self.sharedPopover dismissPopoverAnimated:YES];
        }
    }
}


#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}


#pragma mark - Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcDynamicCellWidths];
    
    DataModel* dataModel = [DataModel getInstance];
    
    [tableViewSections removeAllObjects];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDrugName]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDrugType]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDosage]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsReminder]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDirections]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsNotes]];
    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDrugImage]];
    
    if ([dataModel.apiFlags getFlag:DosecastAPIMultiPersonSupport])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsPerson]];
    
    [remainingRefillRows removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPITrackRemainingQuantities])
    {
        [remainingRefillRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerRemainingRefillRowsQuantityRemaining]];
        [remainingRefillRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerRemainingRefillRowsRefillQuantity]];
    
        if ([dataModel.apiFlags getFlag:DosecastAPITrackRefillsRemaining])
            [remainingRefillRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerRemainingRefillRowsRefillsRemaining]];

        [remainingRefillRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerRemainingRefillRowsRefillAlert]];
    }
    if ([remainingRefillRows count] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsRemainingRefill]];

    [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsExpiration]];

    [doctorPharmacyRows removeAllObjects];
    if ([dataModel.apiFlags getFlag:DosecastAPIDoctorSupport] && dataModel.contactsHelper.accessGranted)
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerDoctorPharmacyRowsDoctor]];
    if ([dataModel.apiFlags getFlag:DosecastAPIPharmacySupport] && dataModel.contactsHelper.accessGranted)
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerDoctorPharmacyRowsPharmacy]];
    if ([dataModel.apiFlags getFlag:DosecastAPIPrescriptionNumberSupport])
        [doctorPharmacyRows addObject:[NSNumber numberWithInt:DrugAddEditViewControllerDoctorPharmacyRowsPrescriptionNum]];
    if ([doctorPharmacyRows count] > 0)
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDoctorPharmacy]];
    
    
    // Display the reminders cell for interval or scheduled drugs only
	if (!reminder.archived && ![reminder isKindOfClass:[AsNeededDrugReminder class]])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsReminderSwitch]];
    // Display the logMissedDoses cell for scheduled drugs only
	if (!reminder.archived && [reminder isKindOfClass:[ScheduledDrugReminder class]])
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsLogMissedDoses]];
    // Display the delete cell if editing only
    if (controllerMode == DrugAddEditViewControllerModeEditDrug)
    {
        [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsArchive]];
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
            [tableViewSections addObject:[NSNumber numberWithInt:DrugAddEditViewControllerSectionsDelete]];
    }
    
	return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    DrugAddEditViewControllerSections controllerSection = (DrugAddEditViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == DrugAddEditViewControllerSectionsDosage)
		return [dosage numDoseInputs];
	else if (controllerSection == DrugAddEditViewControllerSectionsRemainingRefill)
		return [remainingRefillRows count];
    else if (controllerSection == DrugAddEditViewControllerSectionsExpiration)
        return 2;
    else if (controllerSection == DrugAddEditViewControllerSectionsDoctorPharmacy)
        return [doctorPharmacyRows count];
    else if (controllerSection == DrugAddEditViewControllerSectionsReminderSwitch)
    {
        if (reminder.remindersEnabled)
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
    DrugAddEditViewControllerSections section = (DrugAddEditViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (section == DrugAddEditViewControllerSectionsDrugName)
	{
		UILabel* header = (UILabel *)[drugNameCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);
		UILabel* label = (UILabel *)[drugNameCell viewWithTag:2];
		label.text = drugName;
        
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            drugNameCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            drugNameCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            drugNameCell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
        else
        {
            drugNameCell.accessoryType = UITableViewCellAccessoryNone;
            drugNameCell.editingAccessoryType = UITableViewCellAccessoryNone;
            drugNameCell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
		return drugNameCell;
	}
    else if (section == DrugAddEditViewControllerSectionsPerson)
    {
        UILabel* header = (UILabel *)[personCell viewWithTag:1];
        header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonTakenBy", @"Dosecast", [DosecastUtil getResourceBundle], @"For", @"The Person For label in the Drug Edit view"]);
        UILabel* label = (UILabel *)[personCell viewWithTag:2];
        if ([personId length] == 0)
            label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]);
        else
            label.text = [[DataModel getInstance].globalSettings.personNames nameForGuid:personId];
        return personCell;
    }	
	else if (section == DrugAddEditViewControllerSectionsDrugType)
	{
		UILabel* header = (UILabel *)[drugTypeCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type", @"The Drug Type label in the Drug Edit view");
		UILabel* label = (UILabel *)[drugTypeCell viewWithTag:2];
		label.text = [dosage getTypeName];
        
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            drugTypeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            drugTypeCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            drugTypeCell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
        else
        {
            drugTypeCell.accessoryType = UITableViewCellAccessoryNone;
            drugTypeCell.editingAccessoryType = UITableViewCellAccessoryNone;
            drugTypeCell.selectionStyle = UITableViewCellSelectionStyleNone;
        }

		return drugTypeCell;
	}
	else if (section == DrugAddEditViewControllerSectionsDrugImage)
	{
        UIImageView *drugThumbnailImageView = (UIImageView *)[self.drugImageCell viewWithTag:3];
        drugThumbnailImageView.backgroundColor = [DosecastUtil getDrugImagePlaceholderColor];
        
        UIActivityIndicatorView *activity = (UIActivityIndicatorView *)[self.drugImageCell viewWithTag:1000];
        [activity startAnimating];
        activity.layer.zPosition += 1; // Make sure this appears on top of everything else

        UIButton *addImageButton = (UIButton *)[self.drugImageCell viewWithTag:4];
        UIButton *editImageButton = (UIButton *)[self.drugImageCell viewWithTag:5];
        UIButton *clearImageButton = (UIButton *)[self.drugImageCell viewWithTag:6];
        
        UILabel *noDrugImageLabel = (UILabel *)[self.drugImageCell viewWithTag:20];
        noDrugImageLabel.text = NSLocalizedStringWithDefaultValue(@"NoDrugImagePlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"No drug image", @"The default placeholder string when no image has been set throughout the client "]);

        if ( drugImage != nil )
        {            
            drugThumbnailImageView.image = drugImage;
            
            noDrugImageLabel.hidden = YES;
            
            addImageButton.hidden = YES;
            editImageButton.hidden = NO;
            clearImageButton.hidden = NO;
        }
        else
        {            
            BOOL hasPlaceholderImage = self.drugPlaceholderImageView.image != nil;
            
            drugThumbnailImageView.image = hasPlaceholderImage ? self.drugPlaceholderImageView.image : nil;
            
            noDrugImageLabel.hidden = hasPlaceholderImage;
            
            addImageButton.hidden = NO;
            editImageButton.hidden = YES;
            clearImageButton.hidden = YES;
            
            NSString *placeHolderFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Image_Placeholder.png"];
            UIImage* placeHolderImage = [[UIImage alloc] initWithContentsOfFile:placeHolderFilePath];
            drugThumbnailImageView.image = placeHolderImage;
        }
        
        [activity stopAnimating];
        
		return drugImageCell;
    }
	else if (section == DrugAddEditViewControllerSectionsDosage)
	{
        UITableViewCell *cell = nil;
        
        int inputNum = (int)indexPath.row;
		DrugDosageInputType inputType = [dosage getDoseInputTypeForInput:inputNum];

        if (inputType == DrugDosageInputTypeQuantity || inputType == DrugDosageInputTypePicklist)
        {
            static NSString *MyIdentifier = @"PillCellIdentifier";
            cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
            if (cell == nil) {
                [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugAddEditDoseInputTableViewCell" owner:self options:nil];
                cell = doseInputCell;
                doseInputCell = nil;
            }
        }
        else // inputType == DrugDosageInputTypeText
        {
            static NSString *MyIdentifier = @"TextPillCellIdentifier";
            cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
            if (cell == nil) {
                [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugAddEditDoseInputTextTableViewCell" owner:self options:nil];
                cell = doseInputTextCell;
                doseInputTextCell = nil;
            }            
        }
		
		UILabel* titleText = (UILabel*)[cell viewWithTag:1];
		UILabel* labelText = (UILabel*)[cell viewWithTag:2];
        
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.editingAccessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;            
        }

		if (inputType == DrugDosageInputTypeQuantity)
		{
			NSString* quantityName = nil;
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([dosage getDoseQuantityUISettingsForInput:inputNum
										 quantityName:&quantityName
											sigDigits:&sigDigits
										  numDecimals:&numDecimals
										  displayNone:&displayNone
											allowZero:&allowZero])
			{
				titleText.text = [dosage getLabelForDoseQuantity:quantityName];
				labelText.text = [dosage getDescriptionForDoseQuantity:quantityName maxNumDecimals:numDecimals];
				return cell;
			}
			else
				return nil;
		}
		else if (inputType == DrugDosageInputTypePicklist)
		{
			NSString* picklistName = nil;
			BOOL displayNone = YES;
			
			if ([dosage getDosePicklistUISettingsForInput:inputNum
										 picklistName:&picklistName
										  displayNone:&displayNone])
			{
				titleText.text = [dosage getLabelForDosePicklist:picklistName];
				labelText.text = [dosage getValueForDosePicklist:picklistName];
				return cell;				
			}
			else
				return nil;
		}
        else if (inputType == DrugDosageInputTypeText)
		{
			NSString* textValueName = nil;
			BOOL displayNone = YES;
			
			if ([dosage getDoseTextValueUISettingsForInput:inputNum
                                             textValueName:&textValueName
                                               displayNone:&displayNone])
			{
				titleText.text = [dosage getLabelForDoseTextValue:textValueName];
				labelText.text = [dosage getValueForDoseTextValue:textValueName];
                labelText.hidden = NO;
				return cell;				
			}
			else
				return nil;
		}
		else
			return nil;
	}
	else if (section == DrugAddEditViewControllerSectionsDirections)
	{
		UILabel* header = (UILabel*)[directionsCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirections", @"Dosecast", [DosecastUtil getResourceBundle], @"Directions", @"The Directions label in the Drug Edit view"]);
		
		UILabel* label = (UILabel *)[directionsCell viewWithTag:2];
        label.hidden = NO;
		if ([directions length] > 0)
		{
			label.text = directions;
			label.textColor = [UIColor blackColor];
		}
		else
		{
			label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirectionsExample", @"Dosecast", [DosecastUtil getResourceBundle], @"e.g. take with food", @"The Directions example in the Drug Edit view"]);
			label.textColor = [UIColor lightGrayColor];
		}
        
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            directionsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            directionsCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            directionsCell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
        else
        {
            directionsCell.accessoryType = UITableViewCellAccessoryNone;
            directionsCell.editingAccessoryType = UITableViewCellAccessoryNone;
            directionsCell.selectionStyle = UITableViewCellSelectionStyleNone;
        }

		return directionsCell;
	}
	else if (section == DrugAddEditViewControllerSectionsReminder)
	{
		if ([reminder isKindOfClass:[ScheduledDrugReminder class]])
		{
			ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)reminder;
			
			UILabel* takeDrugLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:1];
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
			
			UILabel* reminderTypeLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:2];
			reminderTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduled", @"Dosecast", [DosecastUtil getResourceBundle], @"On a schedule", @"The Take Drug value for scheduled drugs in the Drug Edit view"]);
			
			UILabel* reminderDataHeaderLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:3];
			reminderDataHeaderLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequency", @"Dosecast", [DosecastUtil getResourceBundle], @"Frequency", @"The Frequency label for scheduled drugs in the Drug Edit view"]);
			
			UILabel* frequencyLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:4];
			if (scheduledReminder.frequency == ScheduledDrugFrequencyDaily)
				frequencyLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyDaily", @"Dosecast", [DosecastUtil getResourceBundle], @"Daily", @"The Freiquency value for daily scheduled drugs in the Drug Edit view"]);
			else if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly)
            {
                frequencyLabel.text = [NSString stringWithFormat:@"%@, %@:",
                                  NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeeklyLocal", @"Dosecast", [DosecastUtil getResourceBundle], @"Weekly", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]),
                                  [NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyWeekdayHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Every", @"The Frequency value for weekly scheduled drugs in the Drug Edit view"]) lowercaseString]];
            }
			else if (scheduledReminder.frequency == ScheduledDrugFrequencyMonthly)
                frequencyLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenFrequencyMonthly", @"Dosecast", [DosecastUtil getResourceBundle], @"Monthly", @"The Frequency value for monthly scheduled drugs in the Drug Edit view"]);
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
                
                frequencyLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ScheduleRepeatPeriodPhraseDetail", @"Dosecast", [DosecastUtil getResourceBundle], @"Every %d %@", @"The detailed phrase for describing schedule repeat periods for scheduled drugs"]), scheduledReminder.customFrequencyNum, unitName];
            }

            // Start tracking the last variable-position label in the cell
            int lastLabelPos = frequencyLabel.frame.origin.y + frequencyLabel.frame.size.height;
            
            BOOL showWeekdayLabels = (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly);
                                    
            // Set the weekday label values & visibility
            int numWeekdays = 0;
            if (showWeekdayLabels && scheduledReminder.weekdays)
                numWeekdays = (int)[scheduledReminder.weekdays count];
            
            NSArray* weekdayNames = [dateFormatter weekdaySymbols];
            NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            int firstWeekday = (int)[cal firstWeekday];

            for (int i = 0; i < 7; i++)
            {
                UILabel* weekdayLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:5+i];
                
                if (i+1 <= numWeekdays)
                {
                    weekdayLabel.hidden = NO;
                    int weekday = [[scheduledReminder.weekdays objectAtIndex:i] intValue];
                    weekdayLabel.text = [weekdayNames objectAtIndex:weekday-firstWeekday];
                    lastLabelPos += weekdayLabel.frame.size.height;
                }
                else
                    weekdayLabel.hidden = YES;
            }

            // Add a margin under the weekdays (if any)
            lastLabelPos += FREQUENCY_WEEKDAY_LABEL_MARGIN+1;

			UILabel* treatmentStartsLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:12];
			treatmentStartsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
            treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, lastLabelPos, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
            
			UILabel* treatmentStartsDate = (UILabel*)[takeDrugScheduledCell viewWithTag:13];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];			
			treatmentStartsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentStartDate], [dateFormatter stringFromDate:reminder.treatmentStartDate]];
            treatmentStartsDate.frame = CGRectMake(treatmentStartsDate.frame.origin.x, lastLabelPos, treatmentStartsDate.frame.size.width, treatmentStartsDate.frame.size.height);

            lastLabelPos += treatmentStartsDate.frame.size.height+1;

			UILabel* treatmentEndLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:14];
			treatmentEndLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
            treatmentEndLabel.frame = CGRectMake(treatmentEndLabel.frame.origin.x, lastLabelPos, treatmentEndLabel.frame.size.width, treatmentEndLabel.frame.size.height);
			
			UILabel* treatmentEndsDate = (UILabel*)[takeDrugScheduledCell viewWithTag:15];
			if (reminder.treatmentEndDate == nil)
				treatmentEndsDate.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
			else
				treatmentEndsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentEndDate], [dateFormatter stringFromDate:reminder.treatmentEndDate]];
            treatmentEndsDate.frame = CGRectMake(treatmentEndsDate.frame.origin.x, lastLabelPos, treatmentEndsDate.frame.size.width, treatmentEndsDate.frame.size.height);

            lastLabelPos += treatmentEndsDate.frame.size.height+1;

			UILabel* timeOfDayLabel = (UILabel*)[takeDrugScheduledCell viewWithTag:16];
			timeOfDayLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTakenScheduleTimes", @"Dosecast", [DosecastUtil getResourceBundle], @"Time of Day", @"The Time of Day label for scheduled drugs in the Drug Edit view"]);
            timeOfDayLabel.frame = CGRectMake(timeOfDayLabel.frame.origin.x, lastLabelPos, timeOfDayLabel.frame.size.width, timeOfDayLabel.frame.size.height);
			
            lastLabelPos += FREQUENCY_WEEKDAY_LABEL_MARGIN+2;

			NSMutableArray* reminderDataLabels = [[NSMutableArray alloc] init];
			for (int j = 0; j < MAX_REMINDER_SCHEDULE_TIMES; j++)
			{
				[reminderDataLabels addObject:[takeDrugScheduledCell viewWithTag:17+j]];
			}
			
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			int numTimes = (int)[scheduledReminder.reminderTimes count];
			for (int i = 0; i < MAX_REMINDER_SCHEDULE_TIMES; i++)
			{
				UILabel* l = (UILabel*)[reminderDataLabels objectAtIndex:i];
				if (numTimes == 0 && i == 0)
                {
					l.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditScheduleTimesNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The none value in the Take Drug cell for scheduled reminders of the Drug Edit view"]);
                    l.frame = CGRectMake(l.frame.origin.x, lastLabelPos, l.frame.size.width, l.frame.size.height);
                    lastLabelPos += l.frame.size.height;
                }
                else
				{
					if (numTimes >= i+1)
					{
						l.text = [dateFormatter stringFromDate:[scheduledReminder getReminderTime:i]];
                        l.frame = CGRectMake(l.frame.origin.x, lastLabelPos, l.frame.size.width, l.frame.size.height);
                        lastLabelPos += l.frame.size.height;
						l.hidden = NO;
					}
					else
						l.hidden = YES;					
				}
			}
			
			return takeDrugScheduledCell;
		}
		else if ([reminder isKindOfClass:[IntervalDrugReminder class]])
		{
			DataModel* dataModel = [DataModel getInstance];
			
			UILabel* takeDrugLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:1];
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
			
			UILabel* reminderTypeLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:2];
			if (dataModel.globalSettings.bedtimeStart != -1 && dataModel.globalSettings.bedtimeEnd != -1)
				reminderTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalBedtime", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals until bedtime", @"The Take Drug value for interval drugs in the Drug Edit view when bedtime is defined"]);
			else
				reminderTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugInterval", @"Dosecast", [DosecastUtil getResourceBundle], @"At intervals", @"The Take Drug value for interval drugs in the Drug Edit view"]);
			
			UILabel* reminderDataHeaderLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:3];
			reminderDataHeaderLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalPeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval", @"The Interval label for interval drugs in the Drug Edit view"]);
			
			UILabel* intervalLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:4];
			int numMinutes = ((IntervalDrugReminder*)reminder).interval/60;
			intervalLabel.text = [IntervalDrugReminder intervalDescription:numMinutes];
			
            BOOL showDoseLimit = (numMinutes < MIN_PER_DAY);
            UILabel* doseLimitLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:5];
			doseLimitLabel.hidden = !showDoseLimit;
            if (showDoseLimit)
                doseLimitLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
            
			UILabel* doseLimitValue = (UILabel*)[takeDrugIntervalCell viewWithTag:6];
			doseLimitValue.hidden = !showDoseLimit;
            if (showDoseLimit)
                doseLimitValue.text = [((IntervalDrugReminder*)reminder) getDoseLimitDescription];
            
			UILabel* treatmentStartsLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:7];
			treatmentStartsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
            if (showDoseLimit)
                treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, doseLimitLabel.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
            else
                treatmentStartsLabel.frame = CGRectMake(treatmentStartsLabel.frame.origin.x, reminderDataHeaderLabel.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentStartsLabel.frame.size.width, treatmentStartsLabel.frame.size.height);
                
			UILabel* treatmentStartsDate = (UILabel*)[takeDrugIntervalCell viewWithTag:8];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			treatmentStartsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentStartDate], [dateFormatter stringFromDate:reminder.treatmentStartDate]];
            if (showDoseLimit)
                treatmentStartsDate.frame = CGRectMake(treatmentStartsDate.frame.origin.x, doseLimitValue.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentStartsDate.frame.size.width, treatmentStartsDate.frame.size.height);
            else
                treatmentStartsDate.frame = CGRectMake(treatmentStartsDate.frame.origin.x, intervalLabel.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentStartsDate.frame.size.width, treatmentStartsDate.frame.size.height);
            
			UILabel* treatmentEndLabel = (UILabel*)[takeDrugIntervalCell viewWithTag:9];
			treatmentEndLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
            treatmentEndLabel.frame = CGRectMake(treatmentEndLabel.frame.origin.x, treatmentStartsLabel.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentEndLabel.frame.size.width, treatmentEndLabel.frame.size.height);

			UILabel* treatmentEndsDate = (UILabel*)[takeDrugIntervalCell viewWithTag:10];
			if (reminder.treatmentEndDate == nil)
				treatmentEndsDate.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
			else
				treatmentEndsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentEndDate], [dateFormatter stringFromDate:reminder.treatmentEndDate]];
            treatmentEndsDate.frame = CGRectMake(treatmentEndsDate.frame.origin.x, treatmentStartsDate.frame.origin.y + HEADER_LABEL_HEIGHT, treatmentEndsDate.frame.size.width, treatmentEndsDate.frame.size.height);
			
			return takeDrugIntervalCell;			
		}
		else // AsNeededDrugReminder
		{
			UILabel* takeDrugLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:1];
			takeDrugLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDosesTaken", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Drug", @"The Take Drug label in the Drug Edit view"]);
			
			UILabel* reminderTypeLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:2];
			reminderTypeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugAsNeeded", @"Dosecast", [DosecastUtil getResourceBundle], @"As needed", @"The Take Drug value for as-needed drugs in the Drug Edit view"]);

            UILabel* doseLimitLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:3];
			doseLimitLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
			
			UILabel* doseLimitValue = (UILabel*)[takeDrugAsNeededCell viewWithTag:4];
			doseLimitValue.text = [((AsNeededDrugReminder*)reminder) getDoseLimitDescription];

            UILabel* treatmentStartsLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:5];
			treatmentStartsLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditStarting", @"Dosecast", [DosecastUtil getResourceBundle], @"Starting", @"The Starting label in the Drug Edit view"]);
			
			UILabel* treatmentStartsDate = (UILabel*)[takeDrugAsNeededCell viewWithTag:6];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			treatmentStartsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentStartDate], [dateFormatter stringFromDate:reminder.treatmentStartDate]];
			
			UILabel* treatmentEndLabel = (UILabel*)[takeDrugAsNeededCell viewWithTag:7];
			treatmentEndLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditEnding", @"Dosecast", [DosecastUtil getResourceBundle], @"Ending", @"The Ending label in the Drug Edit view"]);
			
			UILabel* treatmentEndsDate = (UILabel*)[takeDrugAsNeededCell viewWithTag:8];
			if (reminder.treatmentEndDate == nil)
				treatmentEndsDate.text = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditEndingNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The never value in the Ending cell of the Drug Edit view"]);
			else
				treatmentEndsDate.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.treatmentEndDate], [dateFormatter stringFromDate:reminder.treatmentEndDate]];

			return takeDrugAsNeededCell;			
		}
	}
	else if (section == DrugAddEditViewControllerSectionsRemainingRefill)
	{
        DrugAddEditViewControllerRemainingRefillRows row = (DrugAddEditViewControllerRemainingRefillRows)[[remainingRefillRows objectAtIndex:indexPath.row] intValue];

		if (row == DrugAddEditViewControllerRemainingRefillRowsQuantityRemaining)
		{
			UILabel* titleText = (UILabel*)[remainingCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[remainingCell viewWithTag:2];
			
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
			{
				titleText.text = [dosage getLabelForRemainingQuantity];
				labelText.text = [dosage getDescriptionForRemainingQuantity:numDecimals];
				return remainingCell;
			}
			else
				return nil;			
		}
		else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillQuantity)
		{
			UILabel* titleText = (UILabel*)[refillCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[refillCell viewWithTag:2];
			
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([dosage getRefillQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
			{
				titleText.text = [dosage getLabelForRefillQuantity];
				labelText.text = [dosage getDescriptionForRefillQuantity:numDecimals];
				return refillCell;
			}
			else
				return nil;			
		}
        else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillsRemaining)
        {
            UILabel* titleText = (UILabel*)[refillsRemainingCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[refillsRemainingCell viewWithTag:2];
			titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillsRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills Remaining", @"The Refills Remaining label in the Drug Edit view"]);

            labelText.text = [NSString stringWithFormat:@"%d", [dosage getRefillsRemaining]];
            
            return refillsRemainingCell;
        }
		else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillAlert)
		{
			UILabel* titleText = (UILabel*)[refillAlertCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[refillAlertCell viewWithTag:2];
			
			titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The Refill Alert label in the Drug Edit view"]);
			int refillAlertOptionNum = [reminder getRefillAlertOptionNum];
			if (refillAlertOptionNum >= 0)
			{
				NSArray* refillAlertOptions = [reminder getRefillAlertOptions];
				labelText.text = [refillAlertOptions objectAtIndex:refillAlertOptionNum];
			}
			else
			{
				labelText.text = @"";
			}
			
			return refillAlertCell;
		}
        else
            return nil;
	}
    else if (section == DrugAddEditViewControllerSectionsExpiration)
    {
        if (indexPath.row == 0)
        {
            UILabel* titleText = (UILabel*)[expirationDateCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[expirationDateCell viewWithTag:2];
			
			titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationDate", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Date", @"The Expiration Date label in the Drug Edit view"]);
			if (reminder.expirationDate)
			{
                [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
                [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
				labelText.text = [NSString stringWithFormat:@"%@ %@", [DosecastUtil getAbbrevDayOfWeekForDate:reminder.expirationDate], [dateFormatter stringFromDate:reminder.expirationDate]];
			}
			else
			{
				labelText.text = @"";
			}
			
			return expirationDateCell;
        }
        else // if (indexPath.row == 1)
        {
            UILabel* titleText = (UILabel*)[expirationAlertCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[expirationAlertCell viewWithTag:2];
			
			titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Alert", @"The Expiration Alert label in the Drug Edit view"]);
			int expirationAlertOptionNum = [reminder getExpirationAlertOptionNum];
			if (expirationAlertOptionNum >= 0)
			{
				NSArray* expirationAlertOptions = [reminder getExpirationAlertOptions];
				labelText.text = [expirationAlertOptions objectAtIndex:expirationAlertOptionNum];
			}
			else
			{
				labelText.text = @"";
			}
			
			return expirationAlertCell;
        }
    }
    else if (section == DrugAddEditViewControllerSectionsDoctorPharmacy)
    {
        DrugAddEditViewControllerDoctorPharmacyRows row = (DrugAddEditViewControllerDoctorPharmacyRows)[[doctorPharmacyRows objectAtIndex:indexPath.row] intValue];

        if (row == DrugAddEditViewControllerDoctorPharmacyRowsDoctor)
        {
            UILabel* titleText = (UILabel*)[doctorCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[doctorCell viewWithTag:2];
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDoctor", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor", @"The Doctor label in the Drug Edit view"]);            
            labelText.text = [doctorContact getDisplayName];
            
            return doctorCell;
        }
        else if (row == DrugAddEditViewControllerDoctorPharmacyRowsPharmacy)
        {
            UILabel* titleText = (UILabel*)[pharmacyCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[pharmacyCell viewWithTag:2];
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Pharmacy", @"The Pharmacy label in the Drug Edit view"]);
            labelText.text = [pharmacyContact getDisplayName];
            
            return pharmacyCell;
        }
        else if (row == DrugAddEditViewControllerDoctorPharmacyRowsPrescriptionNum)
        {
            UILabel* titleText = (UILabel*)[prescriptionNumCell viewWithTag:1];
			UILabel* labelText = (UILabel*)[prescriptionNumCell viewWithTag:2];
            titleText.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditPrescriptionNumber", @"Dosecast", [DosecastUtil getResourceBundle], @"Prescription #", @"The Prescription Number label in the Drug Edit view"]);

            labelText.text = prescriptionNum;
            
            if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
            {
                prescriptionNumCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                prescriptionNumCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
                prescriptionNumCell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
            else
            {
                prescriptionNumCell.accessoryType = UITableViewCellAccessoryNone;
                prescriptionNumCell.editingAccessoryType = UITableViewCellAccessoryNone;
                prescriptionNumCell.selectionStyle = UITableViewCellSelectionStyleNone;                
            }

            return prescriptionNumCell;   
        }
        else
            return nil;
    }
    else if (section == DrugAddEditViewControllerSectionsNotes)
    {
		UILabel* header = (UILabel*)[notesCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditNotes", @"Dosecast", [DosecastUtil getResourceBundle], @"Notes", @"The Notes label in the Drug Edit view"]);

		UITextView* textView = (UITextView*)[notesCell viewWithTag:2];
        
        // Initialize the properties of the cell
        textView.text = notes;
        textView.editable = NO;
        textView.dataDetectorTypes = UIDataDetectorTypeNone;        

        return notesCell;
    }
	else if (section == DrugAddEditViewControllerSectionsReminderSwitch)
	{
        if (indexPath.row == 0)
        {
            UILabel* header = (UILabel*)[remindersCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminders", @"The Reminders label in the Drug Edit view"]);
            UISwitch* s = (UISwitch*)[remindersCell viewWithTag:2];
            s.on = reminder.remindersEnabled;
            return remindersCell;
        }
        else // if indexPath.row == 1
        {
            UILabel* header = (UILabel*)[secondaryRemindersCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditSecondaryReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Secondary Reminders", @"The Secondary Reminders label in the Drug Edit view"]);
            UISwitch* s = (UISwitch*)[secondaryRemindersCell viewWithTag:2];
            s.on = reminder.secondaryRemindersEnabled;
            return secondaryRemindersCell;
        }
	}
    else if (section == DrugAddEditViewControllerSectionsLogMissedDoses)
	{
		UILabel* header = (UILabel*)[logMissedDosesCell viewWithTag:1];
		header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugEditLogMissedDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Log Missed Doses", @"The Log Missed Doses label in the Drug Edit view"]);
		UISwitch* s = (UISwitch*)[logMissedDosesCell viewWithTag:2];
        ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)reminder;
		s.on = scheduledReminder.logMissedDoses;
		return logMissedDosesCell;
	}
    else if (section == DrugAddEditViewControllerSectionsArchive)
	{
        if (reminder.archived)
        {
            UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
            backView.backgroundColor = [UIColor clearColor];
            unarchiveButtonCell.backgroundView = backView;
            unarchiveButtonCell.backgroundColor = [UIColor clearColor];
            
            // Dynamically set the color of the button if an image isn't already set.
            UIButton* button = (UIButton *)[unarchiveButtonCell viewWithTag:1];
            UIImage* buttonImage = button.currentImage;
            if (!buttonImage)
            {
                [button setTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonUnarchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Unarchive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"]) forState:UIControlStateNormal];
                [DosecastUtil setBackgroundColorForButton:button color:[DosecastUtil getArchiveButtonColor]];
            }
            
            return unarchiveButtonCell;
        }
        else
        {
            UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
            backView.backgroundColor = [UIColor clearColor];
            archiveButtonCell.backgroundView = backView;
            archiveButtonCell.backgroundColor = [UIColor clearColor];
            
            // Dynamically set the color of the button if an image isn't already set.
            UIButton* button = (UIButton *)[archiveButtonCell viewWithTag:1];
            UIImage* buttonImage = button.currentImage;
            if (!buttonImage)
            {
                [button setTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonArchive", @"Dosecast", [DosecastUtil getResourceBundle], @"Archive Drug", @"The text on the Archive button in a confirmation action sheet in the Drug Edit view"]) forState:UIControlStateNormal];
                [DosecastUtil setBackgroundColorForButton:button color:[DosecastUtil getArchiveButtonColor]];
            }
            
            return archiveButtonCell;
        }
	}
	else if (section == DrugAddEditViewControllerSectionsDelete)
	{
		UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		deleteButtonCell.backgroundView = backView;
        deleteButtonCell.backgroundColor = [UIColor clearColor];
		
		// Dynamically set the color of the delete button if an image isn't already set.
		UIButton* deleteButton = (UIButton *)[deleteButtonCell viewWithTag:1];
        UIImage* deleteButtonImage = deleteButton.currentImage;
        if (!deleteButtonImage)
        {
            [deleteButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditActionButtonDelete", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete Drug", @"The text on the Delete button in a confirmation action sheet in the Drug Edit view"]) forState:UIControlStateNormal];
            [DosecastUtil setBackgroundColorForButton:deleteButton color:[DosecastUtil getDeleteButtonColor]];
        }
        
		return deleteButtonCell;
	}
	else
		return nil;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
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

- (BOOL)handleSetDateValue:(NSDate*)dateVal uniqueIdentifier:(int)Id
{
    // If the expiration date was removed and an alert was set, remove the alert
    if (!dateVal && [reminder getExpirationAlertOptionNum] >= 0)
        [reminder setExpirationAlertOptionNum:-1];
    reminder.expirationDate = dateVal;
    [tableView reloadData];
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DrugAddEditViewControllerSections section = (DrugAddEditViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (section == DrugAddEditViewControllerSectionsReminder)
	{
		if ([reminder isKindOfClass:[AsNeededDrugReminder class]])
			return 176;
		else if ([reminder isKindOfClass:[IntervalDrugReminder class]])
        {
            int numMinutes = ((IntervalDrugReminder*)reminder).interval/60;			
            BOOL showDoseLimit = (numMinutes < MIN_PER_DAY);
            if (showDoseLimit)
                return 220;
            else
                return 220- HEADER_LABEL_HEIGHT;
        }
		else // ScheduledDrugReminder
		{
            ScheduledDrugReminder* scheduledReminder = (ScheduledDrugReminder*)reminder;
            int totalHeight = 510;

            int numWeekdays = 0;

            // The cell height may vary depending on the number of weekdays
            if (scheduledReminder.frequency == ScheduledDrugFrequencyWeekly &&
                scheduledReminder.weekdays)
            {
                numWeekdays = (int)[scheduledReminder.weekdays count];
            }
            totalHeight -= REMINDER_TIME_LABEL_HEIGHT * (7 - numWeekdays);

			int reminderTimeCount = (int)[scheduledReminder.reminderTimes count];
			if (reminderTimeCount == 0) // Keep space for at least "None"
				reminderTimeCount = 1;
			totalHeight -= (MAX_REMINDER_SCHEDULE_TIMES-reminderTimeCount)*REMINDER_TIME_LABEL_HEIGHT;
            return totalHeight;
		}
	}
    else if (section == DrugAddEditViewControllerSectionsNotes)
        return 178;
    else if (section == DrugAddEditViewControllerSectionsDrugImage)
        return 120;
    else if (section == DrugAddEditViewControllerSectionsDrugName)
        return (int)ceilf([self getHeightForCellLabel:drugNameCell tag:2 withString:drugName]);
    else if (section == DrugAddEditViewControllerSectionsDosage)
    {
        int inputNum = (int)indexPath.row;
		DrugDosageInputType inputType = [dosage getDoseInputTypeForInput:inputNum];
        if (inputType == DrugDosageInputTypeText)
        {
            NSString* textValueName = nil;
			BOOL displayNone = YES;
			
			if ([dosage getDoseTextValueUISettingsForInput:inputNum
                                             textValueName:&textValueName
                                               displayNone:&displayNone])
			{
                return (int)ceilf([self getHeightForCellLabel:exampleDoseInputTextCell tag:2 withString:[dosage getValueForDoseTextValue:textValueName]]);
			}
            else
                return 44;
        }
        else
            return 44;
    }
    else if (section == DrugAddEditViewControllerSectionsDirections)
        return (int)ceilf([self getHeightForCellLabel:directionsCell tag:2 withString:directions]);
	else
		return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (void) displayDoctorRecord:(ABRecordID)doctorRecord animated:(BOOL)animated
{
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
    
    [self.navigationController pushViewController:viewController animated:animated];
    
    // Set Change button
    NSString* changeButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonChange", @"Dosecast", [DosecastUtil getResourceBundle], @"Change", @"The text on the Change toolbar button"]);
    UIBarButtonItem *changeButton = [[UIBarButtonItem alloc] initWithTitle:changeButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(displayDoctorPicker:)];
    viewController.navigationItem.rightBarButtonItem = changeButton;
    
    // Set None button
    NSString* noneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The text on the None toolbar button"]);
    UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *noneButton = [[UIBarButtonItem alloc] initWithTitle:noneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleViewDoctorNone:)];
    viewController.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, noneButton, nil];
    
    [viewController.navigationController setToolbarHidden:NO animated:animated];
}

- (void) displayPharmacyRecord:(ABRecordID)pharmacyRecord animated:(BOOL)animated
{
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
    
    [self.navigationController pushViewController:viewController animated:animated];
    
    // Set Change button
    NSString* changeButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonChange", @"Dosecast", [DosecastUtil getResourceBundle], @"Change", @"The text on the Change toolbar button"]);
    UIBarButtonItem *changeButton = [[UIBarButtonItem alloc] initWithTitle:changeButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(displayPharmacyPicker:)];
    viewController.navigationItem.rightBarButtonItem = changeButton;
    
    // Set None button
    NSString* noneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The text on the None toolbar button"]);
    UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *noneButton = [[UIBarButtonItem alloc] initWithTitle:noneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleViewPharmacyNone:)];
    viewController.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, noneButton, nil];
    
    [viewController.navigationController setToolbarHidden:NO animated:animated];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	
    DrugAddEditViewControllerSections section = (DrugAddEditViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

	if (section == DrugAddEditViewControllerSectionsDrugName)
	{
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            // Display view for drug name
            DrugNameViewController* nameController = [[DrugNameViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugNameViewController"]
                                                                                              bundle:[DosecastUtil getResourceBundle]
                                                                                            drugName:drugName
                                                                                    placeholderValue:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"])
                                                                                            delegate:self];
            [self.navigationController pushViewController:nameController animated:YES];
        }
	}
    else if (section == DrugAddEditViewControllerSectionsPerson)
    {
        // Premium-only feature
		DataModel* dataModel = [DataModel getInstance];
		if (dataModel.globalSettings.accountType == AccountTypeDemo)
		{
            [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionPerson", @"Dosecast", [DosecastUtil getResourceBundle], @"Multi-person support is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
		}
		else
		{            
            // Find which item is selected
            
			int selectedItem = 0;

            // Get the selected person name
            NSString* selectedPersonName = nil;
            if ([personId length] > 0)
                selectedPersonName = [dataModel.globalSettings.personNames nameForGuid:personId];
            
            NSArray* personNames = nil;
            NSArray* personNameIds = nil;
            [dataModel.globalSettings.personNames getSortedListOfNames:&personNames andCorrespondingGuids:&personNameIds];

            // Look at editable person names
            int numItems = (int)[personNames count];
			for (int i = 0; i < numItems && selectedItem <= 0 && selectedPersonName; i++)
			{
				NSString* thisPersonName = [personNames objectAtIndex:i];
				if ([thisPersonName caseInsensitiveCompare:selectedPersonName] == NSOrderedSame)
					selectedItem = i+1; // skip the "me" option
			}
			
			PicklistViewController* picklistController = [[PicklistViewController alloc]
														  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
														  bundle:[DosecastUtil getResourceBundle]
														  nonEditableItems:[NSArray arrayWithObject:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"])]
                                                          editableItems:personNames
														  selectedItem:selectedItem
                                                          allowEditing:YES
														  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPerson", @"Dosecast", [DosecastUtil getResourceBundle], @"Person", @"The Person label in the Drug Edit view"])
														  headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonTakenBy", @"Dosecast", [DosecastUtil getResourceBundle], @"For", @"The Person For label in the Drug Edit view"])
														  footerText:nil
                                                          addItemCellText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonAdd", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Person", @"The Add Person label in the Drug Edit view"])
                                                          addItemPlaceholderText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonName", @"Dosecast", [DosecastUtil getResourceBundle], @"Person Name", @"The Person Name label in the Drug Edit view"])
														  displayNone:NO
														  identifier:PersonPicklistId
														  subIdentifier:nil
														  delegate:self];
			[self.navigationController pushViewController:picklistController animated:YES];
        }
    }
	else if (section == DrugAddEditViewControllerSectionsDrugType)
	{
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            // Premium-only feature
            DataModel* dataModel = [DataModel getInstance];
            if (dataModel.globalSettings.accountType == AccountTypeDemo)
            {
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionMultipleDrugTypes", @"Dosecast", [DosecastUtil getResourceBundle], @"Multiple drug types are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
            }
            else
            {
                // Find which item is selected
                
                // Look at standard drug types
                NSMutableArray* drugDosageTypeNames = [NSMutableArray arrayWithArray:[[DrugDosageManager getInstance] getStandardTypeNames]];
                [drugDosageTypeNames sortUsingSelector:@selector(compare:)];
                int selectedItem = -1;
                int numItems = (int)[drugDosageTypeNames count];
                NSString* dosageTypeName = [dosage getTypeName];
                for (int i = 0; i < numItems && selectedItem < 0; i++)
                {
                    NSString* thisTypeName = [drugDosageTypeNames objectAtIndex:i];
                    if ([thisTypeName caseInsensitiveCompare:dosageTypeName] == NSOrderedSame)
                        selectedItem = i;
                }
                            
                // Look at custom drug types
                NSArray* customNames = nil;
                NSArray* customNameIds = nil;
                [dataModel.globalSettings.customDrugDosageNames getSortedListOfNames:&customNames andCorrespondingGuids:&customNameIds];

                int numStandardItems = numItems;
                numItems = (int)[customNames count];
                for (int i = 0; i < numItems && selectedItem < 0; i++)
                {
                    NSString* thisTypeName = [customNames objectAtIndex:i];
                    if ([thisTypeName caseInsensitiveCompare:dosageTypeName] == NSOrderedSame)
                        selectedItem = i+(int)[drugDosageTypeNames count];
                }
                
                // If we still don't have a selected item, add the current dosage type name to the list of standard drug types and select it
                if (selectedItem < 0)
                {
                    [drugDosageTypeNames addObject:dosageTypeName];
                    selectedItem = numStandardItems;
                }                
                
                PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                              initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                              bundle:[DosecastUtil getResourceBundle]
                                                              nonEditableItems:drugDosageTypeNames
                                                              editableItems:customNames
                                                              selectedItem:selectedItem
                                                              allowEditing:YES
                                                              viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type", @"The Drug Type label in the Drug Edit view"])
                                                              headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugType", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type", @"The Drug Type label in the Drug Edit view"])
                                                              footerText:nil
                                                              addItemCellText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugTypeAdd", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Drug Type", @"The Add Drug Type label in the Drug Edit view"])
                                                              addItemPlaceholderText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugTypeName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Type Name (e.g. Tablet)", @"The Drug Type Name label in the Drug Edit view"])
                                                              displayNone:NO
                                                              identifier:DrugDosageTypePicklistId
                                                              subIdentifier:nil
                                                              delegate:self];
                [self.navigationController pushViewController:picklistController animated:YES];
            }
        }
	}
	else if (section == DrugAddEditViewControllerSectionsDosage)
	{
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            int inputNum = (int)indexPath.row;
            DrugDosageInputType inputType = [dosage getDoseInputTypeForInput:inputNum];
            if (inputType == DrugDosageInputTypeQuantity)
            {
                // Get UI setting for this quantity
                NSString* quantityName = nil;
                int sigDigits = 0;
                int numDecimals = 0;
                BOOL displayNone = YES;
                BOOL allowZero = YES;
                
                if ([dosage getDoseQuantityUISettingsForInput:inputNum
                                             quantityName:&quantityName
                                                sigDigits:&sigDigits
                                              numDecimals:&numDecimals
                                              displayNone:&displayNone
                                                allowZero:&allowZero])
                {
                    // Get the current value
                    NSMutableArray* possibleUnits = [NSMutableArray arrayWithArray:[dosage possibleUnitsForDoseQuantity:quantityName]];
                    float quantityVal;
                    NSString* quantityUnit;
                    if ([dosage isValidValueForDoseQuantity:quantityName])
                    {
                        [dosage getValue:&quantityVal forDoseQuantity:quantityName];
                        [dosage getUnit:&quantityUnit forDoseQuantity:quantityName];
                    }
                    else
                    {
                        quantityVal = 0.0f;
                        [dosage getUnit:&quantityUnit forDoseQuantity:quantityName];

                        if (!quantityUnit && [possibleUnits count] > 0)
                        {
                            quantityUnit = [possibleUnits objectAtIndex:0];
                        }
                    }
                    
                    // See if the unit is among the list of possible units. If not, add it at the end.
                    if (quantityUnit)
                    {
                        BOOL foundUnit = NO;
                        int numUnits = (int)[possibleUnits count];
                        for (int i = 0; i < numUnits && !foundUnit; i++)
                        {
                            if ([quantityUnit caseInsensitiveCompare:[possibleUnits objectAtIndex:i]] == NSOrderedSame)
                                foundUnit = YES;
                        }
                        
                        if (!foundUnit)
                            [possibleUnits addObject:quantityUnit];
                    }                
                    
                    // Display the picker
                    NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
                                                                      initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                      sigDigits:sigDigits
                                                                      numDecimals:numDecimals
                                                                      viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"])
                                                       displayTitle:[dosage getLabelForDoseQuantity:quantityName]
                                                                      initialVal:quantityVal
                                                                      initialUnit:quantityUnit
                                                                      possibleUnits:possibleUnits
                                                                      displayNone:displayNone
                                                                      allowZeroVal:allowZero
                                                                      identifier:[dosage getTypeName]
                                                                      subIdentifier:quantityName
                                                                      delegate:self];
                    [self.navigationController pushViewController:numericController animated:YES];
                }
            }
            else if (inputType == DrugDosageInputTypePicklist)
            {
                NSString* picklistName = nil;
                BOOL displayNone = YES;
                
                // Get the UI settings for this picklist
                if ([dosage getDosePicklistUISettingsForInput:inputNum
                                             picklistName:&picklistName
                                              displayNone:&displayNone])
                {
                    // Get the current value
                    NSMutableArray* picklistOptions = [NSMutableArray arrayWithArray:[dosage possibleOptionsForDosePicklist:picklistName]];
                    [picklistOptions sortUsingSelector:@selector(compare:)];
                    NSString* picklistVal = [dosage getValueForDosePicklist:picklistName];
                    
                    int selectedItemLoc = -1;
                    int numOptions = (int)[picklistOptions count];
                    for (int i = 0; i < numOptions && selectedItemLoc < 0; i++)
                    {
                        NSString* option = [picklistOptions objectAtIndex:i];
                        if ([option caseInsensitiveCompare:picklistVal] == NSOrderedSame)
                            selectedItemLoc = i;
                    }
                    
                    // If we didn't find the picklist item among available options, add it as an additional item at the bottom
                    if ([picklistVal length] > 0 && selectedItemLoc < 0)
                    {
                        [picklistOptions addObject:picklistVal];
                        selectedItemLoc = (int)[picklistOptions count]-1;
                    }
                    
                    // Display the picker
                    PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                                  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  nonEditableItems:picklistOptions
                                                                  editableItems:nil
                                                                  selectedItem:selectedItemLoc
                                                                  allowEditing:NO
                                                                  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"])
                                                                  headerText:[dosage getLabelForDosePicklist:picklistName]
                                                                  footerText:nil
                                                                  addItemCellText:nil
                                                                  addItemPlaceholderText:nil
                                                                  displayNone:displayNone
                                                                  identifier:[dosage getTypeName]
                                                                  subIdentifier:picklistName
                                                                  delegate:self];
                    [self.navigationController pushViewController:picklistController animated:YES];
                }
            }
            else if (inputType == DrugDosageInputTypeText)
            {
                NSString* textValueName = nil;
                BOOL displayNone = YES;
                
                // Get the UI settings for this text value
                if ([dosage getDoseTextValueUISettingsForInput:inputNum
                                                 textValueName:&textValueName
                                                   displayNone:&displayNone])
                {
                    // Get the current value
                    NSString* textValue = [dosage getValueForDoseTextValue:textValueName];				
                    
                    TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                               initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                               bundle:[DosecastUtil getResourceBundle]
                                                               viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"])
                                                               numTextFields:1
                                                               multiline:NO
                                                               initialValues:[NSArray arrayWithObject:[NSString stringWithString:textValue]]
                                                               placeholderStrings:[NSArray arrayWithObject:NSLocalizedStringWithDefaultValue(@"ViewDrugViewDosage", @"Dosecast", [DosecastUtil getResourceBundle], @"Dosage", @"The Dosage label in the Drug View view"])]
                                                               capitalizationType:UITextAutocapitalizationTypeSentences
                                                               correctionType:UITextAutocorrectionTypeYes
                                                               keyboardType:UIKeyboardTypeDefault
                                                               secureTextEntry:NO
                                                               identifier:TextEntryDosageId
                                                               subIdentifier:textValueName
                                                               delegate:self];
                    [self.navigationController pushViewController:textController animated:YES];
                }
            }
        }
	}
	else if (section == DrugAddEditViewControllerSectionsDirections)
	{
        if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
        {
            // Display text entry view for directions
            NSString* placeholderString = [NSString stringWithFormat:@"%@ %@", NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirections", @"Dosecast", [DosecastUtil getResourceBundle], @"Directions", @"The Directions label in the Drug Edit view"]),
                                           NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirectionsExample", @"Dosecast", [DosecastUtil getResourceBundle], @"e.g. take with food", @"The Directions example in the Drug Edit view"])];
            
            TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                       initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                       bundle:[DosecastUtil getResourceBundle]
                                                       viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditDirections", @"Dosecast", [DosecastUtil getResourceBundle], @"Directions", @"The Directions label in the Drug Edit view"])
                                                       numTextFields:1
                                                       multiline:NO
                                                       initialValues:[NSArray arrayWithObject:[NSString stringWithString:directions]]
                                                       placeholderStrings:[NSArray arrayWithObject:placeholderString]
                                                       capitalizationType:UITextAutocapitalizationTypeSentences
                                                       correctionType:UITextAutocorrectionTypeYes
                                                       keyboardType:UIKeyboardTypeDefault
                                                       secureTextEntry:NO
                                                       identifier:TextEntryDirectionsId
                                                       subIdentifier:nil
                                                       delegate:self];
            [self.navigationController pushViewController:textController animated:YES];
        }
	}
	else if (section == DrugAddEditViewControllerSectionsReminder)
	{
		ReminderAddEditViewController* reminderAddEditController = [[ReminderAddEditViewController alloc]
																	initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ReminderAddEditViewController"]
																	bundle:[DosecastUtil getResourceBundle]
																	drugId:drugId
																	drugReminder:reminder
																	delegate:self];
		[self.navigationController pushViewController:reminderAddEditController animated:YES];
	}
	else if (section == DrugAddEditViewControllerSectionsRemainingRefill)
	{
        DrugAddEditViewControllerRemainingRefillRows row = (DrugAddEditViewControllerRemainingRefillRows)[[remainingRefillRows objectAtIndex:indexPath.row] intValue];

		if (row == DrugAddEditViewControllerRemainingRefillRowsQuantityRemaining)
		{
			// Get UI setting for the remaining quantity
			int sigDigits = 0;
			int numDecimals = 0;
			BOOL displayNone = YES;
			BOOL allowZero = YES;
			
			if ([dosage getRemainingQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
			{
				// Premium-only feature
				DataModel* dataModel = [DataModel getInstance];
				if (dataModel.globalSettings.accountType == AccountTypeDemo)
				{
                    [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionQuantityTracking", @"Dosecast", [DosecastUtil getResourceBundle], @"Quantity tracking is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
				}
				else
				{					
					// Get the current value
					NSMutableArray* possibleUnits = [NSMutableArray arrayWithArray:[dosage possibleUnitsForRemainingQuantity]];
					float quantityVal;
					NSString* quantityUnit;
                    [dosage getValueForRemainingQuantity:&quantityVal];
                    if (quantityVal < epsilon)
                        quantityVal = 0.0f;
                    [dosage getUnitForRemainingQuantity:&quantityUnit];
                    
                    // See if the unit is among the list of possible units. If not, add it at the end.
                    if (quantityUnit)
                    {
                        BOOL foundUnit = NO;
                        int numUnits = (int)[possibleUnits count];
                        for (int i = 0; i < numUnits && !foundUnit; i++)
                        {
                            if ([quantityUnit caseInsensitiveCompare:[possibleUnits objectAtIndex:i]] == NSOrderedSame)
                                foundUnit = YES;
                        }
                        
                        if (!foundUnit)
                            [possibleUnits addObject:quantityUnit];
                    }                
					
					// Display the picker
					NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
																	  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                      sigDigits:sigDigits
																	  numDecimals:numDecimals
																	  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Remaining", @"The Remaining label in the Drug Edit view"])
																	  displayTitle:[dosage getLabelForRemainingQuantity]
																	  initialVal:quantityVal
																	  initialUnit:quantityUnit
																	  possibleUnits:possibleUnits
																	  displayNone:displayNone
																	  allowZeroVal:allowZero
																	  identifier:[dosage getTypeName]
																	  subIdentifier:RemainingQuantityId
																	  delegate:self];
					[self.navigationController pushViewController:numericController animated:YES];
				}
			}				
		}
		else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillQuantity)
		{
			// Premium-only feature
			DataModel* dataModel = [DataModel getInstance];
			if (dataModel.globalSettings.accountType == AccountTypeDemo)
			{
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionRefills", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
			}
			else
			{									
				// Get UI setting for the refill quantity
				int sigDigits = 0;
				int numDecimals = 0;
				BOOL displayNone = YES;
				BOOL allowZero = YES;
				
				if ([dosage getRefillQuantityUISettings:&sigDigits numDecimals:&numDecimals displayNone:&displayNone allowZero:&allowZero])
				{
					// Get the current value
					NSMutableArray* possibleUnits = [NSMutableArray arrayWithArray:[dosage possibleUnitsForRefillQuantity]];
					float quantityVal;
					NSString* quantityUnit;
					if ([dosage isValidValueForRefillQuantity])
					{
						[dosage getValueForRefillQuantity:&quantityVal];
						[dosage getUnitForRefillQuantity:&quantityUnit];
					}
					else
					{
						quantityVal = 0.0f;
						[dosage getUnitForRefillQuantity:&quantityUnit];
						
						if (!quantityUnit && [possibleUnits count] > 0)
						{
							quantityUnit = [possibleUnits objectAtIndex:0];
						}
					}
					
                    // See if the unit is among the list of possible units. If not, add it at the end.
                    if (quantityUnit)
                    {
                        BOOL foundUnit = NO;
                        int numUnits = (int)[possibleUnits count];
                        for (int i = 0; i < numUnits && !foundUnit; i++)
                        {
                            if ([quantityUnit caseInsensitiveCompare:[possibleUnits objectAtIndex:i]] == NSOrderedSame)
                                foundUnit = YES;
                        }
                        
                        if (!foundUnit)
                            [possibleUnits addObject:quantityUnit];
                    }                

					// Display the picker
					NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
																	  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                      sigDigits:sigDigits
																	  numDecimals:numDecimals
																	  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefill", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill", @"The Refill label in the Drug Edit view"])
																	  displayTitle:[dosage getLabelForRefillQuantity]
																	  initialVal:quantityVal
																	  initialUnit:quantityUnit
																	  possibleUnits:possibleUnits
																	  displayNone:displayNone
																	  allowZeroVal:allowZero
																	  identifier:[dosage getTypeName]
																	  subIdentifier:RefillQuantityId
																	  delegate:self];
					[self.navigationController pushViewController:numericController animated:YES];
				}							
			}
		}
        else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillsRemaining)
        {
            // Premium-only feature
			DataModel* dataModel = [DataModel getInstance];
			if (dataModel.globalSettings.accountType == AccountTypeDemo)
			{
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionRefills", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
			}
			else
            {
                int initialRefillsRemaining = [dosage getRefillsRemaining];
                if (initialRefillsRemaining < 0)
                    initialRefillsRemaining = 0;
                
                // Display the picker
                NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
                                                                  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  sigDigits:2
                                                                  numDecimals:0
                                                                  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillsRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills Remaining", @"The Refills Remaining label in the Drug Edit view"])
                                                                  displayTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillsRemaining", @"Dosecast", [DosecastUtil getResourceBundle], @"Refills Remaining", @"The Refills Remaining label in the Drug Edit view"])
                                                                  initialVal:initialRefillsRemaining
                                                                  initialUnit:nil
                                                                  possibleUnits:nil
                                                                  displayNone:YES
                                                                  allowZeroVal:YES
                                                                  identifier:RefillsRemainingId
                                                                  subIdentifier:nil
                                                                  delegate:self];
                [self.navigationController pushViewController:numericController animated:YES];
            }
        }
		else if (row == DrugAddEditViewControllerRemainingRefillRowsRefillAlert)
		{
			// Premium-only feature
			DataModel* dataModel = [DataModel getInstance];
			if (dataModel.globalSettings.accountType == AccountTypeDemo)
			{
                [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionRefillAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill alerts are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
			}
			else
			{
                float takeDoseQuantity;
                NSString* quantityToDecrementRemainingQuantity = [dosage getDoseQuantityToDecrementRemainingQuantity];
                if (quantityToDecrementRemainingQuantity && (![dosage getTakeDoseQuantity:&takeDoseQuantity] || takeDoseQuantity < epsilon))
                {
                    NSString* quantityToDecrementRemainingQuantityLabel = [dosage getLabelForDoseQuantity:quantityToDecrementRemainingQuantity];
                    
                    NSString* alertTitle = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditRefillAlertNotAllowedTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Cannot Set Refill Alert", @"The title of the alert appearing in the Drug Edit page when a refill alert is edited and no remaining quantity is set"]);
                    NSString* alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorDrugEditRefillAlertNotAllowedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"A refill alert cannot be set because the %@ has not been set. Before setting a refill alert, set the %@ first.", @"The message in the alert appearing in the Drug Edit page when a refill alert is edited and no remaining quantity is set"]);
                    
                    DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:alertTitle
                                                                                                       message:[NSString stringWithFormat:alertMessage, quantityToDecrementRemainingQuantityLabel, quantityToDecrementRemainingQuantityLabel]];
                    [alert showInViewController:self];
                }
                else
                {
                    NSArray* refillAlertOptions = [reminder getRefillAlertOptions];
                    
                    PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                                  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                                  bundle:[DosecastUtil getResourceBundle]
                                                                  nonEditableItems:refillAlertOptions
                                                                  editableItems:nil
                                                                  selectedItem:[reminder getRefillAlertOptionNum]
                                                                  allowEditing:NO
                                                                  viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The Refill Alert label in the Drug Edit view"])
                                                                  headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditRefillAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Refill Alert", @"The Refill Alert label in the Drug Edit view"])
                                                                  footerText:nil
                                                                  addItemCellText:nil
                                                                  addItemPlaceholderText:nil
                                                                  displayNone:YES
                                                                  identifier:RefillAlertOptionsPicklistId
                                                                  subIdentifier:nil
                                                                  delegate:self];
                    [self.navigationController pushViewController:picklistController animated:YES];
                }
			}
		}
	}
    else if (section == DrugAddEditViewControllerSectionsExpiration)
    {
        if (indexPath.row == 0)
        {
            TSQMonthPickerViewController* monthPickerController = [[TSQMonthPickerViewController alloc]
                                                                init:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationDate", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Date", @"The Expiration Date label in the Drug Edit view"])
                                                                initialDate:reminder.expirationDate
                                                                displayNever:YES
                                                                uniqueIdentifier:0
                                                                delegate:self];
            [self.navigationController pushViewController:monthPickerController animated:YES];

        }
        else // (indexPath.row == 1)
        {
            NSArray* expirationAlertOptions = [reminder getExpirationAlertOptions];
            
            PicklistViewController* picklistController = [[PicklistViewController alloc]
                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"PicklistViewController"]
                                                          bundle:[DosecastUtil getResourceBundle]
                                                          nonEditableItems:expirationAlertOptions
                                                          editableItems:nil
                                                          selectedItem:[reminder getExpirationAlertOptionNum]
                                                          allowEditing:NO
                                                          viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpiration", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration", @"The Expiration label in the Drug Edit view"])
                                                          headerText:NSLocalizedStringWithDefaultValue(@"ViewDrugEditExpirationAlert", @"Dosecast", [DosecastUtil getResourceBundle], @"Expiration Alert", @"The Expiration Alert label in the Drug Edit view"])
                                                          footerText:nil
                                                          addItemCellText:nil
                                                          addItemPlaceholderText:nil
                                                          displayNone:YES
                                                          identifier:ExpirationAlertOptionsPicklistId
                                                          subIdentifier:nil
                                                          delegate:self];
            [self.navigationController pushViewController:picklistController animated:YES];
        }
    }
	else if (section == DrugAddEditViewControllerSectionsDoctorPharmacy)
    {
        DrugAddEditViewControllerDoctorPharmacyRows row = (DrugAddEditViewControllerDoctorPharmacyRows)[[doctorPharmacyRows objectAtIndex:indexPath.row] intValue];

        if (row == DrugAddEditViewControllerDoctorPharmacyRowsDoctor)
        {
            if ([DataModel getInstance].contactsHelper.addressBook != NULL)
            {
                // Premium-only feature
                DataModel* dataModel = [DataModel getInstance];
                if (dataModel.globalSettings.accountType == AccountTypeDemo)
                {
                    [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoctorPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor and pharmacy tracking are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
                }
                else
                {
                    ABRecordID doctorRecord = doctorContact.recordID;

                    if (doctorRecord == kABRecordInvalidID)
                        [self displayDoctorPicker:nil];
                    else
                    {
                        [self displayDoctorRecord:doctorRecord animated:YES];
                    }
                }
            }
        }
        else if (row == DrugAddEditViewControllerDoctorPharmacyRowsPharmacy)
        {
            if ([DataModel getInstance].contactsHelper.addressBook != NULL)
            {
                // Premium-only feature
                DataModel* dataModel = [DataModel getInstance];
                if (dataModel.globalSettings.accountType == AccountTypeDemo)
                {
                    [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoctorPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor and pharmacy tracking are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
                }
                else
                {
                    ABRecordID pharmacyRecord = pharmacyContact.recordID;
                    
                    if (pharmacyRecord == kABRecordInvalidID)
                        [self displayPharmacyPicker:nil];
                    else
                    {
                        [self displayPharmacyRecord:pharmacyRecord animated:YES];
                    }
                }                
            }
        }
        else if (row == DrugAddEditViewControllerDoctorPharmacyRowsPrescriptionNum)
        {
            if (!drugId || ![[[DataModel getInstance] findDrugWithId:drugId] isManaged])
            {
                // Premium-only feature
                DataModel* dataModel = [DataModel getInstance];
                if (dataModel.globalSettings.accountType == AccountTypeDemo)
                {
                    [self handleDisplayPremiumFeatureAlert:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDoctorPharmacy", @"Dosecast", [DosecastUtil getResourceBundle], @"Doctor and pharmacy tracking are available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])];
                }
                else
                {
                    // Display text entry view for prescription num
                    
                    TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                               initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                               bundle:[DosecastUtil getResourceBundle]
                                                               viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPrescriptionNumber", @"Dosecast", [DosecastUtil getResourceBundle], @"Prescription #", @"The Prescription Number label in the Drug Edit view"])
                                                               numTextFields:1
                                                               multiline:NO
                                                               initialValues:[NSArray arrayWithObject:[NSString stringWithString:prescriptionNum]]
                                                               placeholderStrings:[NSArray arrayWithObject:NSLocalizedStringWithDefaultValue(@"ViewDrugEditPrescriptionNumber", @"Dosecast", [DosecastUtil getResourceBundle], @"Prescription #", @"The Prescription Number label in the Drug Edit view"])]
                                                               capitalizationType:UITextAutocapitalizationTypeSentences
                                                               correctionType:UITextAutocorrectionTypeYes
                                                               keyboardType:UIKeyboardTypeDefault
                                                               secureTextEntry:NO
                                                               identifier:TextEntryPrescriptionNumId
                                                               subIdentifier:nil
                                                               delegate:self];
                    [self.navigationController pushViewController:textController animated:YES];
                }
            }
        }
    }
    else if (section == DrugAddEditViewControllerSectionsNotes)
    {
        TextEntryViewController* textController = [[TextEntryViewController alloc]
                                                   initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TextEntryViewController"]
                                                   bundle:[DosecastUtil getResourceBundle]
                                                   viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugEditNotes", @"Dosecast", [DosecastUtil getResourceBundle], @"Notes", @"The Notes label in the Drug Edit view"])
                                                   numTextFields:1
                                                   multiline:YES
                                                   initialValues:[NSArray arrayWithObject:[NSString stringWithString:notes]]
                                                   placeholderStrings:nil
                                                   capitalizationType:UITextAutocapitalizationTypeSentences
                                                   correctionType:UITextAutocorrectionTypeYes
                                                   keyboardType:UIKeyboardTypeDefault
                                                   secureTextEntry:NO
                                                   identifier:TextEntryNotesId
                                                   subIdentifier:nil
                                                   delegate:self];
        [self.navigationController pushViewController:textController animated:YES];
    }
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


- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DrugImageAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ContactsHelperAddressBookAccessGranted object:nil];
}


@end
