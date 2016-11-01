//
//  NumericPickerViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "NumericPickerViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "DrugDosage.h"
#import "DrugDosageUnitManager.h"

@implementation NumericPickerViewController

@synthesize tableView;
@synthesize pickerView;
@synthesize displayCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil sigDigits:0 numDecimals:0 viewTitle:nil displayTitle:nil initialVal:0.0f initialUnit:nil possibleUnits:nil displayNone:NO allowZeroVal:NO identifier:nil subIdentifier:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            sigDigits:(int)sigDigits
          numDecimals:(int)decimals
            viewTitle:(NSString*)viewTitle
         displayTitle:(NSString*)dispTitle
           initialVal:(float)initialVal
          initialUnit:(NSString*)initialUnit
        possibleUnits:(NSArray*)units
          displayNone:(BOOL)displayNone
         allowZeroVal:(BOOL)allowZero
           identifier:(NSString*)Id
        subIdentifier:(NSString*)subId
             delegate:(NSObject<NumericPickerViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization

        displayCell = nil;
		numSigDigits = sigDigits;
		numDecimals = decimals;
		controllerDelegate = delegate;
		displayTitle = dispTitle;
		val = initialVal;
		unit = initialUnit;
		possibleUnits = units;
		displayNoneButton = displayNone;
		allowZeroVal = allowZero;
		identifier = Id;
		subIdentifier = subId;
		
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
		const float epsilon = 0.0001;
		doneButton.enabled = (allowZeroVal || val > epsilon);
		
		// Create toolbar for none button
		if (displayNone)
		{
			NSString* noneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNone", @"Dosecast", [DosecastUtil getResourceBundle], @"None", @"The text on the None toolbar button"]);
			UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
			UIBarButtonItem *noneButton = [[UIBarButtonItem alloc] initWithTitle:noneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleNone:)];
			self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, noneButton, nil];	
		}
        self.hidesBottomBarWhenPushed = !displayNone;
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
	[[DosecastUtil getResourceBundle] loadNibNamed:@"NumericPickerTableViewCell" owner:self options:nil];	
}

- (BOOL)isSelectingUnit
{
	return possibleUnits && [possibleUnits count] > 0 && unit;
}

- (int)numDigitComponents
{
	int numDigitComponents = numSigDigits;
	if (numDecimals > 0)
		numDigitComponents += 1;	
	return numDigitComponents;
}

- (void)updateDisplayCell
{
	if (displayCell != nil)
	{
		UILabel* labelText = (UILabel*)[displayCell viewWithTag:1];
		labelText.text = [NSString stringWithFormat:@"%@", displayTitle];
		
		int numDigitComponents = [self numDigitComponents];

		// Calculate whether we can remove trailing zeroes for display
		NSString* formatStr = [NSString stringWithFormat:@"%%0%d.%df", numDigitComponents, numDecimals];
		NSString* valStr = [NSString stringWithFormat:formatStr, val];			
		int numDecimalsToIgnore = 0;
		BOOL foundNonZeroDigit = NO;
		for (int position = numSigDigits; position > (numSigDigits-numDecimals) && !foundNonZeroDigit; position--)
		{
			NSString* digitStr = [valStr substringWithRange:NSMakeRange(position, 1)];
			if ([digitStr intValue] == 0)
				numDecimalsToIgnore += 1;
			else
				foundNonZeroDigit = YES;
		}
		
		formatStr = [NSString stringWithFormat:@"%%%d.%df", numDigitComponents-numDecimalsToIgnore, numDecimals-numDecimalsToIgnore];
		valStr = [NSString stringWithFormat:formatStr, val];
        // Use locale to determine whether to use '.' or ',' as the decimal separator
		valStr = [valStr stringByReplacingOccurrencesOfString:@"." withString:[DosecastUtil getDecimalSeparator]];
        
		UILabel* displayLabel = (UILabel*)[displayCell viewWithTag:2];
		
		if ([self isSelectingUnit])
		{
			BOOL pluralize = ![DosecastUtil shouldUseSingularForFloat:val];
			displayLabel.text = [NSString stringWithFormat:@"%@ %@", valStr, [DrugDosage getLabelForUnit:unit pluralize:pluralize]];
		}
		else
			displayLabel.text = valStr;
	}
}

- (void)recalcValAndUnit:(float*)newVal newUnit:(NSString**)newUnit
{
	NSMutableString* valStr = [NSMutableString stringWithString:@""];			

	int numDigitComponents = [self numDigitComponents];
	for (int position = 0; position < numDigitComponents; position++)
	{
		if (position == (numSigDigits-numDecimals))
			[valStr appendString:@"."];
		else
		{
			int row = (int)[pickerView selectedRowInComponent:position];
			[valStr appendFormat:@"%d", row];
		}
	}	
	*newVal = [valStr floatValue];
	
	*newUnit = nil;
	if ([self isSelectingUnit])
	{
		*newUnit = [possibleUnits objectAtIndex:[pickerView selectedRowInComponent:numDigitComponents]];
	}
}

