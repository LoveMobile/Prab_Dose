//
//  RegistrationViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "RegistrationViewController.h"
#import "DosecastUtil.h"

@implementation RegistrationViewController

@synthesize termsCell;
@synthesize submitButtonCell;
@synthesize tableView;
@synthesize registrationDelegate;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
		NSString* registrationTitle = NSLocalizedStringWithDefaultValue(@"ViewRegistrationTitle", @"Dosecast-client", [NSBundle mainBundle], @"%@ Registration", @"The title of the Registration view"]);
		self.title = [NSString stringWithFormat:registrationTitle, [DosecastUtil getProductComponentName]];
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        registrationDelegate = nil;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
    
    self.view.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}



- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

    // Scroll the text view to the top
    UITextView* textView = (UITextView*)[termsCell viewWithTag:1];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];

}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	tableView.backgroundColor = [UIColor clearColor];
	
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


- (IBAction)handleSubmit:(id)sender
{
    // This is called to initiate the registration 
    if ([registrationDelegate respondsToSelector:@selector(registerUser)])
    {
        [registrationDelegate registerUser];
    }	
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 0;
	else
		return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
	{
        UITextView* textView = (UITextView*)[termsCell viewWithTag:1];
        textView.text = NSLocalizedStringWithDefaultValue(@"ViewTermsOfServiceTerms", @"Dosecast-client", [NSBundle mainBundle], @"", @"The terms of service");
        
		return termsCell;
	}
	else if (indexPath.section == 2)
	{
		UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		submitButtonCell.backgroundView = backView;
        submitButtonCell.backgroundColor = [UIColor clearColor];

		// Dynamically set the color of the submit button
		UIButton* submitButton = (UIButton *)[submitButtonCell viewWithTag:1];
		[submitButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewRegistrationButtonAccept", @"Dosecast-client", [NSBundle mainBundle], @"I accept. Create my account.", @"The text on the Accept button in the registration page"]) forState:UIControlStateNormal];

        NSString* colorStr = NSLocalizedStringWithDefaultValue(@"ColorRegistrationSubmitButton", @"Dosecast-client", [NSBundle mainBundle], @"0 0.27 0.45 1", @"Color of the registration submit button"]);
        [DosecastUtil setBackgroundColorForButton:submitButton color:[DosecastUtil getColorFromString:colorStr]];

		return submitButtonCell;
	}
	else
		return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1)
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
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == 0)
		return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ViewRegistrationWelcomeText", @"Dosecast-client", [NSBundle mainBundle], @"Welcome to %@! Please review the terms of service and, if you accept them, click the button below to create your account.", @"The text on the top of the registration page"]), [DosecastUtil getProductAppName]];
	else if (section == 1)
		return NSLocalizedStringWithDefaultValue(@"ViewRegistrationAgreeTermsText", @"Dosecast-client", [NSBundle mainBundle], @"By clicking on 'I accept' below you are agreeing to the Terms of Service.", @"The text on the bottom of the registration page"]);
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
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
