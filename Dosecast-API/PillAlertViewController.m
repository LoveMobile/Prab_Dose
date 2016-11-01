//
//  PillAlertViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "PillAlertViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "Drug.h"
#import "CustomNameIDList.h"
#import "GlobalSettings.h"
#import "HistoryManager.h"
#import "LogManager.h"
#import "FlagDictionary.h"
#import "DosecastAPIFlags.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"
#import "BarButtonDisabler.h"

static const int TABLE_WIDTH = 270;
static const CGFloat DOSAGE_LABEL_BASE_HEIGHT = 19;
static const CGFloat DIRECTIONS_LABEL_BASE_HEIGHT = 18;

@implementation PillAlertViewController
@synthesize tableView;
@synthesize tableViewCell;
@synthesize alertTitle;
@synthesize alertMessage;
@synthesize takeButton;
@synthesize postponeButton;
@synthesize skipButton;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil delegate:nil];
}

// The designated initializer.
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
             delegate:(NSObject<PillAlertViewControllerDelegate>*)del
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		topController = nil;
        delegate = del;
        
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        drugDosageExtraHeightDict = [[NSMutableDictionary alloc] init];
        drugDirectionsExtraHeightDict = [[NSMutableDictionary alloc] init];
        exampleTableViewCell = nil;
        refreshControl = nil;
        tableViewController = nil;
        barButtonDisabler = [[BarButtonDisabler alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHistoryEditedNotification:)
                                                     name:HistoryManagerHistoryEditedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDataModelRefresh:)
                                                     name:DataModelDataRefreshNotification
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LogSyncFailedNotification object:nil];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Load an example cell and size it
    [[DosecastUtil getResourceBundle] loadNibNamed:@"PillAlertTableViewCell" owner:self options:nil];
    exampleTableViewCell = tableViewCell;
    tableViewCell = nil;
    exampleTableViewCell.frame = CGRectMake(exampleTableViewCell.frame.origin.x, exampleTableViewCell.frame.origin.y, TABLE_WIDTH, exampleTableViewCell.frame.size.height);
    [exampleTableViewCell layoutIfNeeded];
    
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
    
    [self refresh];
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
        if (errorMessage && topController)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorSyncTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Sync Error", @"The title on the alert appearing when a sync error occurs"])
                                                                                               message:errorMessage];
            [alert showInViewController:topController];
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
        if (errorMessage && topController)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorSyncTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Sync Error", @"The title on the alert appearing when a sync error occurs"])
                                                                                               message:errorMessage];
            [alert showInViewController:topController];
        }
    }
}

// Called whenever the data model (re)builds from JSON
- (void)handleDataModelRefresh:(NSNotification *)notification
{
    [self refresh];
}

- (void)handleHistoryEditedNotification:(NSNotification *)notification
{
    [self refresh];
}

