//
//  DateTimePickerViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DateTimePickerViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"

@implementation DateTimePickerViewController

@synthesize tableView;
@synthesize datePicker;
@synthesize displayCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil
                          bundle:nibBundleOrNil
              initialDateTimeVal:nil
                            mode:DateTimePickerViewControllerModePickDate
                  minuteInterval:-1
                      identifier:0
                       viewTitle:nil
                      cellHeader:nil
                    displayNever:NO
                      neverTitle:nil
                         nibName:nil
                        delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
   initialDateTimeVal:(NSDate*)initialDateTimeVal
                 mode:(DateTimePickerViewControllerMode)mode
       minuteInterval:(int)minute // the minute interval to use for time and dateTime modes
           identifier:(int)uniqueID	// a unique identifier for the current picker
            viewTitle:(NSString*)viewTitle
           cellHeader:(NSString*)cellHeader
         displayNever:(BOOL)displayNever
           neverTitle:(NSString*)neverTitle
              nibName:(NSString*)nib
             delegate:(NSObject<DateTimePickerViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		if (initialDateTimeVal == nil)
		{
			if (mode == DateTimePickerViewControllerModePickTime)
				currDate = [DosecastUtil getCurrentTimeOnNonDaylightSavingsBoundaryDay];
			else
				currDate = [NSDate date];
		}
		else
			currDate = [initialDateTimeVal copy];
		uniqueIdentifier = uniqueID;
		controllerMode = mode;
        minuteInterval = minute;
		displayNeverButton = displayNever;
        self.hidesBottomBarWhenPushed = !displayNever;
		nibName = nib;
        
		displayCell = nil;
		controllerDelegate = delegate;
		cellHeaderText = cellHeader;
		self.title = viewTitle;
		
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		// Set Cancel button
		UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
		self.navigationItem.leftBarButtonItem = cancelButton;
		
		// Set Done button
		NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
		self.navigationItem.rightBarButtonItem = doneButton;	
		
		// Create toolbar for never button
		if (displayNeverButton)
		{
			UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
			UIBarButtonItem *neverButton = [[UIBarButtonItem alloc] initWithTitle:neverTitle style:UIBarButtonItemStyleBordered target:self action:@selector(handleNever:)];
			self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, neverButton, nil];	
		}
		
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		if (controllerMode == DateTimePickerViewControllerModePickDate)
		{
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		}
		else if (controllerMode == DateTimePickerViewControllerModePickTime)
		{
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		}		
    }
    return self;	
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
		
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;

	// Define picker view properties
	if (controllerMode == DateTimePickerViewControllerModePickDate)
		datePicker.datePickerMode = UIDatePickerModeDate;
	else if (controllerMode == DateTimePickerViewControllerModePickTime)
	{
		datePicker.datePickerMode = UIDatePickerModeTime;
		datePicker.minuteInterval = minuteInterval;
	}
	else // DateTime
	{
		datePicker.datePickerMode = UIDatePickerModeDateAndTime;
		datePicker.minuteInterval = minuteInterval;
	}
	
	// Load the displayCell from the Nib
	if (nibName != nil)
		[[DosecastUtil getResourceBundle] loadNibNamed:nibName owner:self options:nil];
}

- (void)updateDisplayCellLabelWithDate
{
	if (displayCell != nil)
	{
		UILabel* displayHeader = (UILabel*)[displayCell viewWithTag:1];
		displayHeader.text = cellHeaderText;
		UILabel* displayLabel = (UILabel*)[displayCell viewWithTag:2];
		NSMutableString* displayLabelText = nil;
		if (controllerMode == DateTimePickerViewControllerModePickDateTime)
		{
			NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDate* now = [NSDate date];
			unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
			
			// Get the day/month/year for today and for the date given
			NSDateComponents* todayComponents = [cal components:unitFlags fromDate:now];
			NSDateComponents* dateValComponents = [cal components:unitFlags fromDate:currDate];
			
			// If given date is today
			if ([todayComponents day] == [dateValComponents day] &&
				[todayComponents month] == [dateValComponents month] &&
				[todayComponents year] == [dateValComponents year])
			{
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerTodayTime", @"Dosecast", [DosecastUtil getResourceBundle], @"Today at %@", @"The text in the main cell of the DateTimePicker view when the date is today"]);
				displayLabelText = [NSMutableString stringWithFormat:dateFormatText, [dateFormatter stringFromDate:currDate]];
			}
			else
			{

				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				NSString* dateStr = [dateFormatter stringFromDate:currDate];
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				NSString* timeStr = [dateFormatter stringFromDate:currDate];
				NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerFutureTime", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ at %@", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
				displayLabelText = [NSMutableString stringWithFormat:dateFormatText, dateStr, timeStr];
			}
		}
		else
			displayLabelText = [NSMutableString stringWithString:[dateFormatter stringFromDate:currDate]];
		displayLabel.text = displayLabelText;
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
	// For times, round them to the nearest time minute interval
	if ((controllerMode == DateTimePickerViewControllerModePickTime ||
		controllerMode == DateTimePickerViewControllerModePickDateTime) && minuteInterval > 1)
	{
		double uTime = [currDate timeIntervalSince1970];
		uTime = ceil(uTime / (minuteInterval * 60)) * minuteInterval * 60;
		currDate = [NSDate dateWithTimeIntervalSince1970:uTime];
	}
	datePicker.date = currDate;
	[self updateDisplayCellLabelWithDate];
	
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
	datePicker.date = currDate;
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

- (void)handleDelegateDateTimeCancel:(NSTimer*)theTimer
{
	if ([controllerDelegate respondsToSelector:@selector(handleCancelDateTime:)])
	{
		[controllerDelegate handleCancelDateTime:uniqueIdentifier];
	}
}

- (void)handleCancel:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];
    
    // Inform the delegate, but give the view controllers time to update first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleDelegateDateTimeCancel:) userInfo:nil repeats:NO];
}

- (void)handleNever:(id)sender
{
	if ([controllerDelegate respondsToSelector:@selector(handleSetDateTimeValue:forNibNamed:identifier:)])
	{
		[controllerDelegate handleSetDateTimeValue:nil forNibNamed:nibName identifier:uniqueIdentifier];
	}	
	[self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleDateTimeValueChanged:(id)sender
{
	currDate = [datePicker.date copy];
	[self updateDisplayCellLabelWithDate];
}

- (void)handleDone:(id)sender
{
	BOOL success = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleSetDateTimeValue:forNibNamed:identifier:)])
	{
		success = [controllerDelegate handleSetDateTimeValue:datePicker.date forNibNamed:nibName identifier:uniqueIdentifier];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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

@end
