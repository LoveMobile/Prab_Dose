//
//  JoinGroupEnterPasswordViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "JoinGroupEnterPasswordViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "ServerProxy.h"
#import "CustomNameIDList.h"
#import "Group.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

// The different UI sections & rows
typedef enum {
	JoinGroupEnterPasswordViewControllerSectionsTermsStatement = 0,
	JoinGroupEnterPasswordViewControllerSectionsTerms          = 1,
    JoinGroupEnterPasswordViewControllerSectionsPassword       = 2,
    JoinGroupEnterPasswordViewControllerSectionsSubmitButton   = 3
} JoinGroupEnterPasswordViewControllerSections;

@implementation JoinGroupEnterPasswordViewController

@synthesize tableView;
@synthesize passwordCell;
@synthesize termsCell;
@synthesize submitButtonCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
						  bundle:nibBundleOrNil
                         group:nil
						delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
                group:(Group*)g
			 delegate:(NSObject<JoinGroupEnterPasswordViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

		self.title = NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsJoinGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Join Group", @"The Join Group label in the Settings view"]);
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        password = [[NSMutableString alloc] initWithString:@""];
        group = g;
		controllerDelegate = delegate;
        tableViewSections = [[NSMutableArray alloc] init];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString* newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [password setString:newValue];
    return YES;
}

- (BOOL)displayModifiedTerms
{
    NSString* groupTOS = [[DataModel getInstance] getGroupTermsOfService];
    
    return (group.tosAddendum != nil && [group.tosAddendum length] > 0 &&
            groupTOS != nil && [groupTOS length] > 0);
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    [password setString:@""];
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
    UITextField *textField = (UITextField*)[passwordCell viewWithTag:1];
    [textField becomeFirstResponder];
}

- (void)hideKeyboard
{
    UITextField *textField = (UITextField*)[passwordCell viewWithTag:1];
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

    // Scroll the text view to the top
    UITextView* textView = (UITextView*)[termsCell viewWithTag:1];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
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

// Callback when user presses Return button on keyboard when editing a text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self hideKeyboard];
	return YES;
}

- (void)keyboardWillShow:(NSNotification *)sender
{
    CGSize kbSize = [[[sender userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [[[sender userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, kbSize.height, 0);
        [tableView setContentInset:edgeInsets];
        [tableView setScrollIndicatorInsets:edgeInsets];
    }];
}

- (void)keyboardWillHide:(NSNotification *)sender
{
    NSTimeInterval duration = [[[sender userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        UIEdgeInsets edgeInsets = UIEdgeInsetsZero;
        [tableView setContentInset:edgeInsets];
        [tableView setScrollIndicatorInsets:edgeInsets];
    }];
}

- (void)groupJoinServerProxyResponse:(ServerProxyStatus)status groupJoinResult:(NSString*)groupJoinResult gaveSubscription:(BOOL)gaveSubscription gavePremium:(BOOL)gavePremium errorMessage:(NSString*)errorMessage
{
    [[DataModel getInstance] allowDosecastUserInteractionsWithMessage:YES];
    __block BOOL joinGroupSuccess = NO;
    
    if (status == ServerProxySuccess)
	{
        NSString* alertMessage = nil;

        if ([groupJoinResult compare:@"success"] == NSOrderedSame)
        {
            joinGroupSuccess = YES;

            if (gaveSubscription)
                alertMessage = NSLocalizedStringWithDefaultValue(@"AlertJoinGroupResultSubscriptionSuccessUpgrade", @"Dosecast", [DosecastUtil getResourceBundle], @"You have successfully joined the group, and you have been upgraded to the Pro edition with CloudSync at no charge.", @"The message of the alert appearing when a join group is successful"]);
            else if (gavePremium)
                alertMessage = NSLocalizedStringWithDefaultValue(@"AlertJoinGroupResultPremiumSuccessUpgrade", @"Dosecast", [DosecastUtil getResourceBundle], @"You have successfully joined the group, and you have been upgraded to the Premium edition at no charge.", @"The message of the alert appearing when a join group is successful"]);
            else
                alertMessage = NSLocalizedStringWithDefaultValue(@"AlertJoinGroupResultSuccess", @"Dosecast", [DosecastUtil getResourceBundle], @"You have successfully joined the group.", @"The message of the alert appearing when a join group is successful"]);
        }
        else if ([groupJoinResult compare:@"noSuchGroup"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupNoSuchGroupMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"You could not join the group, as the group could not be found. Please try again, and if the error persists, contact us.", @"The message of the alert appearing when a join group is unsuccessful"]);
        }
        else if ([groupJoinResult compare:@"incorrectPassword"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupIncorrectPasswordMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The password you entered is incorrect. Please verify that you have the correct password and try again.", @"The message of the alert appearing when a join group is unsuccessful"]);
        }
        else if ([groupJoinResult compare:@"passwordUsed"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupPasswordUsedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"The password you entered has already been used by someone else and may not be used again. Please obtain a new password from the sponsoring organization.", @"The message of the alert appearing when a join group is unsuccessful"]);
        }
        else // if ([groupJoinResult compare:@"alreadyMember"] == NSOrderedSame)
        {
            alertMessage = NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupAlreadyMemberMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"You are already a member of this group and cannot join it again.", @"The message of the alert appearing when a join group is unsuccessful"]);
        }
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil message:alertMessage style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction *action){
                                          if (joinGroupSuccess)
                                          {
                                              if (controllerDelegate && [controllerDelegate respondsToSelector:@selector(handleJoinGroupSuccess)])
                                              {
                                                  [controllerDelegate handleJoinGroupSuccess];
                                              }
                                          }
                                      }]];
        
        [alert showInViewController:self];
	}
	else if (status != ServerProxyDeviceDetached)
	{
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:errorMessage];
        [alert showInViewController:self];
	}
}

