//
//  JoinGroupEnterGroupNameViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "JoinGroupEnterGroupNameViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "ServerProxy.h"
#import "ViewDeleteGroupViewController.h"
#import "JoinGroupEnterPasswordViewController.h"
#import "Group.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

static const int MAX_GROUPNAME_CHARACTERS = 25;

@implementation JoinGroupEnterGroupNameViewController

@synthesize tableView;
@synthesize groupNameCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
						  bundle:nibBundleOrNil
						delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<JoinGroupEnterGroupNameViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

		self.title = NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsJoinGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Join Group", @"The Join Group label in the Settings view"]);
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

		groupName = [[NSMutableString alloc] initWithString:@""];
        thisGroup = nil;
        thisLogo = nil;
		controllerDelegate = delegate;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSRange disallowedRange = [string rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
    if (disallowedRange.location != NSNotFound)
        return NO;
    
    // Cap the total length of the string
    NSString* newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL allow = ([newValue length] <= MAX_GROUPNAME_CHARACTERS);
    if (allow)
        [groupName setString:newValue];
    return allow;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    [groupName setString:@""];
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
	
	// Set Next button
	NSString* nextButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNext", @"Dosecast", [DosecastUtil getResourceBundle], @"Next", @"The text on the Next toolbar button"]);
	UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:nextButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleNext:)];
	self.navigationItem.rightBarButtonItem = nextButton;
	
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
    UITextField *textField = (UITextField*)[groupNameCell viewWithTag:1];
    [textField becomeFirstResponder];
}

- (void)hideKeyboard
{
    UITextField *textField = (UITextField*)[groupNameCell viewWithTag:1];
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

- (void) viewGroup
{
    ViewDeleteGroupViewController* viewGroupController = [[ViewDeleteGroupViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ViewDeleteGroupViewController"]
                                                                                                         bundle:[DosecastUtil getResourceBundle]
                                                                                                      logoImage:thisLogo
                                                                                                          group:thisGroup
                                                                                                      viewTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsJoinGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Join Group", @"The Join Group label in the Settings view"])
                                                                                                     headerText:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsGroupInfo", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Info", @"The Group Info label in the Settings view"])
                                                                                                     footerText:NSLocalizedStringWithDefaultValue(@"ViewJoinGroupViewGroupFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"To join this group, tap the Next button.", @"The footer label in the ViewGroup view "])
                                                                                           showLeaveGroupButton:NO
                                                                                             leftNavButtonTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                                                                            rightNavButtonTitle:NSLocalizedStringWithDefaultValue(@"ToolbarButtonNext", @"Dosecast", [DosecastUtil getResourceBundle], @"Next", @"The text on the Next toolbar button"])
                                                                                                       delegate:self];
    [self.navigationController pushViewController:viewGroupController animated:YES];
}

// Callback for when user taps on the left nav button
- (void)handleViewGroupTapLeftNavButton
{
    [self.navigationController popViewControllerAnimated:YES];
}

// Callback for when user taps on the right nav button
- (void)handleViewGroupTapRightNavButton
{
    JoinGroupEnterPasswordViewController* enterPasswordController = [[JoinGroupEnterPasswordViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"JoinGroupEnterPasswordViewController"]
                                                                                                         bundle:[DosecastUtil getResourceBundle]
                                                                                                        group:thisGroup
                                                                                                       delegate:self];
    [self.navigationController pushViewController:enterPasswordController animated:YES];
}

// Callback for successful joining of a group
- (void)handleJoinGroupSuccess
{
    if (controllerDelegate && [controllerDelegate respondsToSelector:@selector(handleJoinGroupSuccess)])
    {
        [controllerDelegate handleJoinGroupSuccess];
    }
}

- (void)getBlobServerProxyResponse:(ServerProxyStatus)status data:(NSData*)data errorMessage:(NSString *)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

    if (status == ServerProxySuccess)
    {
        if (data)
            thisLogo = [UIImage imageWithData:data];
        else
            thisLogo = nil;
        
        [self viewGroup];
    }
    else
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
    }
}

- (void)groupInfoByNameServerProxyResponse:(ServerProxyStatus)status groupFound:(BOOL)groupFound group:(Group*)group errorMessage:(NSString*)errorMessage
{
    if (status == ServerProxySuccess)
	{
        if (!groupFound)
        {
            [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupGroupNotFoundTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Not Found", @"The title on the alert appearing when a general error occurs"])
                                                                                               message:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupGroupNotFoundMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The group name you entered could not be found. Please verify the group name and try again.", @"The title on the alert appearing when a general error occurs"])];
            [alert showInViewController:self];

        }
        else
        {
            thisGroup = group;

            if (thisGroup.logoGUID && [thisGroup.logoGUID length] > 0)
            {
                // Get the logo
                [[ServerProxy getInstance] getBlob:thisGroup.logoGUID respondTo:self];
            }
            else
            {
                thisLogo = nil;
                
                [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

                [self viewGroup];
            }
        }
	}
	else
	{
        [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];

        if (status != ServerProxyDeviceDetached)
        {
            DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                               message:errorMessage];
            [alert showInViewController:self];
        }
	}
}

- (void)handleNext:(id)sender
{
    if ([groupName length] == 0)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupEnterGroupNameEmptyNameTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Name Required", @"The error message when the group name is empty"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupEnterGroupNameEmptyNameMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a group name.", @"The error message when the group name is empty"])];
        [alert showInViewController:self];
    }
    else
    {
        [self hideKeyboard];

        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerSearchingForGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Searching for group", @"The message appearing in the spinner view when updating the server"])];
        thisGroup = nil;
        thisLogo = nil;
        [[ServerProxy getInstance] groupInfoByName:groupName respondTo:self];
    }
}

// Callback when user presses Return button on keyboard when editing a text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{	
	[self handleNext:textField];
	return YES;
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
    UITextField *textField = (UITextField*)[groupNameCell viewWithTag:1];
    
    // Initialize the properties of the cell
    textField.text = groupName;
    textField.placeholder = nil;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.keyboardType = UIKeyboardTypeDefault;
    textField.secureTextEntry = NO;        
    
    return groupNameCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterGroupNamePlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Name", @"The placeholder label in the JoinGroupEnterGroupName view"]);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterGroupNameFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter the name of the group and tap the Next button.", @"The footer text of the JoinGroupEnterGroupName view"]);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    
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
