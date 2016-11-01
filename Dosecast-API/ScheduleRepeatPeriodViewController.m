//
//  ScheduleRepeatPeriodViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ScheduleRepeatPeriodViewController.h"
#import "DosecastUtil.h"

static int MAX_NUM_PERIODS = 100;

@implementation ScheduleRepeatPeriodViewController

@synthesize tableView;
@synthesize pickerView;
@synthesize displayCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil initialScheduleRepeatPeriodNum:1 scheduleRepeatPeriod:ScheduleRepeatPeriodDays identifier:0 viewTitle:nil cellHeader:nil nibName:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
initialScheduleRepeatPeriodNum:(int)initialScheduleRepeatPeriodNum
 scheduleRepeatPeriod:(ScheduleRepeatPeriod)initialScheduleRepeatPeriod
           identifier:(int)uniqueID	// a unique identifier for the current picker
            viewTitle:(NSString*)viewTitle
           cellHeader:(NSString*)cellHeader
              nibName:(NSString*)nib
             delegate:(NSObject<ScheduleRepeatPeriodViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		if (initialScheduleRepeatPeriodNum <= 0)
            initialScheduleRepeatPeriodNum = 1;
        else if (initialScheduleRepeatPeriodNum > MAX_NUM_PERIODS)
            initialScheduleRepeatPeriodNum = MAX_NUM_PERIODS;
        scheduleRepeatPeriodNum = initialScheduleRepeatPeriodNum;
        scheduleRepeatPeriod = initialScheduleRepeatPeriod;
		uniqueIdentifier = uniqueID;
		nibName = nib;

        controllerDelegate = delegate;
		displayCell = nil;

		cellHeaderText = cellHeader;
		self.title = viewTitle;
		
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		// Set Cancel button
		UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
		self.navigationItem.leftBarButtonItem = cancelButton;
		
		// Set Done button
		NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
		UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
		self.navigationItem.rightBarButtonItem = doneButton;
        
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
	if (nibName != nil)
		[[DosecastUtil getResourceBundle] loadNibNamed:nibName owner:self options:nil];
}

- (void)setPickerToScheduleRepeatPeriod
{
	[pickerView selectRow:(scheduleRepeatPeriodNum-1) inComponent:0 animated:NO];
	[pickerView selectRow:((int)scheduleRepeatPeriod) inComponent:1 animated:NO];
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

	// Initialize picker and table selections
	[self setPickerToScheduleRepeatPeriod];
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

// Called prior to rotating the device orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	[tableView reloadData];
	[self setPickerToScheduleRepeatPeriod];
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

- (void)handleDelegateScheduleRepeatPeriodCancel:(NSTimer*)theTimer
{
	if ([controllerDelegate respondsToSelector:@selector(handleCancelScheduleRepeatPeriod:)])
	{
		[controllerDelegate handleCancelScheduleRepeatPeriod:uniqueIdentifier];
    }
}

- (void)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];			
	
    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegateScheduleRepeatPeriodCancel:) userInfo:nil repeats:NO];
}

- (void)handleDone:(id)sender
{
	BOOL success = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleSetScheduleRepeatPeriodValue:scheduleRepeatPeriod:forNibNamed:identifier:)])
	{
		success = [controllerDelegate handleSetScheduleRepeatPeriodValue:scheduleRepeatPeriodNum scheduleRepeatPeriod:((int)scheduleRepeatPeriod) forNibNamed:nibName identifier:uniqueIdentifier];
	}
	if (success)
		[self.navigationController popViewControllerAnimated:YES];
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
    NSString* daysPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
    NSString* daysSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);		
    NSString* weeksPlural = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"weeks", @"The plural name for week in scheduled drug descriptions"]);
    NSString* weeksSingular = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"week", @"The singular name for week in scheduled drug descriptions"]);		

	// Set main label
	UILabel* mainLabel = (UILabel *)[displayCell viewWithTag:1];
	mainLabel.text = cellHeaderText;
	
	// Set picker label
	UILabel* pickerLabel = (UILabel *)[displayCell viewWithTag:2];
    NSString* unitName = nil;
    if (scheduleRepeatPeriod == ScheduleRepeatPeriodDays)
    {
        if ([DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum])
            unitName = daysSingular;
        else
            unitName = daysPlural;
    }
    else // ScheduleRepeatPeriodWeeks
    {
        if ([DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum])
            unitName = weeksSingular;
        else
            unitName = weeksPlural;        
    }
	pickerLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ScheduleRepeatPeriodPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"Every %d %@", @"The phrase for describing schedule repeat periods for scheduled drugs"]),
                        scheduleRepeatPeriodNum, unitName];

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
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	if (component == 0)
		return MAX_NUM_PERIODS;
	else // component == 1
		return 2;
}

- (UIView *)pickerView:(UIPickerView *)pv viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    NSString* daysPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"days", @"The plural name for day in interval drug descriptions"]);
    NSString* daysSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugDayNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"day", @"The singular name for day in interval drug descriptions"]);		
    NSString* weeksPlural = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"weeks", @"The plural name for week in scheduled drug descriptions"]);
    NSString* weeksSingular = NSLocalizedStringWithDefaultValue(@"ScheduledDrugWeekNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"week", @"The singular name for week in scheduled drug descriptions"]);		

	UILabel* label = (UILabel*)view;
	if (!label)
	{
		CGSize size = [pv rowSizeForComponent:component];
		label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
	}

	label.textAlignment = NSTextAlignmentCenter;
	label.font = [UIFont boldSystemFontOfSize:24];
	label.backgroundColor = [UIColor clearColor];
	label.userInteractionEnabled = YES;

	if (component == 0)
	{
		label.text = [NSString stringWithFormat:@"%d", (int)row+1];
	}
	else // component == 1
	{
        NSString* unitName = nil;
        if (row == (int)ScheduleRepeatPeriodDays)
        {
            if ([DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum])
                unitName = daysSingular;
            else
                unitName = daysPlural;
        }
        else // ScheduleRepeatPeriodWeeks
        {
            if ([DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum])
                unitName = weeksSingular;
            else
                unitName = weeksPlural;        
        }

		label.text = [NSString stringWithFormat:@"%@", unitName];		
	}
	
	return label;		
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    int oldPeriodNum = scheduleRepeatPeriodNum;
    scheduleRepeatPeriodNum = (int)[self.pickerView selectedRowInComponent:0]+1;
    if (([DosecastUtil shouldUseSingularForInteger:oldPeriodNum] && ![DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum]) ||
        (![DosecastUtil shouldUseSingularForInteger:oldPeriodNum] && [DosecastUtil shouldUseSingularForInteger:scheduleRepeatPeriodNum]))
    {
        [self.pickerView reloadComponent:1]; // reload units
    }

    scheduleRepeatPeriod = (ScheduleRepeatPeriod)[self.pickerView selectedRowInComponent:1];
    
    [tableView reloadData];
}

@end
