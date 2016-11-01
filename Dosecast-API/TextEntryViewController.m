//
//  TextEntryViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "TextEntryViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"

static const int MAX_CHARACTERS = 1024;

@implementation TextEntryViewController

@synthesize tableView;
@synthesize textEntryCell;
@synthesize textEntryMultilineCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
						  bundle:nibBundleOrNil
					   viewTitle:nil
				   numTextFields:0
                       multiline:NO
				   initialValues:[[NSArray alloc] init]
			  placeholderStrings:[[NSArray alloc] init]
			  capitalizationType:UITextAutocapitalizationTypeNone
				  correctionType:UITextAutocorrectionTypeNo
					keyboardType:UIKeyboardTypeDefault
				 secureTextEntry:NO
                      identifier:nil
                   subIdentifier:nil
						delegate:nil];
}

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			viewTitle:(NSString*)viewTitle
		numTextFields:(int)numFields
            multiline:(BOOL)multi
		initialValues:(NSArray*)initialVals
   placeholderStrings:(NSArray*)placeholders
   capitalizationType:(UITextAutocapitalizationType)capitalization
	   correctionType:(UITextAutocorrectionType)correction
		 keyboardType:(UIKeyboardType)keyboard
	  secureTextEntry:(BOOL)secure
           identifier:(NSString*)Id
        subIdentifier:(NSString*)subId
			 delegate:(NSObject<TextEntryViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        identifier = Id;
        subIdentifier = subId;
		self.title = viewTitle;
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		numTextFields = numFields;
		initialValues = [[NSArray alloc] initWithArray:initialVals];
		placeholderStrings = [[NSArray alloc] initWithArray:placeholders];
		capitalizationType = capitalization;
		correctionType = correction;
		keyboardType = keyboard;
		secureTextEntry = secure;
		controllerDelegate = delegate;
		textItemWithFocus = 0; // the first text item should get focus by default
        multiline = multi;
        
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Cap the total length of the string
    NSString* newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    return [newValue length] <= MAX_CHARACTERS;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // Cap the total length of the string
    NSString* currValue = textView.text;
    NSString* newValue = [currValue stringByReplacingCharactersInRange:range withString:text];
    int length = (int)[newValue length];
    return length <= MAX_CHARACTERS;    
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
	// Set Done button
	NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;	
	
	tableView.sectionHeaderHeight = 16;
	tableView.sectionFooterHeight = 16;
	tableView.allowsSelection = YES;
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

- (void)showKeyboard
{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:textItemWithFocus inSection:0];
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    if (multiline)
    {
        UITextView *textView = (UITextView*)[cell viewWithTag:1];
        [textView becomeFirstResponder];
    }
    else
    {
        UITextField *textField = (UITextField*)[cell viewWithTag:1];
        [textField becomeFirstResponder];
    }
}

- (void)hideKeyboard
{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:textItemWithFocus inSection:0];
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    if (multiline)
    {
        UITextView *textView = (UITextView*)[cell viewWithTag:1];
        if ([textView isFirstResponder])
            [textView resignFirstResponder];
    }
    else
    {
        UITextField *textField = (UITextField*)[cell viewWithTag:1];
        if ([textField isFirstResponder])
            [textField resignFirstResponder];
    }
}

// Called prior to rotating the device orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{	
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	[tableView reloadData];
}

// Called after rotating the device orientation
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	[super didRotateFromInterfaceOrientation:interfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self showKeyboard];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
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
	[self hideKeyboard];
	
	BOOL success = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleTextEntryDone:identifier:subIdentifier:)])
	{
		// Build an array of text values
		NSMutableArray* textValues = [[NSMutableArray alloc] init];
		for (int i = 0; i < numTextFields; i++)
		{
			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:i inSection:0];
			UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
            if (multiline)
            {
                UITextView *textView = (UITextView*)[cell viewWithTag:1];
                [textValues addObject:[NSString stringWithString:textView.text]];
            }
            else
            {
                UITextField *textField = (UITextField*)[cell viewWithTag:1];
                [textValues addObject:[NSString stringWithString:textField.text]];                
            }
		}
		success = [controllerDelegate handleTextEntryDone:textValues identifier:identifier subIdentifier:subIdentifier];
	}
	if (success)
		[self.navigationController popViewControllerAnimated:YES];
}

// Callback when user presses Return button on keyboard when editing a text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{	
	[self handleDone:textField];
	return YES;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return numTextFields;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (multiline)
    {
        static NSString *MyIdentifier = @"MultilinePillCellIdentifier";
        
        cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
        if (cell == nil) {
            [[DosecastUtil getResourceBundle] loadNibNamed:@"TextEntryMultilineTableViewCell" owner:self options:nil];
            cell = textEntryMultilineCell;
            textEntryMultilineCell = nil;
        }
        
        UITextView *textView = (UITextView*)[cell viewWithTag:1];
        
        // Initialize the properties of the cell
        NSString* textVal = [initialValues objectAtIndex:indexPath.row];
        textView.text = textVal;
        textView.editable = YES;
        textView.dataDetectorTypes = UIDataDetectorTypeNone;        
        textView.autocapitalizationType = capitalizationType;
        textView.autocorrectionType = correctionType;
        textView.keyboardType = keyboardType;
        textView.secureTextEntry = secureTextEntry;
    }
    else
    {
        static NSString *MyIdentifier = @"PillCellIdentifier";
        
        cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
        if (cell == nil) {
            [[DosecastUtil getResourceBundle] loadNibNamed:@"TextEntryTableViewCell" owner:self options:nil];
            cell = textEntryCell;
            textEntryCell = nil;
        }
        
        UITextField *textField = (UITextField*)[cell viewWithTag:1];
        
        // Initialize the properties of the cell
        NSString* textVal = [initialValues objectAtIndex:indexPath.row];
        textField.text = textVal;
        NSString* placeholderText = [placeholderStrings objectAtIndex:indexPath.row];
        textField.placeholder = placeholderText;
        textField.autocapitalizationType = capitalizationType;
        textField.autocorrectionType = correctionType;
        textField.keyboardType = keyboardType;
        textField.secureTextEntry = secureTextEntry;        
    }
	
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (multiline)
        return 134;
    else
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
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
	
	// Change focus to the field in the given cell
    textItemWithFocus = (int)indexPath.row;
    [self showKeyboard];
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
