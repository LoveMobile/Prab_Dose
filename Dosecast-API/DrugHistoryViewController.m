//
//  DrugHistoryViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugHistoryViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "Drug.h"
#import "HistoryManager.h"
#import "HistoryDateEvents.h"
#import "EditableHistoryEvent.h"
#import "CustomNameIDList.h"
#import "HistoryAddEditEventViewController.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "LocalNotificationManager.h"
#import "LogManager.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static int TIME_LABEL_Y_SHIFT = 15;
static const CGFloat LABEL_BASE_HEIGHT = 16.1f;
static const CGFloat CELL_MIN_HEIGHT = 55.0f;
static const float epsilon = 0.0001;
static NSString *RefillQuantityKey = @"refillAmount";

@implementation DrugHistoryViewController

@synthesize tableView;
@synthesize timeTableViewCell;
@synthesize noteTableViewCell;
@synthesize addEntryTableViewCell;

- (void) refreshHistoryDateEventsList
{
    HistoryManager* historyManager = [HistoryManager getInstance];
    DataModel* dataModel = [DataModel getInstance];

    if (drugId)
    {
        [historyDateEventsList setArray:
         [historyManager getHistoryDateEventsForDrugIds:[NSArray arrayWithObject:drugId]
                                  includePostponeEvents:dataModel.globalSettings.postponesDisplayed
                                           errorMessage:nil]];
    }
    else
    {
        [historyDateEventsList setArray:
         [historyManager getHistoryDateEventsForDrugIds:[dataModel findDrugIdsForPersonId:personId]
                                  includePostponeEvents:dataModel.globalSettings.postponesDisplayed
                                           errorMessage:nil]];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil
                          bundle:nibBundleOrNil
                        personId:nil
                          drugId:nil];
}

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
             personId:(NSString*)pId
               drugId:(NSString*)Id
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        drugId = Id;
        personId = pId;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

		historyDateEventsList = [[NSMutableArray alloc] init];
		
        [self refreshHistoryDateEventsList];
		deletedEvents = [[NSMutableArray alloc] init];
		insertedEvents = [[NSMutableArray alloc] init];
		editedIndexPath = nil;
		isEditing = NO;
        refreshNeeded = NO;
        exampleTimeTableViewCell = nil;
        quantityRemainingOffsetByDrugId = [[NSMutableDictionary alloc] init];
        refillRemainingOffsetByDrugId = [[NSMutableDictionary alloc] init];
        editButton = nil;
        
        // Populate the date of the most recent SetInventory event for each drug, and initialize the drug quantity offset for each
        NSArray* possibleDrugIds = nil;
        if (drugId)
            possibleDrugIds = [NSArray arrayWithObject:drugId];
        else
            possibleDrugIds = [self getDrugIDsForPersonID];
        
        for (NSString* dId in possibleDrugIds)
        {
            [quantityRemainingOffsetByDrugId setObject:[NSNumber numberWithFloat:0.0f] forKey:dId];
            [refillRemainingOffsetByDrugId setObject:[NSNumber numberWithInt:0] forKey:dId];
        }
        
        DataModel* dataModel = [DataModel getInstance];
        self.hidesBottomBarWhenPushed = ![dataModel.apiFlags getFlag:DosecastAPIShowHistoryToolbar];

        // Get notified by adding a notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:DataModelDataRefreshNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:HistoryManagerHistoryEditedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeleteAllData:)
                                                     name:DataModelDeleteAllDataNotification
                                                   object:nil];
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"History", @"The title of the Drug History view"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

	tableView.sectionHeaderHeight = 22;
	tableView.sectionFooterHeight = 22;
	tableView.allowsSelection = YES;
	tableView.allowsSelectionDuringEditing = YES;
	
    // If we've been asked to not show the history toolbar, display the email button in the top-left toolbar
    DataModel* dataModel = [DataModel getInstance];
    if (![dataModel.apiFlags getFlag:DosecastAPIShowHistoryToolbar])
    {
        UIBarButtonItem* emailButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryButtonEmail", @"Dosecast", [DosecastUtil getResourceBundle], @"Email", @"The text on the email toolbar button in the Drug History view"])
                                                                         style:UIBarButtonItemStyleBordered target:self action:@selector(handleEmail:)];
        self.navigationItem.leftBarButtonItem = emailButton;
    }
    
	NSString* editButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonEdit", @"Dosecast", [DosecastUtil getResourceBundle], @"Edit", @"The text on the Edit toolbar button"]);
	editButton = [[UIBarButtonItem alloc] initWithTitle:editButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleEdit:)];
	self.navigationItem.rightBarButtonItem = editButton;
	
	// Setup toolbar with mail button
    if ([dataModel.apiFlags getFlag:DosecastAPIShowHistoryToolbar])
    {
        NSString *mailIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Mail.png"];
        UIImage* mailIconImage = [[UIImage alloc] initWithContentsOfFile:mailIconFilePath];
        UIBarButtonItem* mailButton = [[UIBarButtonItem alloc] initWithImage:mailIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleEmail:)];
            
        UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *flexSpaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, mailButton, flexSpaceButton2, nil];
    }
    
    // Load an example cell
    [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugHistoryTimeTableViewCell" owner:self options:nil];
    exampleTimeTableViewCell = timeTableViewCell;
    timeTableViewCell = nil;
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

    if (isEditing)
        screenWidth -= 100; // Remove space for disclosure indicator and delete button
    
    exampleTimeTableViewCell.frame = CGRectMake(exampleTimeTableViewCell.frame.origin.x, exampleTimeTableViewCell.frame.origin.y, screenWidth, exampleTimeTableViewCell.frame.size.height);

    [exampleTimeTableViewCell layoutIfNeeded];
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


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)handleHistoryEditedNotification:(NSNotification *)notification
{           
    // Update the table if we're not editing. (If we are, this will be handled up when editing finishes.)
    if (isEditing)
        refreshNeeded = YES;
    else
    {
        [self refreshHistoryDateEventsList];
        [self.tableView reloadData];
    }
}

- (void)handleDeleteAllData:(NSNotification *)notification
{
    // Cancel out of editing
    if (isEditing)
        [self handleCancel:nil];
}

