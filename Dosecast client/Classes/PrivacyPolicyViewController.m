//
//  PrivacyPolicyViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/10/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "PrivacyPolicyViewController.h"
#import "DosecastUtil.h"
#import "DosecastAPI.h"

@implementation PrivacyPolicyViewController


 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil dosecastAPI:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dosecastAPI:(DosecastAPI*)a
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		// Custom initialization
        api = a;
	}
	return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedStringWithDefaultValue(@"ViewPrivacyPolicyTitle", @"Dosecast-client", [NSBundle mainBundle], @"Privacy Policy", @"The title of the Privacy Policy view"]);	
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    NSString* regularTerms = NSLocalizedStringWithDefaultValue(@"ViewPrivacyPolicyTerms", @"Dosecast-client", [NSBundle mainBundle], @"", @"The privacy policy");
    NSString* groupTerms = NSLocalizedStringWithDefaultValue(@"ViewPrivacyPolicyTermsGroup", @"Dosecast-client", [NSBundle mainBundle], @"", @"The privacy policy");
    NSMutableString* termsToDisplay = [NSMutableString stringWithString:@""];
    NSString* tosAddenda = [api getGroupTermsOfServiceAddenda];
    
    if (groupTerms && [groupTerms length] > 0 &&
        tosAddenda && [tosAddenda length] > 0)
    {
        [termsToDisplay appendString:groupTerms];
        [termsToDisplay appendString:tosAddenda];
    }
    else
        [termsToDisplay appendString:regularTerms];
    
    UITextView* textView = (UITextView*)[[self view] viewWithTag:1];
    textView.text = termsToDisplay;

    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    
    // Scroll the text view to the top
    UITextView* textView = (UITextView*)[[self view] viewWithTag:1];
    [textView setContentOffset:
     CGPointMake(textView.contentOffset.x, 0) animated:YES];
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

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}




@end
