//
//  ChecklistViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "ChecklistViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"

@implementation ChecklistViewController

@synthesize tableView;
@synthesize checkboxCell;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil items:nil checkedItems:nil viewTitle:nil headerText:nil footerText:nil allowNone:NO identifier:nil subIdentifier:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
				items:(NSArray*)i
		 checkedItems:(NSArray*)ci
			viewTitle:(NSString*)viewTitle
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
            allowNone:(BOOL)none
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<ChecklistViewControllerDelegate>*)d
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		items = [[NSArray alloc] initWithArray:i];
        checkedStatusDict = [[NSMutableDictionary alloc] init];
        self.hidesBottomBarWhenPushed = YES;
        for (NSNumber* index in ci)
        {
            [checkedStatusDict setObject:[NSNumber numberWithInt:1] forKey:index];
        }
		delegate = d;
		headerText = header;
		footerText = footer;
		self.title = viewTitle;
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		identifier = Id;
		subIdentifier = subId;
		allowNone = none;
        doneButton = nil;
   }
    return self;
}

- (BOOL)isAtLeastOneItemChecked
{
    NSArray* allKeys = [checkedStatusDict allKeys];
    for (NSNumber* index in allKeys)
    {
        NSNumber* isCheckedNum = [checkedStatusDict objectForKey:index];
        BOOL isChecked = isCheckedNum && [isCheckedNum intValue] == 1;
        if (isChecked)
            return YES;
    }
    
    return NO;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;
    doneButton.enabled = allowNone || [self isAtLeastOneItemChecked];
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
	if ([delegate respondsToSelector:@selector(handleDoneCheckingItemsInList:identifier:subIdentifier:)])
	{
        NSMutableArray* results = [[NSMutableArray alloc] init];
        NSArray* allKeys = [checkedStatusDict allKeys];
        for (NSNumber* index in allKeys)
        {
            NSNumber* isCheckedNum = [checkedStatusDict objectForKey:index];
            BOOL isChecked = isCheckedNum && [isCheckedNum intValue] == 1;
            if (isChecked)
                [results addObject:index];
        }
        [results sortUsingSelector:@selector(compare:)];
		allowPop = [delegate handleDoneCheckingItemsInList:results identifier:identifier subIdentifier:subIdentifier];
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

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [items count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"PillCellIdentifier";
	
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"ChecklistViewCell" owner:self options:nil];
        cell = checkboxCell;
        checkboxCell = nil;
    }
    	
	// Set main label
	UILabel* mainLabel = (UILabel *)[cell viewWithTag:1];
	mainLabel.text = [items objectAtIndex:indexPath.row];
	    
	// Determine whether checked
    NSNumber* isCheckedNum = [checkedStatusDict objectForKey:[NSNumber numberWithInt:(int)indexPath.row]];
    BOOL isChecked = isCheckedNum && [isCheckedNum intValue] == 1;

	if (isChecked)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;	
	else
		cell.accessoryType = UITableViewCellAccessoryNone;	
	
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

    NSNumber* isCheckedNum = [checkedStatusDict objectForKey:[NSNumber numberWithInt:(int)indexPath.row]];
    BOOL isChecked = isCheckedNum && [isCheckedNum intValue] == 1;
    isChecked = !isChecked;
    [checkedStatusDict setObject:[NSNumber numberWithInt:(isChecked ? 1 : 0)] forKey:[NSNumber numberWithInt:(int)indexPath.row]];

    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];

	if (isChecked)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;
    
    doneButton.enabled = allowNone || [self isAtLeastOneItemChecked];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}



@end