- (void) setMailComposeViewControllerColors:(MFMailComposeViewController*)mailController
{
    NSMutableDictionary* titleTextAttributes = [NSMutableDictionary dictionaryWithDictionary:mailController.navigationBar.titleTextAttributes];
    [titleTextAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    
    mailController.navigationBar.titleTextAttributes = titleTextAttributes;
    
    [mailController.navigationBar setBarTintColor:[DosecastUtil getNavigationBarColor]];
    [mailController.navigationBar setTintColor:[UIColor whiteColor]];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    if (result == MFMailComposeResultFailed && error != nil)
    {
        NSString* errorAlertTitle = NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Error Sending Email", @"The title of the alert when an error occurs sending an email"]);
        NSString* errorAlertMessage = NSLocalizedStringWithDefaultValue(@"ErrorSendingEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your email could not be sent as a result of the following error: %@.", @"The message of the alert when an email can't be sent"]);
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:errorAlertTitle message:[NSString stringWithFormat:errorAlertMessage, [error localizedDescription]] style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          [self dismissViewControllerAnimated:YES completion:nil];
                                      }]];
        
        [alert showInViewController:self];
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void) composeEmailWithHistoryInBody:(NSTimer*)theTimer
{    
    DataModel* dataModel = [DataModel getInstance];
    
	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	NSMutableString* subject = nil;
	NSString* body = nil;

	if (drugId)
	{
        body = [dataModel getDrugHistoryStringForDrug:drugId];
		Drug* d = [dataModel findDrugWithId:drugId];
		subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistorySubjectDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ Dose History in %@", @"The subject of the email containing the history for a particular drug"]), d.name, [DosecastUtil getProductAppName]];		
	}
	else
	{
        body = [dataModel getDrugHistoryStringForPersonId:personId];
		subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistorySubjectAll", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose History in %@", @"The subject of the email containing the history for all drugs"]), [DosecastUtil getProductAppName]];
	}
	[mailController setSubject:subject];
	[mailController setMessageBody:body isHTML:NO];
	
	[dataModel allowDosecastUserInteractionsWithMessage:NO];

    [self setMailComposeViewControllerColors:mailController];

    [self presentViewController:mailController animated:YES completion:nil];
}

- (void) composeEmailWithCSVHistory:(NSTimer*)theTimer
{
	DataModel* dataModel = [DataModel getInstance];

	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	
	NSMutableString* subject = nil;
	NSData* drugHistoryCSVFile = nil;
	NSString* errorMessage = nil;
	NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
	NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
	NSString* historyDurationUnit = nil;

	if ([DosecastUtil shouldUseSingularForInteger:dataModel.globalSettings.doseHistoryDays])
		historyDurationUnit = daySingular;
	else
		historyDurationUnit = dayPlural;	
    
    NSString* personName = nil;
    if (!personId || [personId length] == 0)
        personName = [NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]) lowercaseString];
    else
        personName = [dataModel.globalSettings.personNames nameForGuid:personId];

	if (drugId)
	{
		Drug* d = [dataModel findDrugWithId:drugId];
		subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistorySubjectDrug", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ Dose History in %@", @"The subject of the email containing the history for a particular drug"]), d.name, [DosecastUtil getProductAppName]];		
		drugHistoryCSVFile = [[HistoryManager getInstance] getDoseHistoryAsCSVFileForDrugIds:[NSArray arrayWithObject:drugId] includePostponeEvents:dataModel.globalSettings.postponesDisplayed errorMessage:&errorMessage];
		if (drugHistoryCSVFile)
		{
			NSString* headerForEvents = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugEventsCSV", @"Dosecast", [DosecastUtil getResourceBundle], @"Attached is the %@ dose history for %@ over the last %d %@.", @"The header in the body of the email attaching the CSV history for a particular drug when there are some events"])];
			[mailController setMessageBody:[NSString stringWithFormat:headerForEvents, d.name, personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit] isHTML:NO];
		}
		else
		{
			NSString* headerForNoEvents = [NSString stringWithString:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No %@ dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for a particular drug when there are no events"])];
			[mailController setMessageBody:[NSString stringWithFormat:headerForNoEvents, d.name, personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit] isHTML:NO];
		}
	}
	else
	{
		subject = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistorySubjectAll", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose History in %@", @"The subject of the email containing the history for all drugs"]), [DosecastUtil getProductAppName]];
		drugHistoryCSVFile = [[HistoryManager getInstance] getDoseHistoryAsCSVFileForDrugIds:[dataModel findDrugIdsForPersonId:personId]
                                                                       includePostponeEvents:dataModel.globalSettings.postponesDisplayed
                                                                                errorMessage:&errorMessage];
		if (drugHistoryCSVFile)
		{
			NSMutableString* headerForEvents = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllEventsCSV", @"Dosecast", [DosecastUtil getResourceBundle], @"Attached is the dose history for %@ over the last %d %@.", @"The header in the body of the email attaching the CSV history for all drugs when there are some events"]), personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
			[mailController setMessageBody:headerForEvents isHTML:NO];
		}
		else
		{
			NSString* headerForNoEvents = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for all drugs when there are no events"]), personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
			[mailController setMessageBody:headerForNoEvents isHTML:NO];
		}
	}
	
	[mailController setSubject:subject];

	if (drugHistoryCSVFile)
	{
		[mailController addAttachmentData:drugHistoryCSVFile mimeType:@"text/csv" fileName:
		 NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryCSVFilename", @"Dosecast", [DosecastUtil getResourceBundle], @"DoseHistory.csv", @"The CSV filename of the exported drug history"])];
	}
	
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:NO];
	
    [self setMailComposeViewControllerColors:mailController];

    [self presentViewController:mailController animated:YES completion:nil];
}

- (void) handleDisplayEmailOptions:(id)sender
{
    DosecastAlertController* emailConfirmController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [emailConfirmController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [emailConfirmController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonSendHistoryInEmailBody", @"Dosecast", [DosecastUtil getResourceBundle], @"Send History In Email Body", @"The text on the Send History In Email Body button in an alert"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerCollectingInformation", @"Dosecast", [DosecastUtil getResourceBundle], @"Collecting information", @"The message appearing in the spinner view when collecting information"])];
                                      
                                      [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(composeEmailWithHistoryInBody:) userInfo:nil repeats:NO];
                                  }]];

    [emailConfirmController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonSendHistoryInCSVFile", @"Dosecast", [DosecastUtil getResourceBundle], @"Send History In CSV File", @"The text on the Send History In CSV File button in an alert"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerCollectingInformation", @"Dosecast", [DosecastUtil getResourceBundle], @"Collecting information", @"The message appearing in the spinner view when collecting information"])];
                                      
                                      [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(composeEmailWithCSVHistory:) userInfo:nil repeats:NO];
                                  }]];

    [emailConfirmController showInViewController:self sourceBarButtonItem:(UIBarButtonItem*)sender];
}

