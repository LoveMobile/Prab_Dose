//
//  LateDoseSettingsViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "LateDoseSettingsViewController.h"
#import "DosecastUtil.h"
#import "TimePeriodViewController.h"
#import "DataModel.h"
#import "GlobalSettings.h"

static const int PERIOD_MINUTE_INTERVAL = 5;
static const int PERIOD_MAX_HOURS = 9;

@implementation LateDoseSettingsViewController

@synthesize tableView;
@synthesize lateDoseSwitchCell;
@synthesize lateDosePeriodCell;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<LateDoseSettingsViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
		
		delegate = del;
        DataModel* dataModel = [DataModel getInstance];
        flagLateDoses = (dataModel.globalSettings.lateDosePeriodSecs > 0);
        lateDosePeriodSecs = dataModel.globalSettings.lateDosePeriodSecs;	
        if (lateDosePeriodSecs < 0)
            lateDosePeriodSecs = DEFAULT_LATE_DOSE_PERIOD_SECS;
        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSettingsHistoryHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"History", @"The history header of the Settings view"]);
	
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
	UISwitch* lateDoseSwitch = (UISwitch *)[lateDoseSwitchCell viewWithTag:2];
	[lateDoseSwitch addTarget:self action:@selector(handleLateDoseSwitch:) forControlEvents:UIControlEventValueChanged];
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

// Callback for seconds value
// If value < 0, this corresponds to 'Never'. Returns whether the new value is accepted.
- (BOOL)handleSetTimePeriodValue:(int)timePeriodSecs
                     forNibNamed:(NSString*)nibName
                      identifier:(int)uniqueID // a unique identifier for the current picker
{
    lateDosePeriodSecs = timePeriodSecs;
    [self.tableView reloadData];
    return YES;
}

- (IBAction)handleDone:(id)sender
{
    BOOL popViewController = YES;
    if ([delegate respondsToSelector:@selector(handleLateDoseSettingsDone:lateDosePeriodSecs:)])
    {
        popViewController = [delegate handleLateDoseSettingsDone:flagLateDoses lateDosePeriodSecs:(flagLateDoses ? lateDosePeriodSecs : -1)];
    }					
    
    if (popViewController)
        [self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleCancel:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleLateDoseSwitch:(id)sender
{
	flagLateDoses = !flagLateDoses;

	[self.tableView beginUpdates];
	if (flagLateDoses)
		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationRight];	
	else
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationLeft];

	[self.tableView endUpdates];
}

// Returns the string label to display for the given number of hours
-(NSString*)latePeriodStringLabelForHours:(int)numHours
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
-(NSString*)latePeriodStringLabelForMinutes:(int)numMins
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

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (flagLateDoses)
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
		UILabel* label = (UILabel *)[lateDoseSwitchCell viewWithTag:1];		
		label.text = NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsFlagLateDoses", @"Dosecast", [DosecastUtil getResourceBundle], @"Flag Doses Taken Late", @"The Flag Late Doses label in the Late Dose Settings view"]);
		UISwitch* lateDoseSwitch = (UISwitch *)[lateDoseSwitchCell viewWithTag:2];
		lateDoseSwitch.on = flagLateDoses;
		return lateDoseSwitchCell;
	}
	else // indexPath.section == 1
	{
        UILabel* headerLabel = (UILabel *)[lateDosePeriodCell viewWithTag:1];		
		headerLabel.text = NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsLateDosePeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Late After", @"The Late Dose Period label in the Late Dose Settings view"]);

        UILabel* periodLabel = (UILabel *)[lateDosePeriodCell viewWithTag:2];
        int numMinutes = lateDosePeriodSecs/60;
        int numHours = numMinutes/60;
        int numMinutesLeft = numMinutes%60;
        NSMutableString* periodLabelText = [NSMutableString stringWithString:@""];
        if (numHours > 0)
            [periodLabelText appendString:[self latePeriodStringLabelForHours:numHours]];
        if (numMinutesLeft > 0 || numHours == 0)
        {
            if (numHours > 0)
                [periodLabelText appendString:@" "];
            [periodLabelText appendString:[self latePeriodStringLabelForMinutes:numMinutesLeft]];
        }
        periodLabel.text = periodLabelText;

		return lateDosePeriodCell;
	}
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
	if (section == 0)
		return NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"When this setting is on, a dose taken after its scheduled time will be flagged as late in the dose history.", @"The message in the Late Dose Settings view explaining how the setting works"]);
    else if (section == 1)
        return NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsPeriodMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Define how long after its scheduled time a dose will be flagged as late.", @"The message in the Late Dose Settings view explaining how the period setting works"]);
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	if (indexPath.section == 1)
	{
		// Display TimePeriodViewController in new view
		TimePeriodViewController* timePeriodController = [[TimePeriodViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"TimePeriodViewController"]
                                                                                                    bundle:[DosecastUtil getResourceBundle]
                                                                                     initialTimePeriodSecs:lateDosePeriodSecs
                                                                                            minuteInterval:PERIOD_MINUTE_INTERVAL
                                                                                                  maxHours:PERIOD_MAX_HOURS
                                                                                                identifier:0
                                                                                                 viewTitle:NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Flag Late Doses", @"The title of the Late Dose Settings view"])
                                                                                                cellHeader:NSLocalizedStringWithDefaultValue(@"ViewLateDoseSettingsLateDosePeriod", @"Dosecast", [DosecastUtil getResourceBundle], @"Late After", @"The Late Dose Period label in the Late Dose Settings view"])
                                                                                              displayNever:NO
                                                                                                neverTitle:nil
                                                                                                 allowZero:NO
                                                                                                   nibName:@"TimePeriodTableViewCell"
                                                                                                  delegate:self];
        
		[self.navigationController pushViewController:timePeriodController animated:YES];
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
