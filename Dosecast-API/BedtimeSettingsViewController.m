//
//  BedtimeSettingsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "BedtimeSettingsViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "BedtimePeriodViewController.h"
#import "LocalNotificationManager.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int DEFAULT_BEDTIME_START = 2200;
static const int DEFAULT_BEDTIME_END = 600;

@implementation BedtimeSettingsViewController

@synthesize tableView;
@synthesize bedtimeCell;
@synthesize bedtimePeriodCell;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<BedtimeSettingsViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
		
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        self.hidesBottomBarWhenPushed = YES;
		delegate = del;
		
		DataModel* dataModel = [DataModel getInstance];
		bedtimeStart = dataModel.globalSettings.bedtimeStart;
		bedtimeEnd = dataModel.globalSettings.bedtimeEnd;
		bedtimeDefined = (bedtimeStart != -1 || bedtimeEnd != -1);
		// If bedtime isn't defined, provide some default values
		if (bedtimeStart == -1)
			bedtimeStart = DEFAULT_BEDTIME_START;
		if (bedtimeEnd == -1)
			bedtimeEnd = DEFAULT_BEDTIME_END;
		
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSettingsSchedulingHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"Scheduling", @"The scheduling header of the Settings view"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
	
	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	

	// Setup callback for bedtime switch
	UISwitch* bedtimeSwitch = (UISwitch *)[bedtimeCell viewWithTag:2];
	[bedtimeSwitch addTarget:self action:@selector(handleBedtimeSwitch:) forControlEvents:UIControlEventValueChanged];
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

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)setBedtimeLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage
{
	[[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
	
	if (result)
	{
		if ([delegate respondsToSelector:@selector(handleBedtimeSettingsDone)])
		{
			[delegate handleBedtimeSettingsDone];
		}					
		[self.navigationController popViewControllerAnimated:YES];			
	}
	else
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorCouldNotSetBedtimeTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Could Not Update Settings", @"The title of the alert displayed when an error occurs on setting the bedtime"])
                                                                                           message:errorMessage];
		[alert showInViewController:self];
	}
}

- (void)handleSetBedtimePeriod:(NSDate*)bedtimeStartDate bedtimeEndDate:(NSDate*)bedtimeEndDate
{
	[DataModel convertDatestoBedtime:bedtimeStartDate bedtimeEndDate:bedtimeEndDate bedtimeStart:&bedtimeStart bedtimeEnd:&bedtimeEnd];
	[self.tableView reloadData];
}

- (IBAction)handleDone:(id)sender
{
	int actualBedtimeStart = -1;
	int actualBedtimeEnd = -1;
	if (bedtimeDefined)
	{
		actualBedtimeStart = bedtimeStart;
		actualBedtimeEnd = bedtimeEnd;
	}
	
	[[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingSettings", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating settings", @"The message appearing in the spinner view when updating settings"])];

	[[LocalNotificationManager getInstance] setBedtime:actualBedtimeStart
				 bedtimeEnd:actualBedtimeEnd
				  respondTo:self async:YES];
}

- (IBAction)handleCancel:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleBedtimeSwitch:(id)sender
{
	bedtimeDefined = !bedtimeDefined;

	[self.tableView beginUpdates];
	if (bedtimeDefined)
		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationRight];	
	else
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationLeft];

	[self.tableView endUpdates];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (bedtimeDefined)
		return 2;
	else
		return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
	return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
	{
		UILabel* bedtimeLabel = (UILabel *)[bedtimeCell viewWithTag:1];		
		bedtimeLabel.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimeSettingsIntervalRemindersSwitch", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval Reminders During Bedtime", @"The label appearing in the Bedtime Settings view for the interval reminders switch cell"]);
		UISwitch* bedtimeSwitch = (UISwitch *)[bedtimeCell viewWithTag:2];
		bedtimeSwitch.on = !bedtimeDefined;
		return bedtimeCell;
	}
	else // indexPath.section == 1
	{
		UILabel* bedtimeStartHeader = (UILabel *)[bedtimePeriodCell viewWithTag:1];	
		bedtimeStartHeader.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodBedtimeStarts", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime Starts", @"The label of the bedtime starts cell in the Bedtime Period view"]);
		UILabel* bedtimeEndHeader = (UILabel *)[bedtimePeriodCell viewWithTag:2];		
		bedtimeEndHeader.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodBedtimeEnds", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime Ends", @"The label of the bedtime ends cell in the Bedtime Period view"]);
		
		NSDate* bedtimeStartDate = nil;
		NSDate* bedtimeEndDate = nil;
		[DataModel convertBedtimetoDates:bedtimeStart bedtimeEnd:bedtimeEnd bedtimeStartDate:&bedtimeStartDate bedtimeEndDate:&bedtimeEndDate];
		
		UILabel* bedtimeStartTimeLabel = (UILabel *)[bedtimePeriodCell viewWithTag:3];		
		UILabel* bedtimeEndTimeLabel = (UILabel *)[bedtimePeriodCell viewWithTag:4];
		bedtimeStartTimeLabel.text = [dateFormatter stringFromDate:bedtimeStartDate];
		bedtimeEndTimeLabel.text = [dateFormatter stringFromDate:bedtimeEndDate];

		return bedtimePeriodCell;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
		return 44;
	else // indexPath.section == 1
		return 88;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == 0)
		return NSLocalizedStringWithDefaultValue(@"ViewBedtimeSettingsMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"When this setting is off, reminders for drugs taken at intervals are stopped during the bedtime period you define. This setting doesn't affect reminders for drugs taken on a schedule.", @"The message in the Bedtime Settings view explaining how the settings work"]);
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	if (indexPath.section == 1)
	{
		NSDate* bedtimeStartDate = nil;
		NSDate* bedtimeEndDate = nil;
		[DataModel convertBedtimetoDates:bedtimeStart
								bedtimeEnd:bedtimeEnd
						  bedtimeStartDate:&bedtimeStartDate
							bedtimeEndDate:&bedtimeEndDate];
		
		// Display BedtimePeriodViewController in new view
		BedtimePeriodViewController* bedtimePeriodController = [[BedtimePeriodViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"BedtimePeriodViewController"]
                                                                                                            bundle:[DosecastUtil getResourceBundle]
                                                                                                  bedtimeStartDate:bedtimeStartDate
                                                                                                    bedtimeEndDate:bedtimeEndDate
                                                                                                          delegate:self];
		[self.navigationController pushViewController:bedtimePeriodController animated:YES];
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

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[tableView reloadData];
}



@end