- (void)handleDelete:(id)sender
{
    DosecastAlertController* deleteConfirmController = [DosecastAlertController alertControllerWithTitle:nil message:nil style:DosecastAlertControllerStyleActionSheet];
    
    [deleteConfirmController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    
    [deleteConfirmController addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonDeleteHistory", @"Dosecast", [DosecastUtil getResourceBundle], @"Delete History", @"The text on the Delete History button in an alert"])
                                    style:DosecastAlertActionStyleDefault
                                  handler:^(DosecastAlertAction *action) {
                                      // Build the set of deleted sections and build the list of events to delete
                                      NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
                                      
                                      int numHistoryDateEvents = (int)[historyDateEventsList count];
                                      for (int i = 0; i < numHistoryDateEvents; i++)
                                      {
                                          [deletedSections addIndex:i+1]; // leave section 0
                                          
                                          HistoryDateEvents* historyDateEvents = [historyDateEventsList objectAtIndex:i];
                                          [deletedEvents addObjectsFromArray:historyDateEvents.editableHistoryEvents];
                                      }
                                      
                                      [historyDateEventsList removeAllObjects];
                                      
                                      [tableView beginUpdates];
                                      
                                      [tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
                                      
                                      [tableView endUpdates];
                                  }]];
    
    [deleteConfirmController showInViewController:self sourceBarButtonItem:(UIBarButtonItem*)sender];
}


- (void)setupEditing:(BOOL)edit
{
	if (edit)
	{
		// Set Cancel button
		UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
		self.navigationItem.leftBarButtonItem = cancelButton;
		
		// Set Done button
		NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
		UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
		self.navigationItem.rightBarButtonItem = doneButton;
				
		[tableView setEditing:YES animated:YES];
		isEditing = YES;
				
		// Setup toolbar with delete button
		NSString *deleteIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Trash.png"];
		UIImage* deleteIconImage = [[UIImage alloc] initWithContentsOfFile:deleteIconFilePath];
		UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithImage:deleteIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleDelete:)];
		
		UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *flexSpaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, deleteButton, flexSpaceButton2, nil];
        
        [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't let a background sync conflict with any editing of history events
	}
	else
	{
		self.navigationItem.rightBarButtonItem = editButton;
				
        if (![[DataModel getInstance].apiFlags getFlag:DosecastAPIShowHistoryToolbar])
        {
            UIBarButtonItem* emailButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryButtonEmail", @"Dosecast", [DosecastUtil getResourceBundle], @"Email", @"The text on the email toolbar button in the Drug History view"])
                                                                             style:UIBarButtonItemStyleBordered target:self action:@selector(handleEmail:)];
            self.navigationItem.leftBarButtonItem = emailButton;
        }
        else
            self.navigationItem.leftBarButtonItem = nil;	
		
		[tableView setEditing:NO animated:YES];
		isEditing = NO;
				
		// Setup toolbar with mail button
		NSString *mailIconFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], @"/Mail.png"];
		UIImage* mailIconImage = [[UIImage alloc] initWithContentsOfFile:mailIconFilePath];
		UIBarButtonItem *mailButton = [[UIBarButtonItem alloc] initWithImage:mailIconImage style:UIBarButtonItemStylePlain target:self action:@selector(handleEmail:)];		
		
		UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *flexSpaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, mailButton, flexSpaceButton2, nil];
        
        [[LogManager sharedManager] endPausingBackgroundSync]; // Resume background sync
	}
}

- (void) updateRowSelection
{
	int numSections = (int)[historyDateEventsList count];
	for (int i = 0; i < numSections; i++)
	{
		HistoryDateEvents* dateEvents = [historyDateEventsList objectAtIndex:i];
		int numRows = (int)[dateEvents.editableHistoryEvents count];
		for (int j = 0; j < numRows; j++)
		{
            EditableHistoryEvent* event = [dateEvents.editableHistoryEvents objectAtIndex:j];

			NSIndexPath* path = [NSIndexPath indexPathForRow:j inSection:i+1];
			UITableViewCell* cell = [tableView cellForRowAtIndexPath:path];
            
            if (isEditing && event.drugId) // only allow cells corresponding to events with a drug ID to be selected
            {
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            else
            {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.editingAccessoryType = UITableViewCellAccessoryNone;
            }
		}
	}
}

- (void)deleteEditableHistoryEventAtIndexPath:(NSIndexPath*)indexPath
{
	if ((indexPath.section-1) < [historyDateEventsList count])
	{
		HistoryDateEvents* historyDateEvents = [historyDateEventsList objectAtIndex:(indexPath.section-1)];
		if (indexPath.row < [historyDateEvents.editableHistoryEvents count])
		{			
			[historyDateEvents.editableHistoryEvents removeObjectAtIndex:indexPath.row];
			if ([historyDateEvents.editableHistoryEvents count] == 0)
			{
				[historyDateEventsList removeObjectAtIndex:(indexPath.section-1)];
				[self.tableView	deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationLeft];
			}
			else
				[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];							
			
		}
	}
}

// Inserts the given editable history event into the given list of history date events
- (void) insertEditableHistoryEvent:(EditableHistoryEvent*)event
{
	if (!event)
		return;
	
	int numDateEvents = (int)[historyDateEventsList count];
	NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |
	NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	
	NSDate* eventDay = [DosecastUtil getMidnightOnDate:event.creationDate];
    NSDateComponents* eventDateComponents = [cal components:unitFlags fromDate:eventDay];

	BOOL foundDate = NO;
	for (int i = numDateEvents-1; i >= 0 && !foundDate; i--)
	{
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:i];
		
		// Decide whether to add this event to the current dateEvents object or create a new one
		NSDate* thisDay = [DosecastUtil getMidnightOnDate:events.creationDate];
		NSDateComponents* thisDateComponents = [cal components:unitFlags fromDate:thisDay];
		
		// An exact match for the day
		if ([thisDateComponents day] == [eventDateComponents day] &&
			[thisDateComponents month] == [eventDateComponents month] &&
			[thisDateComponents year] == [eventDateComponents year])
		{
			foundDate = YES;
			int numEvents = (int)[events.editableHistoryEvents count];
			BOOL foundTime = NO;
			
			for (int j = numEvents-1; j >= 0 && !foundTime; j--)
			{
				EditableHistoryEvent* thisEvent = [events.editableHistoryEvents objectAtIndex:j];
				if ([event.creationDate timeIntervalSinceDate:thisEvent.creationDate] < 0)
				{
					foundTime = YES;
					[events.editableHistoryEvents insertObject:event atIndex:(j+1)];
					[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:(j+1) inSection:(i+1)]] withRowAnimation:UITableViewRowAnimationRight];
				}
			}
			
			if (!foundTime)
			{
				[events.editableHistoryEvents insertObject:event atIndex:0];
				[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:(i+1)]] withRowAnimation:UITableViewRowAnimationRight];
			}
		}
		// Needs to be inserted here
		else if ([eventDay timeIntervalSinceDate:thisDay] < 0)
		{
			foundDate = YES;
			[historyDateEventsList insertObject:[HistoryDateEvents historyDateEventsWithEditableHistoryEvent:event]
										atIndex:(i+1)];	
			[tableView insertSections:[NSIndexSet indexSetWithIndex:(i+2)] withRowAnimation:UITableViewRowAnimationRight];
		}
	}
	
	if (!foundDate)
	{
		[historyDateEventsList insertObject:[HistoryDateEvents historyDateEventsWithEditableHistoryEvent:event]
									atIndex:0];			
		[tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationRight];
	}	
}

