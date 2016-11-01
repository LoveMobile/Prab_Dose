//
//  TimePeriodViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "TimePeriodViewController.h"
#import "DosecastUtil.h"

@implementation TimePeriodViewController

@synthesize tableView;
@synthesize pickerView;
@synthesize displayCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil initialTimePeriodSecs:0 minuteInterval:5 maxHours:1 identifier:0 viewTitle:nil cellHeader:nil displayNever:NO neverTitle:nil allowZero:NO nibName:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
initialTimePeriodSecs:(int)initialTimePeriodSecs
       minuteInterval:(int)minute // the minute interval to use
             maxHours:(int)hours
           identifier:(int)uniqueID	// a unique identifier for the current picker
            viewTitle:(NSString*)viewTitle
           cellHeader:(NSString*)cellHeader
         displayNever:(BOOL)displayNever
           neverTitle:(NSString*)neverTitle
            allowZero:(BOOL)zero
              nibName:(NSString*)nib
             delegate:(NSObject<TimePeriodViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		if (initialTimePeriodSecs < 0)
            initialTimePeriodSecs = 0;
        timePeriodSecs = initialTimePeriodSecs;
		uniqueIdentifier = uniqueID;
        minuteInterval = minute;
        maxHours = hours;
		displayNeverButton = displayNever;
        allowZero = zero;
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
		doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
		self.navigationItem.rightBarButtonItem = doneButton;
        doneButton.enabled = (timePeriodSecs > 0 || allowZero);
		
		// Create toolbar for never button
		if (displayNever)
		{
			UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
			UIBarButtonItem *neverButton = [[UIBarButtonItem alloc] initWithTitle:neverTitle style:UIBarButtonItemStyleBordered target:self action:@selector(handleNever:)];
			self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, neverButton, nil];	
		}
        self.hidesBottomBarWhenPushed = !displayNever;
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

- (void)setPickerToTimePeriod
{
    int numMinutes = timePeriodSecs / 60;
	int numHours = numMinutes/60;
	int numMinutesLeft = numMinutes%60;
	[pickerView selectRow:numHours inComponent:0 animated:NO];
	[pickerView selectRow:(numMinutesLeft/minuteInterval) inComponent:1 animated:NO];
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
	[self setPickerToTimePeriod];
    
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
	[self setPickerToTimePeriod];
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

- (void)handleDelegateTimePeriodCancel:(NSTimer*)theTimer
{
	if ([controllerDelegate respondsToSelector:@selector(handleCancelTimePeriod:)])
	{
		[controllerDelegate handleCancelTimePeriod:uniqueIdentifier];
	}
}

- (void)handleCancel:(id)sender
{	
	[self.navigationController popViewControllerAnimated:YES];
    
    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegateTimePeriodCancel:) userInfo:nil repeats:NO];
}

- (void)handleNever:(id)sender
{
    BOOL success = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleSetTimePeriodValue:forNibNamed:identifier:)])
	{
		success = [controllerDelegate handleSetTimePeriodValue:-1 forNibNamed:nibName identifier:uniqueIdentifier];
	}
    if (success)
        [self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleDone:(id)sender
{
	BOOL success = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleSetTimePeriodValue:forNibNamed:identifier:)])
	{
		success = [controllerDelegate handleSetTimePeriodValue:timePeriodSecs forNibNamed:nibName identifier:uniqueIdentifier];
	}
	if (success)
		[self.navigationController popViewControllerAnimated:YES];
}

// Returns the string label to display for the given number of hours
-(NSString*)pickerStringLabelForHours:(int)numHours
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
-(NSString*)pickerStringLabelForMinutes:(int)numMins padNum:(BOOL)padNum
{
	NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
	NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);

	NSString* unit = nil;
	if (![DosecastUtil shouldUseSingularForInteger:numMins])
		unit = minPlural;
	else
		unit = minSingular;
	
	if (padNum)
		return [NSString stringWithFormat:@"%02d %@", numMins, unit];
	else
		return [NSString stringWithFormat:@"%d %@", numMins, unit];
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
	// Set main label
	UILabel* mainLabel = (UILabel *)[displayCell viewWithTag:1];
	mainLabel.text = cellHeaderText;
	
	// Set picker label
	UILabel* pickerLabel = (UILabel *)[displayCell viewWithTag:2];
    int numMinutes = timePeriodSecs/60;
	int numHours = numMinutes/60;
	int numMinutesLeft = numMinutes%60;
    NSMutableString* pickerLabelText = [NSMutableString stringWithString:@""];
    if (numHours > 0)
        [pickerLabelText appendString:[self pickerStringLabelForHours:numHours]];
    if (numMinutesLeft > 0 || numHours == 0)
    {
        if (numHours > 0)
            [pickerLabelText appendString:@" "];
        [pickerLabelText appendString:[self pickerStringLabelForMinutes:numMinutesLeft padNum:NO]];
    }
	pickerLabel.text = pickerLabelText;

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
		return maxHours;
	else // component == 1
		return 60/minuteInterval;
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
	label.font = [UIFont boldSystemFontOfSize:24];
	label.backgroundColor = [UIColor clearColor];
	label.userInteractionEnabled = YES;

	if (component == 0)
	{
		label.text = [NSString stringWithFormat:@"%@", [self pickerStringLabelForHours:(int)row]];
	}
	else // component == 1
	{
		label.text = [NSString stringWithFormat:@"%@", [self pickerStringLabelForMinutes:(int)row*minuteInterval padNum:YES]];
	}
	
	return label;		
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	int numHours = (int)[self.pickerView selectedRowInComponent:0];
	int numMins = (int)[self.pickerView selectedRowInComponent:1]*minuteInterval;
	timePeriodSecs = (numHours*60*60)+(numMins*60);
    [tableView reloadData];
    
    doneButton.enabled = (timePeriodSecs > 0 || allowZero);
}

@end
