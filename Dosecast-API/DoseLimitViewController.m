//
//  DoseLimitViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DoseLimitViewController.h"
#import "DosecastUtil.h"
#import "NumericPickerViewController.h"
#import "DrugDosageUnitManager.h"

@implementation DoseLimitViewController

@synthesize tableView;
@synthesize doseLimitNoneCell;
@synthesize doseLimitPerDayCell;
@synthesize doseLimitPer24HrsCell;
@synthesize maxNumDosesCell;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil limitType:DoseLimitViewControllerLimitTypeNever maxNumDoses:0 delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            limitType:(DoseLimitViewControllerLimitType)limit
          maxNumDoses:(int)max
			 delegate:(NSObject<DoseLimitViewControllerDelegate>*)del
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
		
		delegate = del;
        limitType = limit;
        if (max <= 0)
            max = 1;
        maxNumDoses = max;
        self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title =  NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 16;	
	
	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	
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

// Callback for numeric quantity
// If val is negative, this corresponds to 'None'. Returns whether to pop the view controller.
- (BOOL)handleSetNumericQuantity:(float)val
                            unit:(NSString*)unit
                      identifier:(NSString*)Id
                   subIdentifier:(NSString*)subId
{
    maxNumDoses = val;
    [self.tableView reloadData];
    
    return YES;
}

