//
//  ContactViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ContactViewController.h"
#import "DosecastUtil.h"

@implementation ContactViewController

@synthesize tableView;
@synthesize appointmentsAndAdviceCell;
@synthesize appointmentsAndAdviceHeader;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

        phoneConfirmationAlert = [[UIAlertView alloc] initWithTitle:@"Call KP"
                                                                  message:nil
                                                                 delegate:self
                                                        cancelButtonTitle:@"Cancel"
                                                        otherButtonTitles:@"Call", nil];

    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = @"Contact";
	
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }

    // Set background image in table
    NSString *backgroundFilePath = [NSString stringWithFormat:@"%@%@", [[DosecastUtil getResourceBundle] resourcePath], [DosecastUtil getDeviceSpecificFilename:@"/Background.png"]];
    UIImage* image = [[UIImage alloc] initWithContentsOfFile:backgroundFilePath];
    UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeTopLeft;
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    tableView.backgroundView = imageView;
    
	tableView.sectionHeaderHeight = 8;
	tableView.sectionFooterHeight = 0;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
    if ([DosecastUtil getOSVersionFloat] >= 7.0f)
    {
        self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
        self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
        self.navigationController.toolbar.tintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.toolbar.translucent = NO;
    }
    else
    {
        self.navigationController.navigationBar.tintColor = [DosecastUtil getNavigationBarColor];
        self.navigationController.toolbar.tintColor = [DosecastUtil getToolbarColor];
    }
    
    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}

- (NSUInteger)supportedInterfaceOrientations
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

// Return a stripped phone number from a formatted one
- (NSString*) getStrippedPhoneNumber:(NSString*)formattedPhoneNumber
{
    NSMutableString* strippedPhoneNumber = [NSMutableString stringWithString:@"tel:+1"];
    NSCharacterSet* numericCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
    for (int i = 0; i < [formattedPhoneNumber length]; i++)
    {
        unichar c = [formattedPhoneNumber characterAtIndex:i];
        if ([numericCharacterSet characterIsMember:c])
        {
            [strippedPhoneNumber appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    
    return strippedPhoneNumber;
}

// Button-click callback when UIAlertView appears and "Try Again" button is pressed
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView == phoneConfirmationAlert)
	{
		if (buttonIndex != 0) // user didn't click cancel
		{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:
                                                        [self getStrippedPhoneNumber:phoneConfirmationAlert.message]]];
		}
	}
}

- (IBAction)handleCall:(id)sender
{
    UIButton* button = (UIButton*)sender;
    NSString* phoneNumber = [button titleForState:UIControlStateNormal];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:
                                                       [self getStrippedPhoneNumber:phoneNumber]]])
    {
        phoneConfirmationAlert.message = phoneNumber;
        [phoneConfirmationAlert show];
    }
    else
    {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil
                                                            message:@"Your device does not support calls."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		appointmentsAndAdviceHeader.backgroundView = backView;
        appointmentsAndAdviceHeader.backgroundColor = [UIColor clearColor];

        UILabel* label = (UILabel*) [appointmentsAndAdviceHeader viewWithTag:1];
        label.text = @"For symptoms-related questions, medical advice, or to leave a message for your doctor:";
        return appointmentsAndAdviceHeader;
    }
    else if (indexPath.section == 1)
    {
        UILabel* label = (UILabel*) [appointmentsAndAdviceCell viewWithTag:1];
        label.text = @"Appointments and advice";
        UIButton* phone = (UIButton*) [appointmentsAndAdviceCell viewWithTag:2];
        [phone setTitle:@"(866) 454-8855" forState:UIControlStateNormal];

        return appointmentsAndAdviceCell;
    }
    else
        return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
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