// Set picker's rows to val
- (void)updatePickerWithVal
{
	int numDigitComponents = [self numDigitComponents];

	NSString* formatStr = [NSString stringWithFormat:@"%%0%d.%df", numDigitComponents, numDecimals];
	NSString* valStr = [NSString stringWithFormat:formatStr, val];			

	for (int position = 0; position < numDigitComponents; position++)
	{
		if (position != (numSigDigits-numDecimals))
		{
			NSString* digitStr = [valStr substringWithRange:NSMakeRange(position, 1)];
			[pickerView selectRow:[digitStr intValue] inComponent:position animated:NO];
		}
	}
	if ([self isSelectingUnit])
	{
		int numPossibleUnits = (int)[possibleUnits count];
		BOOL found = NO;
		int row = -1;
		for (int i = 0; i < numPossibleUnits && !found; i++)
		{
			NSString* thisUnit = [possibleUnits objectAtIndex:i];
			if ([thisUnit caseInsensitiveCompare:unit] == NSOrderedSame)
			{
				found = YES;
				row = i;
			}
		}
		[pickerView selectRow:row inComponent:numDigitComponents animated:NO];
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
	[self updateDisplayCell];
	[self updatePickerWithVal];
		
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
	[self updatePickerWithVal];
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

- (void)handleNone:(id)sender
{
    BOOL popViewController = YES;
	if ([controllerDelegate respondsToSelector:@selector(handleSetNumericQuantity:unit:identifier:subIdentifier:)])
	{
		popViewController = [controllerDelegate handleSetNumericQuantity:-1.0f unit:unit identifier:identifier subIdentifier:subIdentifier];
	}	
    if (popViewController)
        [self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleDone:(id)sender
{
    BOOL popViewController = YES;

	if ([controllerDelegate respondsToSelector:@selector(handleSetNumericQuantity:unit:identifier:subIdentifier:)])
	{
		popViewController = [controllerDelegate handleSetNumericQuantity:val unit:unit identifier:identifier subIdentifier:subIdentifier];
	}	
    if (popViewController)
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

#pragma mark Picker view methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{	
	int numComponents = numSigDigits;
	if (numDecimals > 0)
		numComponents += 1;
	if ([self isSelectingUnit])
		numComponents += 1;
	return numComponents;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	int numDigitComponents = [self numDigitComponents];
	
	if (numDecimals > 0 && component == (numSigDigits-numDecimals))
		return 1;
	else if ([self isSelectingUnit] && component == numDigitComponents)
		return [possibleUnits count];
	else
		return 10;
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
	
	int numDigitComponents = [self numDigitComponents];
	if (numDecimals > 0 && component == (numSigDigits-numDecimals))
		label.text = [NSString stringWithString:[DosecastUtil getDecimalSeparator]];
	else if ([self isSelectingUnit] && component == numDigitComponents)
	{
		BOOL pluralize = ![DosecastUtil shouldUseSingularForFloat:val];

		NSString* unitText = [DrugDosage getLabelForUnit:[possibleUnits objectAtIndex:row] pluralize:pluralize];
		NSRange range = [unitText rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
        int fontSize = -1;
		if (range.location != NSNotFound)
		{
			unitText = [NSString stringWithFormat:@"%@\n/%@", [unitText substringToIndex:range.location],
						[unitText substringFromIndex:(range.location+1)]];            
            fontSize = 14;
		}
		else
			fontSize = 16;

        fontSize -= 1;
        
        // Special case: when displaying the unit text 'unit', need to shrink the font size down manually
        NSString* unitString = NSLocalizedStringWithDefaultValue(@"DrugDosageUnitUnitsSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"unit", @"A unit in drug dosages"]);
        NSRange unitRange = [unitText rangeOfString:unitString options:NSCaseInsensitiveSearch];
        if (unitRange.location != NSNotFound)
            fontSize = 11;
        
        label.font = [UIFont boldSystemFontOfSize:fontSize];
		label.text = unitText;
		label.lineBreakMode = NSLineBreakByWordWrapping;
		label.numberOfLines = 2;
	}	
	else
		label.text = [NSString stringWithFormat:@"%d", (int)row];
	return label;	
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	float newVal;
	NSString* newUnit;
	[self recalcValAndUnit:&newVal newUnit:&newUnit];
	const float epsilon = 0.0001;

	int numDigitComponents = [self numDigitComponents];
	if (([self isSelectingUnit]) &&
		(([DosecastUtil shouldUseSingularForFloat:val] && ![DosecastUtil shouldUseSingularForFloat:newVal]) ||
		 ([DosecastUtil shouldUseSingularForFloat:newVal] && ![DosecastUtil shouldUseSingularForFloat:val])))
	{
		[self.pickerView reloadComponent:numDigitComponents]; // reload units
	}
	
	val = newVal;
	unit = newUnit;
		
	[self updateDisplayCell];	
	doneButton.enabled = (allowZeroVal || val > epsilon);
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
	int numDigitComponents = [self numDigitComponents];
	if (numDecimals > 0 && component == (numSigDigits-numDecimals)) // decimal point width
		return 15;
	else if ([self isSelectingUnit] && component == numDigitComponents) // unit width
		return 55;
	else // digit width
    {
        if (numSigDigits >= 7)
            return 30;
        else
            return 35;
    }
}

@end
