//
//  IntervalPeriodViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "IntervalPeriodViewController.h"
#import "DosecastUtil.h"
#import "Drug.h"
#import "IntervalDrugReminder.h"
#import "DataModel.h"

static const int MAX_NUM_DAYS = 31;
static const int MAX_NUM_HOURS = 24;
static const int MAX_NUM_MINUTES = 60;
static const int INTERVAL_INCREMENT_MINS = 5;

@implementation IntervalPeriodViewController

@synthesize tableView;
@synthesize pickerView;
@synthesize displayCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil initialMinutes:DEFAULT_REMINDER_INTERVAL_MINUTES delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
       initialMinutes:(int)initialMinutes
             delegate:(NSObject<IntervalPeriodViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		controllerDelegate = del;
        
		minutes = initialMinutes;
		displayCell = nil;
		self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugAddEditTakeDrugIntervalPeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Interval", @"The Interval label for interval drugs in the Drug Edit view"]);

        // Set Cancel button
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        
        // Set Done button
        NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
        doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
        self.navigationItem.rightBarButtonItem = doneButton;
        doneButton.enabled = (minutes > 0);

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
	tableView.sectionHeaderHeight = 16;
	tableView.sectionFooterHeight = 16;
			
	// Load the displayCell from the Nib
	[[DosecastUtil getResourceBundle] loadNibNamed:@"IntervalPeriodTableViewCell" owner:self options:nil];	
}

- (void)setPickerToInterval
{
	int numMinutesLeft = minutes % 60;
	int numHours = minutes / 60;
	int numHoursLeft = numHours % 24;
	int numDays = numHours / 24;
	[pickerView selectRow:numDays inComponent:0 animated:NO];
	[pickerView selectRow:numHoursLeft inComponent:1 animated:NO];
	[pickerView selectRow:(numMinutesLeft/INTERVAL_INCREMENT_MINS) inComponent:2 animated:NO];
}

- (void)updateDisplayCellForPickerRow
{	
	if (displayCell != nil)
	{
		UILabel* displayLabel = (UILabel*)[displayCell viewWithTag:2];
		displayLabel.text = [IntervalDrugReminder intervalDescription:minutes];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
	// Initialize the display value in the cell and picker
	[self updateDisplayCellForPickerRow];	
	[self setPickerToInterval];
	
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

// Called prior to rotating the device orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	[tableView reloadData];
	[self setPickerToInterval];
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

- (void)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleDone:(id)sender
{
	if (minutes == 0)
		[self handleCancel:sender];
	else
	{
		if ([controllerDelegate respondsToSelector:@selector(handleSetIntervalPeriod:)])
		{
			[controllerDelegate handleSetIntervalPeriod:minutes];
		}				
		[self.navigationController popViewControllerAnimated:YES];			
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UILabel* header = (UILabel*)[displayCell viewWithTag:1];
	header.text = NSLocalizedStringWithDefaultValue(@"ViewIntervalPeriodReminderInterval", @"Dosecast", [DosecastUtil getResourceBundle], @"Reminder Interval", @"The label for the interval period in the Interval Period view"]);
	return displayCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
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

#pragma mark Picker view methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{	
	return 3;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	if (component == 0)
		return MAX_NUM_DAYS;
	else if (component == 1)
		return MAX_NUM_HOURS;
	else // component == 2
		return MAX_NUM_MINUTES / INTERVAL_INCREMENT_MINS;
}

- (UIView *)pickerView:(UIPickerView *)pv viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
	UILabel* label = (UILabel*)view;
	if (!label)
	{
		CGSize size = [pv rowSizeForComponent:component];
		label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
	}
	
	label.textAlignment = NSTextAlignmentCenter;
	label.font = [UIFont boldSystemFontOfSize:17];
	label.backgroundColor = [UIColor clearColor];
	label.userInteractionEnabled = YES;
	
	NSString* daySingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);
	NSString* dayPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
	NSString* hourSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"hour", @"The singular name for hour in interval drug descriptions"]);
	NSString* hourPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"hours", @"The plural name for hour in interval drug descriptions"]);
	NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
	NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);
	
	if (component == 0)
	{
		NSMutableString* labelText = nil;
		if (![DosecastUtil shouldUseSingularForInteger:(int)row])
			labelText = [NSMutableString stringWithFormat:@"%d %@", (int)row, dayPlural];
		else
			labelText = [NSMutableString stringWithFormat:@"%d %@", (int)row, daySingular];
		label.text = labelText;
	}
	else if (component == 1)
	{
		NSMutableString* labelText = nil;
		if (![DosecastUtil shouldUseSingularForInteger:(int)row])
			labelText = [NSMutableString stringWithFormat:@"%d %@", (int)row, hourPlural];
		else
			labelText = [NSMutableString stringWithFormat:@"%d %@", (int)row, hourSingular];
		label.text = labelText;
	}
	else // component == 2
	{
		int minsDisplayed = (int)row*INTERVAL_INCREMENT_MINS;
		NSMutableString* labelText = nil;
		if (![DosecastUtil shouldUseSingularForInteger:minsDisplayed])
			labelText = [NSMutableString stringWithFormat:@"%d %@", minsDisplayed, minPlural];
		else
			labelText = [NSMutableString stringWithFormat:@"%d %@", minsDisplayed, minSingular];
		label.text = labelText;		
	}
	
	return label;		
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    minutes = (int)[self.pickerView selectedRowInComponent:0]*24*60 + (int)[self.pickerView selectedRowInComponent:1]*60 + (int)[self.pickerView selectedRowInComponent:2]*INTERVAL_INCREMENT_MINS;
	doneButton.enabled = (minutes > 0);
	[self updateDisplayCellForPickerRow];	
}

@end