- (BOOL)handleAddEditEventComplete:(NSString*)eventDrugId
                        actionName:(NSString*)actionName
                postponePeriodSecs:(int)postponePeriodSecs
                         eventTime:(NSDate*)eventTime
                     scheduledTime:(NSDate*)scheduledTime
                      refillAmount:(float)refillAmount
{
    if (editedIndexPath) // if we're editing an existing event
    {
        BOOL isFuture = [eventTime timeIntervalSinceNow] > 0;
        
        if (isFuture)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Invalid Time", @"The title to display in alert appearing when the user selects an invalid dose time"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorDoseTimeInvalidMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please select a time in the past.", @"The message to display in alert appearing when the user selects an invalid dose time"])];
            [alert showInViewController:self];
        }
        else
        {
            if (eventTime && (editedIndexPath.section-1) < [historyDateEventsList count])
            {
                HistoryDateEvents* historyDateEvents = [historyDateEventsList objectAtIndex:(editedIndexPath.section-1)];
                
                if (editedIndexPath.row < [historyDateEvents.editableHistoryEvents count])
                {
                    DataModel* dataModel = [DataModel getInstance];
                    Drug* d = [dataModel findDrugWithId:eventDrugId];
                    
                    EditableHistoryEvent* editedEvent = [historyDateEvents.editableHistoryEvents objectAtIndex:editedIndexPath.row];
                    editedEvent.creationDate = eventTime;
                    editedEvent.operation = actionName;
                    editedEvent.scheduleDate = scheduledTime;
                    BOOL drugChanged = ([editedEvent.drugId compare:eventDrugId options:NSLiteralSearch] != NSOrderedSame);
                    editedEvent.drugId = eventDrugId;
                    if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
                        editedEvent.operationData = [NSString stringWithFormat:@"%d", postponePeriodSecs];
                    else
                        editedEvent.operationData = nil;
                    if ([actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
                    {
                        NSString* refillAmountStr = [NSString stringWithFormat:@"%.2f", refillAmount];
                        [editedEvent replaceDosageTypePrefValue:RefillQuantityKey withValue:refillAmountStr];
                    }
                    if (drugChanged)
                        [editedEvent setDosageTypeToDrugDosage:d.dosage];
                    editedEvent.eventDescription = nil;
                    [tableView beginUpdates];
                    
                    [self deleteEditableHistoryEventAtIndexPath:editedIndexPath];
                    [self insertEditableHistoryEvent:editedEvent];
                    
                    [tableView endUpdates];
                    
                }
            }
            
            editedIndexPath = nil;
        }
        
        return !isFuture;	
    }
    else // we're creating a new event
    {
        NSString* operationData = nil;
        if ([actionName caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame)
            operationData = [NSString stringWithFormat:@"%d", postponePeriodSecs];

        DrugDosage* dosage = nil;
        if ([actionName caseInsensitiveCompare:HistoryManagerRefillOperationName] == NSOrderedSame)
        {
            DataModel* dataModel = [DataModel getInstance];
            Drug* d = [dataModel findDrugWithId:eventDrugId];
            dosage = [d.dosage mutableCopy];
            [dosage setValueForRefillQuantity:refillAmount];
        }

        EditableHistoryEvent* event = [EditableHistoryEvent editableHistoryEvent:eventDrugId
                                                                    creationDate:eventTime
                                                                       operation:actionName
                                                                   operationData:operationData
                                                                    scheduleDate:scheduledTime
                                                                          dosage:dosage];
        
        [tableView beginUpdates];
        
        [self insertEditableHistoryEvent:event];
        [insertedEvents addObject:event];
        
        [tableView endUpdates];
        
        return YES;
    }
}

- (void)handleCancelAddEditEvent
{
    if (editedIndexPath)
    {
        editedIndexPath = nil;    
    }
}

- (void)handleEdit:(id)sender
{	
	[self setupEditing:YES];
	
	[self updateRowSelection];
	
	int numHistoryDateEvents = (int)[historyDateEventsList count];
    
    [tableView beginUpdates];
    
    // Refresh the note row
    [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
    
    [self handleRefreshNonNoteSections:numHistoryDateEvents numNewHistoryDateEvents:numHistoryDateEvents];
    
    [tableView endUpdates];
}

// Refresh all but the note sections when the number of sections changes
- (void)handleRefreshNonNoteSections:(int)numOldHistoryDateEvents numNewHistoryDateEvents:(int)numNewHistoryDateEvents
{    	
	// Determine whether to delete or insert sections. Also reload all other sections.
	if (numOldHistoryDateEvents > numNewHistoryDateEvents)
	{
		NSMutableIndexSet* reloadSections = [NSMutableIndexSet indexSet];
		for (int i = 0; i < numNewHistoryDateEvents; i++)
			[reloadSections addIndex:i+1]; // leave section 0
        
		NSMutableIndexSet* deletedSections = [NSMutableIndexSet indexSet];
		for (int i = numNewHistoryDateEvents; i < numOldHistoryDateEvents; i++)
			[deletedSections addIndex:i+1]; // leave section 0
		
		[tableView reloadSections:reloadSections withRowAnimation:UITableViewRowAnimationLeft];
		[tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationLeft];
	}
	else if (numOldHistoryDateEvents < numNewHistoryDateEvents)
	{
		NSMutableIndexSet* reloadSections = [NSMutableIndexSet indexSet];
		for (int i = 0; i < numOldHistoryDateEvents; i++)
			[reloadSections addIndex:i+1]; // leave section 0
		
		NSMutableIndexSet* insertedSections = [NSMutableIndexSet indexSet];
		for (int i = numOldHistoryDateEvents; i < numNewHistoryDateEvents; i++)
			[insertedSections addIndex:i+1]; // leave section 0
		
		[tableView reloadSections:reloadSections withRowAnimation:UITableViewRowAnimationLeft];
		[tableView insertSections:insertedSections withRowAnimation:UITableViewRowAnimationRight];
	}
	else
	{
		NSMutableIndexSet* reloadSections = [NSMutableIndexSet indexSet];
		for (int i = 0; i < numNewHistoryDateEvents; i++)
			[reloadSections addIndex:i+1]; // leave section 0
		
		[tableView reloadSections:reloadSections withRowAnimation:UITableViewRowAnimationLeft];
	}    
}

- (void)handleCancel:(id)sender
{
	[self setupEditing:NO];
				
	int numOldHistoryDateEvents = (int)[historyDateEventsList count];
	   
    [[HistoryManager getInstance] beginBatchUpdates];

	// Delete all inserted events
	for (EditableHistoryEvent* event in insertedEvents)
	{
		[event deleteFromHistory];
	}
	
    [[HistoryManager getInstance] endBatchUpdates:YES];

    [self refreshHistoryDateEventsList];
    
	int numNewHistoryDateEvents = (int)[historyDateEventsList count];
		
    [tableView beginUpdates];

    // Refresh the note row
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
    
    [self handleRefreshNonNoteSections:numOldHistoryDateEvents numNewHistoryDateEvents:numNewHistoryDateEvents];
    
    [tableView endUpdates];

	[insertedEvents removeAllObjects];	
	[deletedEvents removeAllObjects];		

	[self updateRowSelection];
    
    refreshNeeded = NO;
}

- (NSSet*) updateQuantityRefillsRemainingOffsetForEvent:(EditableHistoryEvent*)event
{
    NSMutableSet* affectedDrugIds = [[NSMutableSet alloc] init];
    float remainingQuantityOffsetA = 0.0f;
    int refillQuantityOffsetA = 0;
    float remainingQuantityOffsetB = 0.0f;
    int refillQuantityOffsetB = 0;
    NSString *drugIdA = nil;
    NSString *drugIdB = nil;
    
    // Calculate the offset to the remaining quantity and refill quantity for 1-2 affected drugs
    [event getOffsetToRemainingRefillQuantityForDrug:&drugIdA remainingQuantityOffset:&remainingQuantityOffsetA refillQuantityOffset:&refillQuantityOffsetA
                                          andForDrug:&drugIdB remainingQuantityOffset:&remainingQuantityOffsetB refillQuantityOffset:&refillQuantityOffsetB];

    if (drugIdA)
    {
        [affectedDrugIds addObject:drugIdA];
    
        if (fabsf(remainingQuantityOffsetA) > epsilon)
        {
            NSNumber* currOffset = [quantityRemainingOffsetByDrugId objectForKey:drugIdA];
            if (currOffset)
                [quantityRemainingOffsetByDrugId setObject:[NSNumber numberWithFloat:[currOffset floatValue]+remainingQuantityOffsetA] forKey:drugIdA];
        }

        if (abs(refillQuantityOffsetA) > 0)
        {
            NSNumber* currOffset = [refillRemainingOffsetByDrugId objectForKey:drugIdA];
            if (currOffset)
                [refillRemainingOffsetByDrugId setObject:[NSNumber numberWithInt:[currOffset intValue]+refillQuantityOffsetA] forKey:drugIdA];
        }
    }
    
    if (drugIdB)
    {
        [affectedDrugIds addObject:drugIdB];
        
        if (fabsf(remainingQuantityOffsetB) > epsilon)
        {
            NSNumber* currOffset = [quantityRemainingOffsetByDrugId objectForKey:drugIdB];
            if (currOffset)
                [quantityRemainingOffsetByDrugId setObject:[NSNumber numberWithFloat:[currOffset floatValue]+remainingQuantityOffsetB] forKey:drugIdB];
        }
        
        if (abs(refillQuantityOffsetB) > 0)
        {
            NSNumber* currOffset = [refillRemainingOffsetByDrugId objectForKey:drugIdB];
            if (currOffset)
                [refillRemainingOffsetByDrugId setObject:[NSNumber numberWithInt:[currOffset intValue]+refillQuantityOffsetB] forKey:drugIdB];
        }
    }
    
    return affectedDrugIds;
}

- (void) updateQuantityRefillsRemainingOffsetForDrug:(NSString*)dId
{
    Drug* d = [[DataModel getInstance] findDrugWithId:dId];
    
    DrugDosage* dosage = [d.dosage mutableCopy];
    
    float remainingQuantityOffset = 0.0f;
    int refillQuantityOffset = 0;
    NSNumber* remainingQuantityOffsetNum = [quantityRemainingOffsetByDrugId objectForKey:dId];
    if (remainingQuantityOffsetNum)
        remainingQuantityOffset = [remainingQuantityOffsetNum floatValue];
    NSNumber* refillQuantityOffsetNum = [refillRemainingOffsetByDrugId objectForKey:dId];
    if (refillQuantityOffsetNum)
        refillQuantityOffset = [refillQuantityOffsetNum intValue];
    
    // Update remaining quantity and refills remaining, if they were changed
    if (fabsf(remainingQuantityOffset) > epsilon)
    {
        float remainingQuantity = 0.0f;
        [dosage getValueForRemainingQuantity:&remainingQuantity];
        [dosage setValueForRemainingQuantity:remainingQuantity + remainingQuantityOffset];
    }
    
    if (abs(refillQuantityOffset) > 0)
    {
        int refillQuantity = [dosage getRefillsRemaining];
        [dosage setRefillsRemaining:refillQuantity + refillQuantityOffset];
    }
    
    [[LocalNotificationManager getInstance] editPill:d.drugId
                                            drugName:d.name
                                           imageGUID:d.drugImageGUID
                                            personId:d.personId
                                          directions:d.directions
                                       doctorContact:d.doctorContact
                                     pharmacyContact:d.pharmacyContact
                                     prescriptionNum:d.prescriptionNum
                                        drugReminder:d.reminder
                                          drugDosage:dosage
                                               notes:d.notes
                                undoHistoryEventGUID:d.undoHistoryEventGUID
                                        updateServer:NO
                                           respondTo:nil
                                               async:NO];
    
    [quantityRemainingOffsetByDrugId setObject:[NSNumber numberWithFloat:0.0f] forKey:dId];
    [refillRemainingOffsetByDrugId setObject:[NSNumber numberWithInt:0] forKey:dId];
}

- (void)handleDoneAsync:(NSTimer*)theTimer
{
    [self setupEditing:NO];
    
    NSMutableSet* affectedDrugIds = [[NSMutableSet alloc] init];
    
    HistoryManager* historyManager = [HistoryManager getInstance];
    [historyManager beginBatchUpdates];
    
    int numOldHistoryDateEvents = (int)[historyDateEventsList count];
    
    // Commit all changes to events
    for (HistoryDateEvents* historyDateEvents in historyDateEventsList)
    {
        for (EditableHistoryEvent* event in historyDateEvents.editableHistoryEvents)
        {
            if (event.changed)
            {
                NSSet* theseAffectedDrugIds = [self updateQuantityRefillsRemainingOffsetForEvent:event];
                [affectedDrugIds unionSet:theseAffectedDrugIds];
                [event commitChanges];
            }
        }
    }
    
    // Commit all deletes
    for (EditableHistoryEvent* event in deletedEvents)
    {
        NSSet* theseAffectedDrugIds = [self updateQuantityRefillsRemainingOffsetForEvent:event];
        [affectedDrugIds unionSet:theseAffectedDrugIds];

        [event deleteFromHistory];
    }
    
    int numNewHistoryDateEvents = numOldHistoryDateEvents;
    if (refreshNeeded)
    {
        [self refreshHistoryDateEventsList];
        
        numNewHistoryDateEvents = (int)[historyDateEventsList count];
    }
    
    [tableView beginUpdates];
    
    // Refresh the note row
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
    
    if (refreshNeeded)
        [self handleRefreshNonNoteSections:numOldHistoryDateEvents numNewHistoryDateEvents:numNewHistoryDateEvents];
    
    [tableView endUpdates];
    
    [deletedEvents removeAllObjects];
    [insertedEvents removeAllObjects];
    
    [self updateRowSelection];
    
    [historyManager endBatchUpdates:YES];
    
    [[LocalNotificationManager getInstance] beginBatchUpdates];
    
    for (NSString* dId in affectedDrugIds)
    {
        // Edit this drug and do a getState, since deleting the history could have changed the effLastTaken
        // and we may need to update the quantity/refill remaining
        [self updateQuantityRefillsRemainingOffsetForDrug:dId];
    }
    
    [[LocalNotificationManager getInstance] getState:NO respondTo:nil async:NO];
    [[LocalNotificationManager getInstance] endBatchUpdates:NO];
    
    refreshNeeded = NO;
    
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
}

- (void)handleDone:(id)sender
{
    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];

    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDoneAsync:) userInfo:nil repeats:NO];
}

