//
//  ProgressViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ProgressViewController.h"
#import "DosecastUtil.h"
#import "BarButtonDisabler.h"

static const CGFloat SPINNER_ALPHA = 0.8;

@implementation ProgressViewController

@synthesize visible;

- (id)init
{
    return [self initWithNibName:nil bundle:nil];
}

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"ProgressViewController"] bundle:[DosecastUtil getResourceBundle]])) {
        // Custom initialization
        topController = nil;
        message = [[NSMutableString alloc] initWithString:@""];
        progress = 0.0f;
        barButtonDisabler = [[BarButtonDisabler alloc] init];
    }
    return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Initialize variables
    UILabel* label = (UILabel *)[self.view viewWithTag:2];
    label.text = message;
    label.textColor = [DosecastUtil getSpinnerLabelColor];
    UIProgressView* progressView = (UIProgressView *)[self.view viewWithTag:3];
    progressView.progress = progress;
}

// Callback for device rotation
- (void) willChangeStatusBarOrientation:(NSNotification *)notification
{
    [self handleHide:NO];
}

- (void) handleShowDelayed:(NSTimer*)theTimer
{
    [self handleShow:NO];
}

// Callback for post-device rotation
- (void) didChangeStatusBarOrientation:(NSNotification *)notification
{
    // Schedule the handling for this orientation for a little later to allow the topController to update its bounds first
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleShowDelayed:) userInfo:nil repeats:NO];
}

- (void) handleShow:(BOOL)animated
{
    // Resize our bounds using the current status bar orientation
    CGSize topViewBounds = topController.view.bounds.size;
    [self view].frame = CGRectMake(0, 0, topViewBounds.width, topViewBounds.height);
    
    [barButtonDisabler setToolbarStateForViewController:topController enabled:NO];

    if (animated)
    {
        self.view.alpha = 0;
        
        [topController.view addSubview:self.view];
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
        self.view.alpha = SPINNER_ALPHA;
        [UIView commitAnimations];
    }
    else
    {
        self.view.alpha = SPINNER_ALPHA;
        [topController.view addSubview:self.view];
    }
}

- (void)handleHide:(BOOL)animated
{
    [barButtonDisabler setToolbarStateForViewController:topController enabled:YES];

    if (animated)
    {
        self.view.alpha = SPINNER_ALPHA;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
        
        self.view.alpha = 0;
        
        // Set callback for when animation stops
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        
        [UIView commitAnimations];
    }
    else
    {
        self.view.alpha = 0;
        [self.view removeFromSuperview];
    }
}



-(void)showOnViewController:(UIViewController*)controller animated:(BOOL)animated
{
    if (topController)
        [self hide:NO];
    
    if (!controller)
        return;
    
    topController = controller;
    
    // Setup device orientation callbacks
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willChangeStatusBarOrientation:)
                                                 name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeStatusBarOrientation:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    
    [self handleShow:animated];
}

-(void)hide:(BOOL)animated
{
    if (!topController)
        return;
    
    [self handleHide:animated];
    
    // stop device orientation event callbacks
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    
    topController = nil;
}

// Callback for when animation stops
- (void)animationDidStop:(NSString*)animationID finished:(BOOL)finished context:(void *)context
{
    [self.view removeFromSuperview];
    [UIView setAnimationDelegate:nil];
    [UIView setAnimationDidStopSelector:nil];
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


// Returns current message
- (NSString*)message
{
    return message;
}

// Sets current message
- (void)setMessage:(NSString*)m
{
    [message setString:m];
    
    if ([self isViewLoaded])
    {
        // Pass through to the labels in our view
        UILabel* label = (UILabel *)[self.view viewWithTag:2];
        label.text = m;
    }
}

// Returns current progress
- (float)progress
{
    return progress;
}

// Sets current progress
- (void)setProgress:(float)p
{
    progress = p;
    
    if ([self isViewLoaded])
    {
        UIProgressView* progressView = (UIProgressView *)[self.view viewWithTag:3];
        progressView.progress = p;
    }
}

@end
