//
//  BooleanViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "BooleanViewController.h"
#import "DosecastUtil.h"

@implementation BooleanViewController

@synthesize tableView;
@synthesize booleanCell;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil initialValue:NO viewTitle:nil displayTitle:nil headerText:nil footerText:nil identifier:nil subIdentifier:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
         initialValue:(BOOL)v
			viewTitle:(NSString*)vTitle
         displayTitle:(NSString*)dTitle
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<BooleanViewControllerDelegate>*)d
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        value = v;
		delegate = d;
		headerText = header;
		footerText = footer;
		self.title = vTitle;
        self.hidesBottomBarWhenPushed = YES;
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        displayTitle = dTitle;
		identifier = Id;
		subIdentifier = subId;
   }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
    tableView.allowsSelectionDuringEditing = YES;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
    NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
    UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
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


- (IBAction)handleDone:(id)sender
{
    BOOL allowPop = YES;
    if (delegate && [delegate respondsToSelector:@selector(handleBooleanDone:identifier:subIdentifier:)])
    {
        allowPop = [delegate handleBooleanDone:value identifier:identifier subIdentifier:subIdentifier];
    }
    if (allowPop)
        [self.navigationController popViewControllerAnimated:YES];			
}

- (IBAction)handleCancel:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)handleSwitch:(id)sender
{
    value = !value;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{    
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *) createNewItemCell
{
    static NSString *MyIdentifier = @"PillCellIdentifier";

    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"BooleanViewCell" owner:self options:nil];
        cell = booleanCell;
        booleanCell = nil;
        
        // Setup callback for switch
        UISwitch* s = (UISwitch *)[cell viewWithTag:2];
        [s addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];	
    }
    
    return cell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [self createNewItemCell];
    
    // Set main label
    UILabel* displayLabel = (UILabel *)[cell viewWithTag:1];
    displayLabel.text = displayTitle;
    
    // Determine whether switched on
    UISwitch* s = (UISwitch *)[cell viewWithTag:2];
    s.on = value;

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return headerText;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return footerText;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}



@end