- (void)handleEmail:(id)sender
{
	if (![MFMailComposeViewController canSendMail])
	{
		DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Can't Send Email", @"The title of the alert when an email can't be sent"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorNoDeviceEmailMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Your device cannot currently send email. Please ensure you have 3G or WiFi connectivity and that email is not disabled.", @"The message of the alert when an email can't be sent because the device doesn't allow it"])];
		[alert showInViewController:self];
	}
	else
	{
        DataModel* dataModel = [DataModel getInstance];
        
        NSString* languageCode = [DosecastUtil getLanguageCode];
        if ([dataModel.apiFlags getFlag:DosecastAPIWarnOnEmailingDrugInfo] && [languageCode compare:@"en" options:NSLiteralSearch] == NSOrderedSame)
        {
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Privacy Warning", @"The title on the alert warning when emailing drug info"])
                                                                                       message:NSLocalizedStringWithDefaultValue(@"EmailDrugInfoPrivacyWarningMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"If you send this email, the personal health information shared within it will not be protected. Continue if you are sure you want to send this information in an email.", @"The message on the alert warning when emailing drug info"])
                                                                                         style:DosecastAlertControllerStyleAlert];
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonClose", @"Dosecast", [DosecastUtil getResourceBundle], @"Close", @"The text on the Close button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonContinue", @"Dosecast", [DosecastUtil getResourceBundle], @"Continue", @"The text on the Continue button in an alert"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction* action){
                                              // Open an action sheet to confirm the delete
                                              [self handleDisplayEmailOptions:sender];
                                          }]];
            
            [alert showInViewController:self];
        }
        else
        {
            // Open an action sheet to confirm the delete
            [self handleDisplayEmailOptions:sender];
        }
	}
}

