//
//  MessagePanelViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "MessagePanelViewController.h"
#import "DosecastUtil.h"

@implementation MessagePanelViewController

-(id) init
{
    return [self initWithNibName:nil bundle:nil];
}

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"MessagePanelViewController"] bundle:[DosecastUtil getResourceBundle]])) {
        // Custom initialization
		topController = nil;
		
		// Initialize variables
		UITextField* label = (UITextField *)[self.view viewWithTag:1];
		label.text = nil;
		label.textColor = [DosecastUtil getMessagePanelTextColor];
		label.backgroundColor = [DosecastUtil getMessagePanelBackgroundColor];
    }
    return self;
}


- (void)handleHide:(BOOL)animated
{
	if (animated)
	{
		UITextField* label = (UITextField *)[self.view viewWithTag:1];
		int selfWidth = self.view.bounds.size.width;
		int selfHeight = self.view.bounds.size.height;
		int controllerHeight = topController.view.bounds.size.height;
		int labelHeight = label.bounds.size.height;
		
		self.view.alpha = 1;
		self.view.frame = CGRectMake(0, controllerHeight-labelHeight, selfWidth, selfHeight);
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.5];
		
		self.view.alpha = 0;
		self.view.frame = CGRectMake(0, controllerHeight+labelHeight, selfWidth, selfHeight);

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

// Callback for pre-device rotation
- (void) willChangeStatusBarOrientation:(NSNotification *)notification
{
	[self handleHide:NO];
}

- (void) handleShowDelayed:(NSTimer*)theTimer
{
	// Resize our bounds using the current status bar orientation
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	CGSize screenBounds = ([[UIScreen mainScreen] bounds]).size;
	if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
	{
		[self view].bounds = CGRectMake(0, 0, screenBounds.height, screenBounds.width);
	}
	else
	{
		[self view].bounds = CGRectMake(0, 0, screenBounds.width, screenBounds.height);
	}		
	
	UITextField* label = (UITextField *)[self.view viewWithTag:1];
	int selfWidth = self.view.bounds.size.width;
	int selfHeight = self.view.bounds.size.height;
	int controllerHeight = topController.view.bounds.size.height;
	int labelHeight = label.bounds.size.height;
	self.view.alpha = 0;
	
	[topController.view addSubview:self.view];
	self.view.frame = CGRectMake(0, controllerHeight+labelHeight, selfWidth, selfHeight);
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5];
	self.view.alpha = 1;
	self.view.frame = CGRectMake(0, controllerHeight-labelHeight, selfWidth, selfHeight);
	[UIView commitAnimations];	
}

// Callback for post-device rotation
- (void) didChangeStatusBarOrientation:(NSNotification *)notification
{	
	// Schedule the handling for this orientation for a little later to allow the topController to update its bounds first
	[NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleShowDelayed:) userInfo:nil repeats:NO];
}

-(void)showOnViewController:(UIViewController*)controller
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
	
	// Schedule the handling for the show for a little later to allow the topController to update its bounds first
	// (the toolbar may be appearing/disappearing)
	[NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(handleShowDelayed:) userInfo:nil repeats:NO];
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

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}



// Returns current message
- (NSString*)message {
	// Pass through to the labels in our view
	UITextField* label = (UITextField *)[self.view viewWithTag:1];
	return label.text;
}

// Sets current message
- (void)setMessage:(NSString*)m {
	// Pass through to the labels in our view
	UITextField* label = (UITextField *)[self.view viewWithTag:1];
	label.text = m;
}

- (BOOL) visible
{
	return topController != nil;
}

@end
