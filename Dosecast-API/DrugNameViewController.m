//
//  DrugNameViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "DrugNameViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "DosecastAPIFlags.h"
#import "FlagDictionary.h"
#import "DrugDatabaseSearchController.h"
#import "Medication.h"
#import "AccountViewController.h"
#import "GlobalSettings.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int MAX_CHARACTERS = 1024;

@implementation DrugNameViewController

@synthesize tableView;
@synthesize drugNameCell;
@synthesize drugDatabaseCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
						  bundle:nibBundleOrNil
                        drugName:nil
                placeholderValue:nil
						delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
             drugName:(NSString*)name
     placeholderValue:(NSString*)placeholder
			 delegate:(NSObject<DrugNameViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

		self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);
        if (!name)
            name = @"";
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		drugName = [[NSMutableString alloc] initWithString:name];
        if (!placeholder)
            placeholder = @"";
		placeholderValue = placeholder;
		controllerDelegate = delegate;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Cap the total length of the string
    NSString* newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL allow = ([newValue length] <= MAX_CHARACTERS);
    if (allow)
        [drugName setString:newValue];
    return allow;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    [drugName setString:@""];
    return YES;
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
    UITextField *textField = (UITextField*)[drugNameCell viewWithTag:1];
    [textField becomeFirstResponder];
}

- (void)hideKeyboard
{
    UITextField *textField = (UITextField*)[drugNameCell viewWithTag:1];
    if ([textField isFirstResponder])
        [textField resignFirstResponder];
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
	
	if ([controllerDelegate respondsToSelector:@selector(handleDrugNameEntryDone:)])
	{
		[controllerDelegate handleDrugNameEntryDone:drugName];
	}
}

// Callback when user presses Return button on keyboard when editing a text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{	
	[self handleDone:textField];
	return YES;
}

- (void) handleDrugDatabaseSearchResult:(Medication *)permutation resultMatch:(MedicationResultMatch)resultMatch
{
	if ([controllerDelegate respondsToSelector:@selector(handleDrugDatabaseEntryDone:resultMatch:)])
	{
		[controllerDelegate handleDrugDatabaseEntryDone:permutation resultMatch:resultMatch];
	}
}

#pragma mark Table view methods

- (BOOL) isUSDrugDatabaseSearchEnabled
{
    DataModel* dataModel = [DataModel getInstance];    
    NSString* languageCountryCode = [DosecastUtil getLanguageCountryCode];
    return ([dataModel.apiFlags getFlag:DosecastAPIEnableUSDrugDatabaseSearch] && [languageCountryCode compare:@"en_US" options:NSLiteralSearch] == NSOrderedSame);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
        
    // If the US drug database is enabled, and this locale is en_US, then display the button to search the drug database
    if ([self isUSDrugDatabaseSearchEnabled])
        return 2;
    else
        return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {        
        UITextField *textField = (UITextField*)[drugNameCell viewWithTag:1];
        
        // Initialize the properties of the cell
        textField.text = drugName;
        textField.placeholder = placeholderValue;
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.secureTextEntry = NO;        
        
        return drugNameCell;
    }
    else // indexPath.section == 1
    {
        UILabel *buttonLabel = (UILabel*)[drugDatabaseCell viewWithTag:1];

        buttonLabel.text = NSLocalizedStringWithDefaultValue(@"ViewDrugNameButtonSearchDrugDatabase", @"Dosecast", [DosecastUtil getResourceBundle], @"Search Drug Database", @"The Search Drug Database button of the Drug Name view"]);
        return drugDatabaseCell;
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
    if ([self isUSDrugDatabaseSearchEnabled] && section == 0)
        return NSLocalizedStringWithDefaultValue(@"ViewDrugNameFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter the name of the medication or search the medication database.", @"The footer text of the Drug Name view"]);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    
    if (indexPath.section == 0)
    {
        [self showKeyboard];
    }
    else if (indexPath.section == 1 && [self isUSDrugDatabaseSearchEnabled])
    {
        // Premium-only feature
        DataModel* dataModel = [DataModel getInstance];
        if (dataModel.globalSettings.accountType == AccountTypeDemo)
        {
            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Pro Feature", @"The title on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                       message:NSLocalizedStringWithDefaultValue(@"ErrorFeatureSubscriptionDrugDatabase", @"Dosecast", [DosecastUtil getResourceBundle], @"The drug database is available in the premium edition. To learn more about this and other features in the premium edition, tap the 'Upgrade' button below.", @"The message on the alert appearing when a premium feature is accessed in the demo edition"])
                                                                                         style:DosecastAlertControllerStyleAlert];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonNotNow", @"Dosecast", [DosecastUtil getResourceBundle], @"Not Now", @"The text on the Not Now button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:nil]];
            
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertFeatureSubscriptionButtonSubscribe", @"Dosecast", [DosecastUtil getResourceBundle], @"Subscribe", @"The Upgrade button of the alert appearing when a premium feature is accessed in demo edition"])
                                            style:DosecastAlertActionStyleDefault
                                          handler:^(DosecastAlertAction *action){
                                              // Push the account view controller
                                              
                                              // Set Back button title
                                              NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
                                              UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
                                              backButton.style = UIBarButtonItemStylePlain;
                                              if (!backButton.image)
                                                  backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
                                              self.navigationItem.backBarButtonItem = backButton;
                                              
                                              // Display AccountViewController in new view
                                              AccountViewController* accountController = [[AccountViewController alloc]
                                                                                          initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"AccountViewController"]
                                                                                          bundle:[DosecastUtil getResourceBundle] delegate:nil];
                                              [self.navigationController pushViewController:accountController animated:YES];
                                          }]];
            
            [alert showInViewController:self];
        }
        else
        {
            // Set Back button title
            NSArray* toolbarButtons = [[DosecastUtil getResourceBundle] loadNibNamed:@"ToolbarButtons" owner:self options:nil];
            UIBarButtonItem *backButton = [toolbarButtons objectAtIndex:0];
            backButton.style = UIBarButtonItemStylePlain;
            if (!backButton.image)
                backButton.title = NSLocalizedStringWithDefaultValue(@"ToolbarButtonBack", @"Dosecast", [DosecastUtil getResourceBundle], @"Back", @"The text on the Back toolbar button"]);
            self.navigationItem.backBarButtonItem = backButton;

            DrugDatabaseSearchController* searchController = [[DrugDatabaseSearchController alloc]
                                                                     initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugDatabaseSearchController"]
                                                                     bundle:[DosecastUtil getResourceBundle]
                                                                     delegate:self];
            [self.navigationController pushViewController:searchController animated:YES];
        }
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



@end
