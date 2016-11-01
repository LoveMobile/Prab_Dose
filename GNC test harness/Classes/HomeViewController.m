//
//  HomeViewController.m
//  Sephora
//
//  Created by Dan Gilliam on 7/1/10.
//  Copyright Branding Brand, LLC 2010. All rights reserved.
//

#import "HomeViewController.h"
#import "WebAppViewController.h"
#import "GNCDosecastAPI.h"
#import "SpinnerViewController.h"
#import "ProgressViewController.h"

@implementation HomeViewController

- (void) awakeFromNib
{
    _dosecastUIInitialized = NO;
    _isRegisteringDosecastUser = NO;
    _isDisplayingSpinner = NO;
    _isDisplayingProgress = NO;
    _spinnerViewController = nil;
    _progressViewController = nil;
    
    _dosecastAPI = nil;
    _delegate = nil;
}

/*
 // Implement loadView to create a view hierarchy programmatically, without using a nib.
 - (void)loadView {
 }
 */

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [_scrollView setContentSize:CGSizeMake(320.0, 412.0)];

    if (!_spinnerViewController)
        _spinnerViewController = [[SpinnerViewController alloc] init];
    if (!_progressViewController)
        _progressViewController = [[ProgressViewController alloc] init];
    
    [super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [_searchBar setText:@""];
    [_searchBar resignFirstResponder];
}

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (BOOL) isDosecastVisible
{
    NSArray* controllers = self.navigationController.viewControllers;
    int numControllers = (int)[controllers count];
    for (int i = 0; i < numControllers; i++)
    {
        UIViewController* controller = [controllers objectAtIndex:i];
        if (controller == _dosecastAPI.mainViewController)
            return YES;
    }
    return NO;
}

- (void) registerDosecastUser
{
    if (!_dosecastAPI.userRegistered)
    {
        _isRegisteringDosecastUser = YES;
        [_dosecastAPI registerUser];
    }
}

- (IBAction)openDosecast:(id)sender
{
    if (!_dosecastAPI.userRegistered && !_isRegisteringDosecastUser)
    {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                         message:@"Could not register user."
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        [alert show];
    }
    else
    {
        [self.navigationController pushViewController:_dosecastAPI.mainViewController animated:YES];
        
        if (!_dosecastUIInitialized)
        {
            _spinnerViewController.message = @"Initializing...";
            [_spinnerViewController showInView:[self.navigationController view]];
        }
        else if (_isRegisteringDosecastUser)
        {
            _spinnerViewController.message = @"Registering...";
            [_spinnerViewController showInView:[self.navigationController view]];
        }
        else if (_isDisplayingSpinner)
        {
            [_spinnerViewController showInView:[self.navigationController view]];
        }
        else if (_isDisplayingProgress)
        {
            [_progressViewController showInView:[self.navigationController view]];
        }
    }
}

// Callback for when UI initialization is complete. The DosecastAPI view controllers must not be made visible until
// after this call is made
- (void)handleDosecastUIInitializationComplete
{
    _dosecastUIInitialized = YES;
    if (!_isRegisteringDosecastUser && _spinnerViewController.visible)
    {
        [_spinnerViewController hide:YES];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(doneInitializingDosecast)])
    {
        [_delegate doneInitializingDosecast];
    }
}

// Button-click callback when UIAlertView appears and "Try Again" button is pressed
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{	
    if (_dosecastUIInitialized && [self isDosecastComponentVisible])
    {
        _spinnerViewController.message = @"Registering...";
        [_spinnerViewController showInView:[self.navigationController view]];
    }
    [_dosecastAPI registerUser];
}

// Callback for when Dosecast registration completes. If an error occurred, errorMessage will be non-nil.
- (void)handleDosecastRegistrationComplete:(NSString*)errorMessage
{
    if (_dosecastUIInitialized && _spinnerViewController.visible)
    {
        [_spinnerViewController hide:YES];
    }

    if (errorMessage)
    {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                         message:errorMessage
                                                        delegate:self
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        [alert show];        
    }
    else
    {        
        _isRegisteringDosecastUser = NO;
    }
}

// Callback for when the Dosecast component must be made visible. If Dosecast is embedded in a UITabBarController
// or other UI component, this component must be made visible at the time of this call if it is not already.
- (void)displayDosecastComponent
{
    if (_delegate && [_delegate respondsToSelector:@selector(displayHomeTab)])
        [_delegate displayHomeTab];
    
    if (![self isDosecastComponentVisible])
        [self.navigationController pushViewController:_dosecastAPI.mainViewController animated:YES];
}

// Callback to find out if the Dosecast component is visible. If Dosecast is embedded in a UITabBarController
// or other UI component, return whether the component is active/selected.
- (BOOL)isDosecastComponentVisible
{
    if (_delegate && [_delegate respondsToSelector:@selector(isHomeTabVisible)])
    {
        return [_delegate isHomeTabVisible] && [self isDosecastVisible];
    }
    else
        return NO;
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessage will be called.
- (void)disallowDosecastUserInteractionsWithMessage:(NSString*)message
{
    _spinnerViewController.message = message;
    
    if ([self isDosecastComponentVisible])
    {
        [_spinnerViewController showInView:[self.navigationController view]];
    }
    
    _isDisplayingSpinner = YES;
}

// Callback for when a message changes while user interactions are disallowed.
- (void)updateDosecastMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    _spinnerViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessage:(BOOL)allowAnimation
{
    if (_spinnerViewController.visible)
    {
        [_spinnerViewController hide:allowAnimation];
    }
    
    _isDisplayingSpinner = NO;
}

// Callback for when Dosecast user interactions should be disallowed and a message displayed to the user with intermediate progress.
// updateDosecastProgress will be called to deliver intermediate progress updates.
// When user interactions should be allowed again, allowDosecastUserInteractionsWithMessageAndProgress will be called.
- (void)disallowDosecastUserInteractionsWithMessageAndProgress:(NSString*)message
                                                      progress:(float)progress // A number between 0 and 1
{
    _progressViewController.message = message;
    _progressViewController.progress = progress;
    
    if ([self isDosecastComponentVisible])
    {        
        [_progressViewController showInView:[self.navigationController view]];
    }
    
    _isDisplayingProgress = YES;
}

// Callback for when an intermediate progress update occurs.
- (void)updateDosecastProgressWhileUserInteractionsDisallowed:(float)progress // A number between 0 and 1
{
    _progressViewController.progress = progress;
}

// Callback for when a message changes while progressing and user interactions are disallowed.
- (void)updateDosecastProgressMessageWhileUserInteractionsDisallowed:(NSString*)message
{
    _progressViewController.message = message;
}

// Callback for when Dosecast user interactions should be allowed again
// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
- (void)allowDosecastUserInteractionsWithMessageAndProgress:(BOOL)allowAnimation
{
    if (_progressViewController.visible)
    {
        [_progressViewController hide:allowAnimation];
    }
    
    _isDisplayingProgress = NO;
}

- (UINavigationController*) getUINavigationController
{
    return self.navigationController;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc
{
    _searchBar = nil;
    _scrollView = nil;
}


#pragma mark -


@end