- (void)refresh
{
    [drugDosageExtraHeightDict removeAllObjects];
    [drugDirectionsExtraHeightDict removeAllObjects];

    // Initialize variables
    alertTitle.text = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Dose Reminder", @"The title of the dose reminder alert"]);
    
    NSString* takeDoseSingular = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Dose", @"The Take Dose button on the dose reminder alert"]);
    NSString* takeDosePlural = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonTakeDosePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Take Doses", @"The Take Doses button on the dose reminder alert"]);
    NSString* skipDoseSingular = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonSkipDoseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Dose", @"The Skip Dose button on the dose reminder alert"]);
    NSString* skipDosePlural = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonSkipDosePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Skip Doses", @"The Skip Doses button on the dose reminder alert"]);
    
    NSMutableString* takeDoseButtonTitle = nil;
    NSMutableString* skipDoseButtonTitle = nil;
    DataModel* dataModel = [DataModel getInstance];
    int numOverdueDrugs = [dataModel numOverdueDrugs];

    if (![DosecastUtil shouldUseSingularForInteger:numOverdueDrugs])
    {
        takeDoseButtonTitle = [NSMutableString stringWithString:takeDosePlural];
        skipDoseButtonTitle = [NSMutableString stringWithString:skipDosePlural];
    }
    else
    {
        takeDoseButtonTitle = [NSMutableString stringWithString:takeDoseSingular];
        skipDoseButtonTitle = [NSMutableString stringWithString:skipDoseSingular];
    }
    
    NSString* phraseSingular = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderMessagePhraseSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"Time to take:", @"The message phrase on the dose reminder alert when only 1 dose is due"]);
    NSString* phrasePlural = NSLocalizedStringWithDefaultValue(@"AlertDoseReminderMessagePhrasePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"Time to take %d doses:", @"The message phrase on the dose reminder alert when multiple doses are due"]);
    
    if (![DosecastUtil shouldUseSingularForInteger:numOverdueDrugs])
        alertMessage.text = [NSMutableString stringWithFormat:phrasePlural, numOverdueDrugs];
    else
        alertMessage.text = [NSMutableString stringWithString:phraseSingular];

    [takeButton setTitle:takeDoseButtonTitle forState:UIControlStateNormal];
    [takeButton setTitle:takeDoseButtonTitle forState:UIControlStateDisabled];
    [takeButton setTitle:takeDoseButtonTitle forState:UIControlStateHighlighted];
    [takeButton setTitle:takeDoseButtonTitle forState:UIControlStateSelected];
    [DosecastUtil setBackgroundColorForButton:takeButton color:[DosecastUtil getDoseAlertButtonColor]];
    
    [skipButton setTitle:skipDoseButtonTitle forState:UIControlStateNormal];
    [skipButton setTitle:skipDoseButtonTitle forState:UIControlStateDisabled];
    [skipButton setTitle:skipDoseButtonTitle forState:UIControlStateHighlighted];
    [skipButton setTitle:skipDoseButtonTitle forState:UIControlStateSelected];
    [DosecastUtil setBackgroundColorForButton:skipButton color:[DosecastUtil getDoseAlertButtonColor]];

    [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateNormal];
    [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateSelected];
    [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateDisabled];
    [postponeButton setTitle:NSLocalizedStringWithDefaultValue(@"AlertDoseReminderButtonPostpone", @"Dosecast", [DosecastUtil getResourceBundle], @"Postpone", @"The Postpone button on the dose reminder alert"]) forState:UIControlStateHighlighted];
    [DosecastUtil setBackgroundColorForButton:postponeButton color:[DosecastUtil getDoseAlertButtonColor]];

    [self.tableView reloadData];
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

// Returns a list of NSNumbers indicating the indices of overdue drugs in the drug list for distinct groups
- (NSArray*)getOverdueDrugListGroupIndices
{
    NSMutableArray* overdueDrugs = [[NSMutableArray alloc] init];
    DataModel* dataModel = [DataModel getInstance];

    int numOverdueDrugs = [dataModel numOverdueDrugs];
    for (int i = 0; i < numOverdueDrugs; i++)
    {
        Drug* d = [dataModel findOverdueDrug:i];
        [overdueDrugs addObject:d];
    }
    
    return [self getGroupIndicesForDrugList:overdueDrugs];
}
#pragma mark Table view methods

- (Drug*) getOverdueDrugForCellAtIndexPath:(NSIndexPath*)indexPath
{
    DataModel* dataModel = [DataModel getInstance];
    NSArray* overdueDrugListGroupIndices = [self getOverdueDrugListGroupIndices];
    if ([overdueDrugListGroupIndices count] > indexPath.section)
    {
        int drugIndex = [((NSNumber*)[overdueDrugListGroupIndices objectAtIndex:(int)indexPath.section]) intValue] + (int)indexPath.row;
        return [dataModel findOverdueDrug:drugIndex];
    }
    else
        return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self getOverdueDrugListGroupIndices] count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DataModel* dataModel = [DataModel getInstance];
    NSArray* overdueDrugListGroupIndices = [self getOverdueDrugListGroupIndices];
    
    if ([overdueDrugListGroupIndices count] > section)
    {
        // Calculate the start & end indixes for this section
        int drugIndexStart = [((NSNumber*)[overdueDrugListGroupIndices objectAtIndex:section]) intValue];
        int drugIndexEnd = -1;
        if (section == [overdueDrugListGroupIndices count]-1)
            drugIndexEnd = [dataModel numOverdueDrugs]-1;
        else
            drugIndexEnd = [((NSNumber*)[overdueDrugListGroupIndices objectAtIndex:section+1]) intValue]-1;
        
        return drugIndexEnd-drugIndexStart+1;
    }
    else
        return 0;
}