- (IBAction)handleSubmit:(id)sender
{
    if ([password length] == 0)
    {
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupEnterGroupPasswordEmptyNameTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Password Required", @"The error message when the group name is empty"])
                                                                                           message:NSLocalizedStringWithDefaultValue(@"ErrorJoinGroupEnterGroupPasswordEmptyNameMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Please enter a group password.", @"The error message when the group name is empty"])];
        [alert showInViewController:self];
    }
    else
    {
        [self hideKeyboard];
        
        [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingServer", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating server", @"The message appearing in the spinner view when updating the server"])];

        [[ServerProxy getInstance] groupJoin:group.groupID password:password respondTo:self];
    }
}

#pragma mark Table view methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    [tableViewSections removeAllObjects];
    if ([self displayModifiedTerms])
    {
        [tableViewSections addObject:[NSNumber numberWithInt:JoinGroupEnterPasswordViewControllerSectionsTermsStatement]];
        [tableViewSections addObject:[NSNumber numberWithInt:JoinGroupEnterPasswordViewControllerSectionsTerms]];
    }
    
    [tableViewSections addObject:[NSNumber numberWithInt:JoinGroupEnterPasswordViewControllerSectionsPassword]];
    [tableViewSections addObject:[NSNumber numberWithInt:JoinGroupEnterPasswordViewControllerSectionsSubmitButton]];

    return [tableViewSections count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    JoinGroupEnterPasswordViewControllerSections controllerSection = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == JoinGroupEnterPasswordViewControllerSectionsTermsStatement)
        return 0;
    else
        return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    JoinGroupEnterPasswordViewControllerSections section = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (section == JoinGroupEnterPasswordViewControllerSectionsTerms)
    {
        UITextView* textView = (UITextView*)[termsCell viewWithTag:1];
        
        NSMutableString* terms = [NSMutableString stringWithString:[[DataModel getInstance] getGroupTermsOfService]];
        [terms appendString:group.tosAddendum];
        
        textView.text = terms;
        
		return termsCell;
    }
    else if (section == JoinGroupEnterPasswordViewControllerSectionsPassword)
    {
        UITextField *textField = (UITextField*)[passwordCell viewWithTag:1];
        
        // Initialize the properties of the cell
        textField.text = password;
        textField.placeholder = nil;
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.secureTextEntry = NO;        
        
        return passwordCell;
    }
    else if (section == JoinGroupEnterPasswordViewControllerSectionsSubmitButton)
    {
        UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		submitButtonCell.backgroundView = backView;
        submitButtonCell.backgroundColor = [UIColor clearColor];
		
		// Dynamically set the color of the submit button if an image isn't already set.
		UIButton* submitButton = (UIButton *)[submitButtonCell viewWithTag:1];
        UIImage* submitButtonImage = submitButton.currentImage;
        if (!submitButtonImage)
        {
            if ([self displayModifiedTerms])
                [submitButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordSubmitButtonTerms", @"Dosecast", [DosecastUtil getResourceBundle], @"I accept. Join the group.", @"The submit button label in the JoinGroupEnterPassword view"]) forState:UIControlStateNormal];
            else
                [submitButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordSubmitButtonNoTerms", @"Dosecast", [DosecastUtil getResourceBundle], @"Join the group.", @"The submit button label in the JoinGroupEnterPassword view"]) forState:UIControlStateNormal];

            [DosecastUtil setBackgroundColorForButton:submitButton color:[DosecastUtil getJoinGroupButtonColor]];
        }

        return submitButtonCell;
    }
    else
        return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    JoinGroupEnterPasswordViewControllerSections section = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (section == JoinGroupEnterPasswordViewControllerSectionsTerms)
    {
		if ([DosecastUtil isIPad])
			return 450;
		else
			return 200;
    }
    else
        return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    JoinGroupEnterPasswordViewControllerSections controllerSection = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == JoinGroupEnterPasswordViewControllerSectionsPassword)
        return NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordPlaceholder", @"Dosecast", [DosecastUtil getResourceBundle], @"Group Password", @"The placeholder label in the JoinGroupEnterPassword view"]);
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    JoinGroupEnterPasswordViewControllerSections controllerSection = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:section] intValue];

    if (controllerSection == JoinGroupEnterPasswordViewControllerSectionsTermsStatement)
    {
        return NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordTermsStatement", @"Dosecast", [DosecastUtil getResourceBundle], @"Joining this group requires a change to the terms of service that apply to you. Please review these terms below and, if you accept them, enter the group password and tap the button to join the group.", @"The terms statement label in the JoinGroupEnterPassword view"]);
    }
    else if (controllerSection == JoinGroupEnterPasswordViewControllerSectionsPassword)
    {
        NSMutableString* footer = [NSMutableString stringWithString:NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordFooter", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter the password for the group.", @"The footer text of the JoinGroupEnterPassword view"])];
        
        if ([self displayModifiedTerms])
        {
            [footer appendFormat:@"\n\n%@",
             NSLocalizedStringWithDefaultValue(@"ViewJoinGroupEnterPasswordFooterTerms", @"Dosecast", [DosecastUtil getResourceBundle], @"By tapping on 'I accept' below you are agreeing to the changed Terms of Service.", @"The terms footer label in the JoinGroupEnterPassword view"])];
        }
        
        return footer;
    }
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    JoinGroupEnterPasswordViewControllerSections section = (JoinGroupEnterPasswordViewControllerSections)[[tableViewSections objectAtIndex:indexPath.section] intValue];

    if (section == JoinGroupEnterPasswordViewControllerSectionsPassword)
    {
        [self showKeyboard];
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
