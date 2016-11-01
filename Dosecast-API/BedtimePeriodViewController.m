//
//  BedtimePeriodViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "BedtimePeriodViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"

@implementation BedtimePeriodViewController

@synthesize tableView;
@synthesize datePicker;
@synthesize bedtimeStartCell;
@synthesize bedtimeEndCell;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil bedtimeStartDate:nil bedtimeEndDate:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
     bedtimeStartDate:(NSDate*)bedtimeStartDateVal
       bedtimeEndDate:(NSDate*)bedtimeEndDateVal
             delegate:(NSObject<BedtimePeriodViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization		
                
		delegate = del;
		
		self.title = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime", @"The title of the Bedtime Period view"]);

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        
        bedtimeStartDate = bedtimeStartDateVal;
		bedtimeEndDate = bedtimeEndDateVal;
		bedtimeStartSelected = YES;
		dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		
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


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	
	// Define picker view properties
	datePicker.datePickerMode = UIDatePickerModeTime;
	datePicker.minuteInterval = 5;
		
	[[DosecastUtil getResourceBundle] loadNibNamed:@"BedtimePeriodTableViewCells" owner:self options:nil];	
}

- (void)setPickerToSelectedTime
{
	if (bedtimeStartSelected)
		[datePicker setDate:bedtimeStartDate animated:YES];
	else
		[datePicker setDate:bedtimeEndDate animated:YES];
}

- (void)updateSelectedDisplayTime
{
	if (bedtimeStartSelected)
	{
		UILabel* bedtimeStartLabel = (UILabel*)[bedtimeStartCell viewWithTag:2];
		bedtimeStartLabel.text = [dateFormatter stringFromDate:bedtimeStartDate];
	}
	else
	{
		UILabel* bedtimeEndLabel = (UILabel*)[bedtimeEndCell viewWithTag:2];
		bedtimeEndLabel.text = [dateFormatter stringFromDate:bedtimeEndDate];
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self setPickerToSelectedTime];
	[self updateSelectedDisplayTime];
		
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
	[self setPickerToSelectedTime];
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
	if ([delegate respondsToSelector:@selector(handleSetBedtimePeriod:bedtimeEndDate:)])
	{
		[delegate handleSetBedtimePeriod:bedtimeStartDate bedtimeEndDate:bedtimeEndDate];
	}
	[self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleDateTimeValueChanged:(id)sender
{
	// Check for valid bedtime	
	if (bedtimeStartSelected)
	{
		// Bedtime is valid - update it
		bedtimeStartDate = datePicker.date;
	}
	else
	{
		// Bedtime is valid - update it
		bedtimeEndDate = datePicker.date;
	}
	[self updateSelectedDisplayTime];
}
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 2;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == 0)
	{
		UILabel* bedtimeStartHeader = (UILabel*)[bedtimeStartCell viewWithTag:1];
		bedtimeStartHeader.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodBedtimeStarts", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime Starts", @"The label of the bedtime starts cell in the Bedtime Period view"]);
		UILabel* bedtimeStartLabel = (UILabel*)[bedtimeStartCell viewWithTag:2];
		bedtimeStartLabel.text = [dateFormatter stringFromDate:bedtimeStartDate];
		
		if (bedtimeStartSelected)
		{
			bedtimeStartHeader.textColor = [UIColor blackColor];
			bedtimeStartLabel.textColor = [UIColor blackColor];
		}
		else
		{
			bedtimeStartHeader.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
			bedtimeStartLabel.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
		}
		
		return bedtimeStartCell;
	}
	else // indexPath.row == 1
	{
		UILabel* bedtimeEndHeader = (UILabel*)[bedtimeEndCell viewWithTag:1];
		bedtimeEndHeader.text = NSLocalizedStringWithDefaultValue(@"ViewBedtimePeriodBedtimeEnds", @"Dosecast", [DosecastUtil getResourceBundle], @"Bedtime Ends", @"The label of the bedtime ends cell in the Bedtime Period view"]);
		UILabel* bedtimeEndLabel = (UILabel*)[bedtimeEndCell viewWithTag:2];
		bedtimeEndLabel.text = [dateFormatter stringFromDate:bedtimeEndDate];
		
		if (bedtimeStartSelected)
		{
			bedtimeEndHeader.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
			bedtimeEndLabel.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
		}
		else
		{
			bedtimeEndHeader.textColor = [UIColor blackColor];
			bedtimeEndLabel.textColor = [UIColor blackColor];
		}
		
		return bedtimeEndCell;
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
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	bedtimeStartSelected = (indexPath.row == 0);
	
	// Update the picker
	[self setPickerToSelectedTime];
	[self.tableView reloadData];	
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