- (CGFloat) getHeightForCellLabelTag:(int)tag labelBaseHeight:(CGFloat)labelBaseHeight withString:(NSString*)value
{
    UILabel* label = (UILabel*)[exampleTableViewCell viewWithTag:tag];
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

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *MyIdentifier = @"PillCellIdentifier";
	
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"PillAlertTableViewCell" owner:self options:nil];
        cell = tableViewCell;
        tableViewCell = nil;
    }
	
	Drug* overdueDrug = [self getOverdueDrugForCellAtIndexPath:indexPath];
	
    if (overdueDrug)
    {
        // Set main label
        UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
        mainLabel.text = [overdueDrug.dosage getDescriptionForDrugDose:overdueDrug.name];
        CGFloat mainLabelHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:DOSAGE_LABEL_BASE_HEIGHT withString:mainLabel.text];
        mainLabel.frame = CGRectMake(mainLabel.frame.origin.x, mainLabel.frame.origin.y, mainLabel.frame.size.width, (int)ceilf(mainLabelHeight));
        CGFloat shiftY = (mainLabelHeight - DOSAGE_LABEL_BASE_HEIGHT);

        // Set sub label
        UILabel* subLabel = (UILabel *)[cell viewWithTag:2];
        NSString* pillAlertFormatStr = NSLocalizedStringWithDefaultValue(@"AlertDoseTimePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"At %@", @"The time phrase appearing on dose alerts"]);
        NSMutableString* subLabelText = [NSMutableString stringWithFormat:pillAlertFormatStr, [dateFormatter stringFromDate:overdueDrug.reminder.overdueReminder]];
        if ([overdueDrug.directions length] > 0)
            [subLabelText appendFormat:@" (%@)", overdueDrug.directions];
        subLabel.text = subLabelText;
        CGFloat subLabelHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DIRECTIONS_LABEL_BASE_HEIGHT withString:subLabelText];
        subLabel.frame = CGRectMake(subLabel.frame.origin.x, (int)ceilf([exampleTableViewCell viewWithTag:2].frame.origin.y + shiftY), subLabel.frame.size.width, (int)ceilf(subLabelHeight));
        
        UIImageView *notesIcon = (UIImageView *)[cell viewWithTag:44];
        notesIcon.hidden = (!overdueDrug.notes || [[overdueDrug.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0);
    }
    
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	Drug* overdueDrug = [self getOverdueDrugForCellAtIndexPath:indexPath];
    
    CGFloat cellHeight = exampleTableViewCell.frame.size.height;
    
    CGFloat mainLabelHeight = [self getHeightForCellLabelTag:1 labelBaseHeight:DOSAGE_LABEL_BASE_HEIGHT withString:[overdueDrug.dosage getDescriptionForDrugDose:overdueDrug.name]];
    cellHeight += (mainLabelHeight - DOSAGE_LABEL_BASE_HEIGHT);
    
    NSString* pillAlertFormatStr = NSLocalizedStringWithDefaultValue(@"AlertDoseTimePhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"At %@", @"The time phrase appearing on dose alerts"]);
    NSMutableString* subLabelText = [NSMutableString stringWithFormat:pillAlertFormatStr, [dateFormatter stringFromDate:overdueDrug.reminder.overdueReminder]];
    if ([overdueDrug.directions length] > 0)
        [subLabelText appendFormat:@" (%@)", overdueDrug.directions];
    CGFloat subLabelHeight = [self getHeightForCellLabelTag:2 labelBaseHeight:DIRECTIONS_LABEL_BASE_HEIGHT withString:subLabelText];
    cellHeight += (subLabelHeight - DIRECTIONS_LABEL_BASE_HEIGHT);
    
	return cellHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    Drug* d = [self getOverdueDrugForCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
    
    if (d)
        return [self getGroupNameForGroupContainingDrug:d];
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    Drug* overdueDrug = [self getOverdueDrugForCellAtIndexPath:indexPath];
    
    if (overdueDrug && delegate && [delegate respondsToSelector:@selector(handleAlertViewDrug:)])
    {
        [delegate handleAlertViewDrug:overdueDrug.drugId];
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

-(void)showOnViewController:(UIViewController*)controller animated:(BOOL)animated
{
	if (topController)
		[self hide:NO];
	
	if (!controller)
		return;
    
	topController = controller;
	
	// Setup device orientation callbacks
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(willChangeStatusBarOrientation:)
												 name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(didChangeStatusBarOrientation:)
												 name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
	
    [self handleShow:animated];
}

- (void) handleShow:(BOOL)animated
{
	// Resize our bounds using the current status bar orientation
	CGSize topViewBounds = topController.view.bounds.size;
    [self view].frame = CGRectMake(0, 0, topViewBounds.width, topViewBounds.height);

    [barButtonDisabler setToolbarStateForViewController:topController enabled:NO];

	if (animated)
    {
     	self.view.alpha = 0;
        
        [topController.view addSubview:self.view];
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        self.view.alpha = 1;
        [UIView commitAnimations];   
    }
    else
    {
        self.view.alpha = 1;
        [topController.view addSubview:self.view];
    }
}

- (void)handleHide:(BOOL)animated
{
    [barButtonDisabler setToolbarStateForViewController:topController enabled:YES];

	if (animated)
	{		
		self.view.alpha = 1;
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.3];
		
		self.view.alpha = 0;
        
		// Set callback for when animation stops
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		
		[UIView commitAnimations];
	}
	else
	{
		self.view.alpha = 0;
		[self.view removeFromSuperview];
	}	
}

// Callback for pre-device rotation
- (void) willChangeStatusBarOrientation:(NSNotification *)notification
{
	[self handleHide:NO];
}

- (void) handleShowDelayed:(NSTimer*)theTimer
{
    [self handleShow:NO];
}

// Callback for post-device rotation
- (void) didChangeStatusBarOrientation:(NSNotification *)notification
{
    // Schedule the handling for this orientation for a little later to allow the topController to update its bounds first
	[NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleShowDelayed:) userInfo:nil repeats:NO];
}

-(void)hide:(BOOL)animated
{	
	if (!topController)
		return;
	
	[self handleHide:animated];
	
	// stop device orientation event callbacks
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];	
	
	topController = nil;
}

// Callback for when animation stops
- (void)animationDidStop:(NSString*)animationID finished:(BOOL)finished context:(void *)context 
{
	[self.view removeFromSuperview];
	[UIView setAnimationDelegate:nil];
	[UIView setAnimationDidStopSelector:nil];	
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
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

- (IBAction)handlePostponeDose:(id)sender
{
    if (delegate && [delegate respondsToSelector:@selector(handleAlertPostponeDose:)])
    {
        [delegate handleAlertPostponeDose:sender];
    }
}

- (IBAction)handleTakeDose:(id)sender
{
    if (delegate && [delegate respondsToSelector:@selector(handleAlertTakeDose:)])
    {
        [delegate handleAlertTakeDose:sender];
    }
}

- (IBAction)handleSkipDose:(id)sender
{
    if (delegate && [delegate respondsToSelector:@selector(handleAlertSkipDose:)])
    {
        [delegate handleAlertSkipDose:sender];
    }
}


- (BOOL) visible
{
	return topController != nil;
}

@end