- (IBAction)handleDone:(id)sender
{
    if ([delegate respondsToSelector:@selector(handleSetDoseLimit:maxNumDoses:)])
    {
        int maxNum = maxNumDoses;
        if (limitType == DoseLimitViewControllerLimitTypeNever)
            maxNum = 0;
        [delegate handleSetDoseLimit:limitType maxNumDoses:maxNum];
    }					
    [self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleCancel:(id)sender
{
	[self.navigationController popViewControllerAnimated:YES];			
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (limitType == DoseLimitViewControllerLimitTypeNever)
        return 1;
    else
        return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
    if (section == 0)
        return 3;
    else
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
	{
        if (indexPath.row == 0)
        {
            UILabel* headerLabel = (UILabel *)[doseLimitNoneCell viewWithTag:1];		
            headerLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTypeNone", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The Dose Limit Never type label in the Dose Limit view"]);

            if (limitType == DoseLimitViewControllerLimitTypeNever)
            {
                doseLimitNoneCell.accessoryType = UITableViewCellAccessoryCheckmark;
                doseLimitNoneCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                doseLimitNoneCell.accessoryType = UITableViewCellAccessoryNone;
                doseLimitNoneCell.editingAccessoryType = UITableViewCellAccessoryNone;                
            }
            return doseLimitNoneCell;
        }
        else if (indexPath.row == 1)
        {
            UILabel* headerLabel = (UILabel *)[doseLimitPerDayCell viewWithTag:1];		
            headerLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTypePerDay", @"Dosecast", [DosecastUtil getResourceBundle], @"Per day", @"The Dose Limit Per Day type label in the Dose Limit view"]);

            if (limitType == DoseLimitViewControllerLimitTypePerDay)
            {
                doseLimitPerDayCell.accessoryType = UITableViewCellAccessoryCheckmark;
                doseLimitPerDayCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                doseLimitPerDayCell.accessoryType = UITableViewCellAccessoryNone;
                doseLimitPerDayCell.editingAccessoryType = UITableViewCellAccessoryNone;                
            }

            return doseLimitPerDayCell;
        }
        else // indexPath.row == 2
        {
            UILabel* headerLabel = (UILabel *)[doseLimitPer24HrsCell viewWithTag:1];		
            headerLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTypePer24Hours", @"Dosecast", [DosecastUtil getResourceBundle], @"Per 24 hrs", @"The Dose Limit Per 24 Hours type label in the Dose Limit view"]);

            if (limitType == DoseLimitViewControllerLimitTypePer24Hours)
            {
                doseLimitPer24HrsCell.accessoryType = UITableViewCellAccessoryCheckmark;
                doseLimitPer24HrsCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                doseLimitPer24HrsCell.accessoryType = UITableViewCellAccessoryNone;
                doseLimitPer24HrsCell.editingAccessoryType = UITableViewCellAccessoryNone;                
            }

            return doseLimitPer24HrsCell;
        }
	}
	else // indexPath.section == 1
	{
        UILabel* label = (UILabel *)[maxNumDosesCell viewWithTag:1];
        if (limitType == DoseLimitViewControllerLimitTypePerDay)
            label.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitMaxDosesPerDay", @"Dosecast", [DosecastUtil getResourceBundle], @"Max Doses Per Day", @"The Max Doses Per Day label in the Dose Limit view"]);
        else // DoseLimitViewControllerLimitTypePer24Hours
            label.text = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitMaxDosesPer24Hours", @"Dosecast", [DosecastUtil getResourceBundle], @"Max Doses Per 24 Hrs", @"The Max Doses Per 24 Hours label in the Dose Limit view"]);

        UILabel* value = (UILabel *)[maxNumDosesCell viewWithTag:2];
        value.text = [NSString stringWithFormat:@"%d", maxNumDoses];
        
		return maxNumDosesCell;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"]);
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
        return NSLocalizedStringWithDefaultValue(@"ViewDoseLimitFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Limiting doses per day allows up to a maximum number of doses to be taken during one calendar day. Limiting doses per 24 hrs allows up to a maximum number of doses to be taken during any 24 hr period.", @"The footer of the Dose Limit view"]);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    if (indexPath.section == 0)
    {
        [self.tableView beginUpdates];
        if (indexPath.row == 0 && limitType != DoseLimitViewControllerLimitTypeNever)
        {
            // Update checkmarks
            doseLimitNoneCell.accessoryType = UITableViewCellAccessoryCheckmark;
            doseLimitNoneCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
            doseLimitPerDayCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitPerDayCell.editingAccessoryType = UITableViewCellAccessoryNone;
            doseLimitPer24HrsCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitPer24HrsCell.editingAccessoryType = UITableViewCellAccessoryNone;            

            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationLeft];

            limitType = DoseLimitViewControllerLimitTypeNever;            
        }
        else if (indexPath.row == 1 && limitType != DoseLimitViewControllerLimitTypePerDay)
        {
            // Update checkmarks
            doseLimitNoneCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitNoneCell.editingAccessoryType = UITableViewCellAccessoryNone;
            doseLimitPerDayCell.accessoryType = UITableViewCellAccessoryCheckmark;
            doseLimitPerDayCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;
            doseLimitPer24HrsCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitPer24HrsCell.editingAccessoryType = UITableViewCellAccessoryNone;            

            if (limitType == DoseLimitViewControllerLimitTypeNever)
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationRight];
            else
            {
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
            }
            
            limitType = DoseLimitViewControllerLimitTypePerDay;            
        }
        else if (indexPath.row == 2 && limitType != DoseLimitViewControllerLimitTypePer24Hours)
        {
            // Update checkmarks
            doseLimitNoneCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitNoneCell.editingAccessoryType = UITableViewCellAccessoryNone;
            doseLimitPerDayCell.accessoryType = UITableViewCellAccessoryNone;
            doseLimitPerDayCell.editingAccessoryType = UITableViewCellAccessoryNone;
            doseLimitPer24HrsCell.accessoryType = UITableViewCellAccessoryCheckmark;
            doseLimitPer24HrsCell.editingAccessoryType = UITableViewCellAccessoryCheckmark;            

            if (limitType == DoseLimitViewControllerLimitTypeNever)
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationRight];
            else
            {
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
            }
            
            limitType = DoseLimitViewControllerLimitTypePer24Hours;
        }
        [self.tableView endUpdates];        
    }
	else if (indexPath.section == 1)
	{
        NSString* displayTitle = nil;
        if (limitType == DoseLimitViewControllerLimitTypePerDay)
            displayTitle = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitMaxDosesPerDay", @"Dosecast", [DosecastUtil getResourceBundle], @"Max Doses Per Day", @"The Max Doses Per Day label in the Dose Limit view"]);
        else // DoseLimitViewControllerLimitTypePer24Hours
            displayTitle = NSLocalizedStringWithDefaultValue(@"ViewDoseLimitMaxDosesPer24Hours", @"Dosecast", [DosecastUtil getResourceBundle], @"Max Doses Per 24 Hrs", @"The Max Doses Per 24 Hours label in the Dose Limit view"]);

        // Display the picker
        NumericPickerViewController* numericController = [[NumericPickerViewController alloc]
                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"NumericPickerViewController"]
														  bundle:[DosecastUtil getResourceBundle]
                                                          sigDigits:2
                                                          numDecimals:0
                                                          viewTitle:NSLocalizedStringWithDefaultValue(@"ViewDoseLimitTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Limit Doses", @"The title of the Dose Limit view"])
                                                          displayTitle:displayTitle
                                                          initialVal:maxNumDoses
                                                          initialUnit:nil
                                                          possibleUnits:nil
                                                          displayNone:NO
                                                          allowZeroVal:NO
                                                          identifier:nil
                                                          subIdentifier:nil
                                                          delegate:self];
        [self.navigationController pushViewController:numericController animated:YES];
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