- (NSArray*) getDrugIDsForPersonID
{
    DataModel* dataModel = [DataModel getInstance];
    NSMutableArray* drugIDs = [[NSMutableArray alloc] init];
    NSArray* drugList = dataModel.drugList;
    int numDrugs = (int)[drugList count];
    
    for (int i = 0; i < numDrugs; i++)
    {
        Drug* d = [drugList objectAtIndex:i];
        if (!d.reminder.invisible && [d.personId caseInsensitiveCompare:personId] == NSOrderedSame)
            [drugIDs addObject:d.drugId];
    }
    
    return drugIDs;
}
									
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    [self recalcExampleCellWidth];
    
    int numDrugIDs = 1;
    if (!drugId)
        numDrugIDs = (int)[[self getDrugIDsForPersonID] count];
    editButton.enabled = (numDrugIDs > 0);
    
	return [historyDateEventsList count]+1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
	if (section == 0)
	{
		if (isEditing)
			return 2;
		else
			return 1;
	}
	else
	{
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:section-1];
		return [events.editableHistoryEvents count];
	}
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{		    
	if (indexPath.section == 0)
	{	
		if (indexPath.row == 0)
		{
            DataModel* dataModel = [DataModel getInstance];
            UILabel* mainLabel = (UILabel *)[noteTableViewCell viewWithTag:1];
            NSMutableString* noteText = [NSMutableString stringWithString:@""];
            NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
            NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
            NSString* historyDurationUnit = nil;

            if ([DosecastUtil shouldUseSingularForInteger:dataModel.globalSettings.doseHistoryDays])
                historyDurationUnit = daySingular;
            else
                historyDurationUnit = dayPlural;
            
            NSString* personName = nil;
            if (!personId || [personId length] == 0)
                personName = [NSLocalizedStringWithDefaultValue(@"ViewDrugEditPersonMe", @"Dosecast", [DosecastUtil getResourceBundle], @"Me", @"The Me Person label in the Drug Edit view"]) lowercaseString];
            else
                personName = [dataModel.globalSettings.personNames nameForGuid:personId];

            if (drugId)
            {
                Drug* d = [dataModel findDrugWithId:drugId];
                if ([historyDateEventsList count] > 0)
                    [noteText appendFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ dose history for %@ over the last %d %@:", @"The header in the body of the email containing the history for a particular drug when there are some events"]), d.name, personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
                else
                    [noteText appendFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderDrugNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No %@ dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for a particular drug when there are no events"]), d.name, personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
            }
            else
            {
                if ([historyDateEventsList count] > 0)
                    [noteText appendFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllEvents", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose history for %@ over the last %d %@:", @"The header in the body of the email containing the history for all drugs when there are some events"]), personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
                else
                    [noteText appendFormat:NSLocalizedStringWithDefaultValue(@"EmailDrugHistoryHeaderAllNone", @"Dosecast", [DosecastUtil getResourceBundle], @"No dose history for %@ over the last %d %@.", @"The header in the body of the email containing the history for all drugs when there are no events"]), personName, dataModel.globalSettings.doseHistoryDays, historyDurationUnit];
            }
            mainLabel.text = noteText;
            return noteTableViewCell;				
		}
		else // if (indexPath.row == 1)
		{
			UILabel* mainLabel = (UILabel *)[addEntryTableViewCell viewWithTag:1];
			mainLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEntry", @"Dosecast", [DosecastUtil getResourceBundle], @"Add New Entry", @"The label appearing in the Add Entry option in the Drug History view"]);
			return addEntryTableViewCell;
		}
	}
	else
	{
		static NSString *MyIdentifier = @"PillCellIdentifier";
	
		UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
		if (cell == nil) {
			[[DosecastUtil getResourceBundle] loadNibNamed:@"DrugHistoryTimeTableViewCell" owner:self options:nil];
			cell = timeTableViewCell;
			timeTableViewCell = nil;
		}
		
        HistoryManager* historyManager = [HistoryManager getInstance];
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:indexPath.section-1];
		EditableHistoryEvent* event = [events.editableHistoryEvents objectAtIndex:indexPath.row];
        BOOL isEventLate = event.late && [event.operation caseInsensitiveCompare:HistoryManagerTakePillOperationName] == NSOrderedSame;
        
		// Set labels
		UILabel* timeLabel = (UILabel *)[cell viewWithTag:1];
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		timeLabel.text = [NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:event.creationDate]];
        timeLabel.frame = CGRectMake(timeLabel.frame.origin.x, (isEventLate ? [exampleTimeTableViewCell viewWithTag:1].frame.origin.y-TIME_LABEL_Y_SHIFT : [exampleTimeTableViewCell viewWithTag:1].frame.origin.y), timeLabel.frame.size.width, timeLabel.frame.size.height);
		
		UILabel* descriptionLabel = (UILabel *)[cell viewWithTag:2];
		descriptionLabel.text = [historyManager getEventDescriptionForHistoryEvent:event.drugId
                                                                         operation:event.operation
                                                                     operationData:event.operationData
                                                                        dosageType:event.dosageType
                                                                   preferencesDict:[event createHistoryEventPreferencesDict]
                                                            legacyEventDescription:event.eventDescription
                                                                   displayDrugName:YES];

        // Color the description for missed pills differently
        if ([event.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] == NSOrderedSame)
            descriptionLabel.textColor = [DosecastUtil getHistoryMissDoseLabelColor];
        else
            descriptionLabel.textColor = [UIColor blackColor];

        UILabel* lateLabel = (UILabel *)[cell viewWithTag:3];
        lateLabel.textColor = [DosecastUtil getHistoryLateDoseTextColor];
        lateLabel.hidden = !isEventLate;
        if (!lateLabel.hidden)
            lateLabel.text = [NSString stringWithFormat:@"%@ %@", [event latePeriodDescription], [NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryLateDose", @"Dosecast", [DosecastUtil getResourceBundle], @"Late", @"The label appearing under a late dose in the Drug History view"]) lowercaseString]];
        
        UIImageView* warningImage = (UIImageView*)[cell viewWithTag:4];
        if (warningImage)
            warningImage.hidden = ([event.operation caseInsensitiveCompare:HistoryManagerMissPillOperationName] != NSOrderedSame); // show the warning for missed pills only
        
		if (isEditing && event.drugId) // only allow cells corresponding to events with a drug ID to be selected
        {
			cell.selectionStyle = UITableViewCellSelectionStyleGray;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
		else
        {
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.editingAccessoryType = UITableViewCellAccessoryNone;
        }
		
		return cell;
	}
}

- (CGFloat) getHeightForCellLabelTag:(int)tag labelBaseHeight:(CGFloat)labelBaseHeight withString:(NSString*)value
{
    UILabel* label = (UILabel*)[exampleTimeTableViewCell viewWithTag:tag];
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
    if (indexPath.section == 0)
    {
        return 44;
    }
    else
    {
        HistoryManager* historyManager = [HistoryManager getInstance];
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:indexPath.section-1];
		EditableHistoryEvent* event = [events.editableHistoryEvents objectAtIndex:indexPath.row];
        
        NSString* eventDescription = [historyManager getEventDescriptionForHistoryEvent:event.drugId
                                                                         operation:event.operation
                                                                     operationData:event.operationData
                                                                        dosageType:event.dosageType
                                                                   preferencesDict:[event createHistoryEventPreferencesDict]
                                                            legacyEventDescription:event.eventDescription
                                                                   displayDrugName:YES];

        return (int)ceilf([self getHeightForCellLabelTag:2 labelBaseHeight:LABEL_BASE_HEIGHT withString:eventDescription]);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return nil;
	else
	{
		HistoryDateEvents* events = [historyDateEventsList objectAtIndex:section-1];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		return [dateFormatter stringFromDate:events.creationDate];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row

	if (!isEditing)
		return;	

	if (indexPath.section == 0 && indexPath.row == 1)
	{
        NSArray* possibleDrugIds = nil;
        if (drugId)
            possibleDrugIds = [NSArray arrayWithObject:drugId];
        else
            possibleDrugIds = [self getDrugIDsForPersonID];
        
		HistoryAddEditEventViewController* addEventController = [[HistoryAddEditEventViewController alloc]
															 initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"HistoryAddEditEventViewController"]
															 bundle:[DosecastUtil getResourceBundle]
                                                             viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEntry", @"Dosecast", [DosecastUtil getResourceBundle], @"Add New Entry", @"The label appearing in the Add Entry option in the Drug History view"])
															 drugId:nil
                                                             possibleDrugIds:possibleDrugIds
                                                             actionName:nil
                                                             eventTime:nil
                                                             scheduledTime:nil
                                                             postponePeriodSecs:-1
                                                             refillAmount:0.0f
															 delegate:self];
		[self.navigationController pushViewController:addEventController animated:YES];
	}
	else if ((indexPath.section-1) < [historyDateEventsList count])
	{        
		HistoryDateEvents* historyDateEvents = [historyDateEventsList objectAtIndex:(indexPath.section-1)];

		if (indexPath.row < [historyDateEvents.editableHistoryEvents count])
		{
			EditableHistoryEvent* selectedEvent = [historyDateEvents.editableHistoryEvents objectAtIndex:indexPath.row];
            
            if (selectedEvent.drugId) // don't allow an event to be edited if it doesn't have a drug ID
            {
                editedIndexPath = indexPath;

                NSArray* possibleDrugIds = nil;
                if (drugId)
                    possibleDrugIds = [NSArray arrayWithObject:drugId];
                else
                    possibleDrugIds = [self getDrugIDsForPersonID];

                int postponePeriodSecs = -1;
                if ([selectedEvent.operation caseInsensitiveCompare:HistoryManagerPostponePillOperationName] == NSOrderedSame &&
                    selectedEvent.operationData && [selectedEvent.operationData length] > 0)
                    postponePeriodSecs = [selectedEvent.operationData intValue];
                
                float refillAmount = 0.0f;
                if ([selectedEvent.operation isEqualToString:HistoryManagerRefillOperationName])
                {
                    NSString* refillAmountStr = [selectedEvent getDosageTypePrefValue:RefillQuantityKey];
                    if (refillAmountStr)
                        refillAmount = [refillAmountStr floatValue];
                }
                
                HistoryAddEditEventViewController* editEventController = [[HistoryAddEditEventViewController alloc]
                                                                         initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"HistoryAddEditEventViewController"]
                                                                         bundle:[DosecastUtil getResourceBundle]
                                                                         viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryEditEntry", @"Dosecast", [DosecastUtil getResourceBundle], @"Edit Entry", @"The label appearing in the Edit Entry option in the Drug History view"])
                                                                         drugId:selectedEvent.drugId
                                                                         possibleDrugIds:possibleDrugIds
                                                                         actionName:selectedEvent.operation
                                                                         eventTime:selectedEvent.creationDate
                                                                         scheduledTime:selectedEvent.scheduleDate
                                                                         postponePeriodSecs:postponePeriodSecs
                                                                          refillAmount:refillAmount
                                                                          delegate:self];
                [self.navigationController pushViewController:editEventController animated:YES];
            }
		}
	}
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
	if (indexPath.section == 0 && indexPath.row == 0)
		return NO;
    else
        return YES;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 && indexPath.row == 1)
		return UITableViewCellEditingStyleInsert;
	else
		return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!isEditing)
        [[LogManager sharedManager] beginPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!isEditing)
        [[LogManager sharedManager] endPausingBackgroundSync]; // Don't let a sync occur while an edit is happening
}

