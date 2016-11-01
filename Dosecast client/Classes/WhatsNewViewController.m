//
//  WhatsNewViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 5/21/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "WhatsNewViewController.h"
#import "DosecastUtil.h"

@implementation WhatsNewViewController

@synthesize textView;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedStringWithDefaultValue(@"ViewWhatsNewTitle", @"Dosecast-client", [NSBundle mainBundle], @"What's New", @"Title of About => What's New view"]);
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
	textView.text = NSLocalizedStringWithDefaultValue(@"ReleaseNotes", @"Dosecast-client", [NSBundle mainBundle], @"", @"Release notes");

    if (self.navigationController.toolbarHidden != YES)
        [self.navigationController setToolbarHidden:YES animated:YES];   
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