- (void)handleDeleteAsync:(NSTimer*)theTimer
{
    EditableHistoryEvent* deletedEvent = (EditableHistoryEvent*)theTimer.userInfo;
    
    [self updateQuantityRefillsRemainingOffsetForEvent:deletedEvent];
    NSString* thisDrugId = nil;
    if (deletedEvent.drugId)
        thisDrugId = [deletedEvent.drugId mutableCopy];
    
    [deletedEvent deleteFromHistory];
    
    [[LocalNotificationManager getInstance] beginBatchUpdates];
    
    if (thisDrugId)
    {
        // Edit this drug and do a getState, since deleting the history could have changed the effLastTaken
        // and we may need to update the quantity/refill remaining
        [self updateQuantityRefillsRemainingOffsetForDrug:thisDrugId];
    }
    
    [[LocalNotificationManager getInstance] getState:NO respondTo:nil async:NO];
    [[LocalNotificationManager getInstance] endBatchUpdates:NO];
    
    // If we just deleted the last event, refresh the note cell.
    if ([historyDateEventsList count] == 0)
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleInsert)
	{
        NSArray* possibleDrugIds = nil;
        if (drugId)
            possibleDrugIds = [NSArray arrayWithObject:drugId];
        else
            possibleDrugIds = [self getDrugIDsForPersonID];
        
		HistoryAddEditEventViewController* addEventController = [[HistoryAddEditEventViewController alloc]
																  initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"HistoryAddEditEventViewController"]
																		   bundle:[DosecastUtil getResourceBundle]
                                                                        viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDrugHistoryAddEntry", @"Dosecast", [DosecastUtil getResourceBundle], @"Add New Entry", @"The label appearing in the Add Entry option in the Drug History view"])
																		   drugId:nil
                                                                  possibleDrugIds:possibleDrugIds
                                                                       actionName:nil
                                                                        eventTime:nil
                                                                    scheduledTime:nil
                                                               postponePeriodSecs:-1
                                                                     refillAmount:0.0f
                                                                         delegate:self];
		[self.navigationController pushViewController:addEventController animated:YES];
	}
	else if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		if ((indexPath.section-1) < [historyDateEventsList count])
		{
			HistoryDateEvents* historyDateEvents = [historyDateEventsList objectAtIndex:(indexPath.section-1)];
			
			if (indexPath.row < [historyDateEvents.editableHistoryEvents count])
			{
				EditableHistoryEvent* deletedEvent = [historyDateEvents.editableHistoryEvents objectAtIndex:indexPath.row];
		
				[self.tableView beginUpdates];
				
				[self deleteEditableHistoryEventAtIndexPath:indexPath];
				
				[self.tableView endUpdates];
				
				// If we are editing, then add the deleted event to the deleted list so it can be cancelled or committed later.
				// If we aren't editing, commit it now. This can happen via swipe-to-delete.
				if (isEditing)
					[deletedEvents addObject:deletedEvent];
				else
                {
                    [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingReminders", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating reminders", @"The message appearing in the spinner view when updating the reminders"])];
                    
                    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDeleteAsync:) userInfo:deletedEvent repeats:NO];
                }
			}
		}
	}	
}

- (void)dealloc {
    
    // Remove our notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDataRefreshNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HistoryManagerHistoryEditedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DataModelDeleteAllDataNotification object:nil];

}


@end
