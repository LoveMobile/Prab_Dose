//
//  WebAppViewController.m
//  GNC
//
//  Created by Dan Gilliam on 9/27/10.
//  Copyright 2010 Branding Brand, LLC. All rights reserved.
//

#import "WebAppViewController.h"
#import <QuartzCore/CALayer.h>
#import "GNCAppDelegate.h"

@implementation WebAppViewController



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
  self.webView.delegate = self;
  _loadedFromData = NO;

  if (self.initialURL)
  {
    if (!_deferInitialLoad)
      [self.webView loadRequest:[NSURLRequest requestWithURL:self.initialURL]];
  }
  else if (self.initialData)
  {
    [self.webView loadData:self.initialData
                  MIMEType:@"text/html"
                  textEncodingName:@"utf-8"
                  baseURL:self.initialDataBaseURL];
                  
    _loadedFromData = YES;
  }

  [self.placeholderView setHidden:YES];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.navbarButtonView];
  //self.navigationItem.leftBarButtonItem = nil;

  [super viewDidLoad];
}


- (void)clearContent
{
  [self.webView loadHTMLString:@"" baseURL:nil];  // clear out any existing content immediately
}

- (void)viewWillAppear:(BOOL)animated
{ 
  if (_contentFlushed)
  {
    _contentFlushed = NO;
    [self.webView reload];
  }
  
  NSString *searchBarKey = [self.navigationController gncSearchBarVisibilityKey];
  NSNumber *searchBarPrefValue = [[NSUserDefaults standardUserDefaults] objectForKey:searchBarKey];
  if (!searchBarPrefValue)
  {
    BOOL searchBarDefault = [self.navigationController gncSearchBarVisibilityDefault];
    [[NSUserDefaults standardUserDefaults] setBool:searchBarDefault forKey:searchBarKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }

  [self setSearchBarVisible:[[NSUserDefaults standardUserDefaults] boolForKey:searchBarKey] animated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
  [self.searchBar setText:@""];
  [self.searchBar resignFirstResponder];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)reloadInitialURL
{
  [self.webView loadRequest:[NSURLRequest requestWithURL:self.initialURL]];
}

- (void)dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [self.webView setDelegate:nil];   // webview may have pending operations -- make sure it won't call our delegate methods after we've been dealloc'd
}



/*
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
*/


- (void)webViewDidStartLoad:(UIWebView *)inWebView
{
  // NSLog(@"webViewDidStartLoad: %@", inWebView);

  [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
  [self.activityIndicator setHidden:NO];
  [self.activityIndicator startAnimating];  
}


- (void)webView:(UIWebView *)inWebView didFailLoadWithError:(NSError *)error
{
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  [self.activityIndicator stopAnimating];

  if ([error code] != NSURLErrorCancelled && 
      [error code] != 102 /* WebKitErrorFrameLoadInterruptedByPolicyChange */ )
  {
    NSLog(@"webView: %@ didFailLoadWithError: %@", inWebView, error);

    NSString *titleString = @"Error Loading Page";
    NSString *messageString = [error localizedDescription];
    messageString = [NSString stringWithFormat:@"%@", messageString];

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:titleString
        message:messageString delegate:nil
        cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
    [alertView show];
  }
  
}


- (void)webViewDidFinishLoad:(UIWebView *)inWebView
{
  // NSLog(@"webViewDidFinishLoad: %@", inWebView);

  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  [self.activityIndicator stopAnimating];

  [self.navigationItem setTitle:[inWebView stringByEvaluatingJavaScriptFromString:@"document.title"]];

  if (!self.navigationItem.title || [self.navigationItem.title length] == 0)
  {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                            style:UIBarButtonItemStyleBordered target:nil action:nil];

    [self.navigationItem setTitle:@"GNC"];
  }

}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
  if ([[[request URL] scheme] isEqualToString:@"mailto"] || [[[request URL] scheme] isEqualToString:@"sms"] || [[[request URL] scheme] isEqualToString:@"tel"])
  {
    [[UIApplication sharedApplication] openURL:[request URL]];
    return NO;
  }
  
  return YES;
}


+ (void)pushWebAppURLRequest:(NSURLRequest*)inRequest sender:(id)sender
{
  [WebAppViewController pushWebAppURLRequest:inRequest sender:sender delegate:nil];
}

+ (void)pushWebAppURLRequest:(NSURLRequest*)inRequest sender:(id)sender delegate:(id)inDelegate
{
  WebAppViewController *webAppViewController = [[WebAppViewController alloc] initWithNibName:@"WebAppView" bundle:nil];

  [[sender navigationController] pushViewController:webAppViewController animated:YES];
  [[webAppViewController webView] loadRequest:inRequest];
  [webAppViewController setWebAppViewDelegate:inDelegate];
  [[[sender navigationController] navigationBar] setHidden:NO];
}


+ (void)loadWebAppURLInBackground:(NSURL*)inURL sender:(id)sender delegate:(id)inDelegate
{
  WebAppViewController *webAppViewController = [[WebAppViewController alloc] initWithNibName:@"WebAppView" bundle:nil];
  [webAppViewController setWebAppViewDelegate:inDelegate];
  [webAppViewController view];

  NSURLRequest *siteRequest = [NSURLRequest requestWithURL:inURL];

  [[webAppViewController webView] loadRequest:siteRequest];
}


+ (void)pushWebAppURL:(NSURL*)inURL sender:(id)sender
{
  [WebAppViewController pushWebAppURL:inURL sender:sender delegate:nil];
}

+ (void)pushWebAppURL:(NSURL*)inURL sender:(id)sender delegate:(id)inDelegate
{  
  NSURLRequest *siteRequest = [NSURLRequest requestWithURL:inURL];
  [WebAppViewController pushWebAppURLRequest:siteRequest sender:sender delegate:inDelegate];
}


- (BOOL)searchBarIsVisible
{
  BOOL barIsVisible = (self.searchBar.superview.frame.origin.y >= -1);
  
  return barIsVisible;
}

- (void)setSearchBarVisible:(BOOL)visible animated:(BOOL)animated
{
  UIView *outerSearchBar = self.searchBar.superview;
  
  BOOL barIsVisible = (outerSearchBar.frame.origin.y >= -1);
  
  if (barIsVisible == visible)
    return;

  CGRect newBarFrame = outerSearchBar.frame;
  CGRect newWebViewFrame = self.webView.frame;
  CGFloat adjustment = newBarFrame.size.height;
  if (!visible)
    adjustment = -adjustment;

  
  newBarFrame.origin.y += adjustment;
  newWebViewFrame.origin.y += adjustment;
  newWebViewFrame.size.height -= adjustment;
  
  if (animated)
    [UIView beginAnimations:nil context:nil];
    
  [outerSearchBar setFrame:newBarFrame];
  [self.webView setFrame:newWebViewFrame];
  
  if (animated)
    [UIView commitAnimations];
}

- (IBAction)toggleSearchBar:(id)sender
{
  BOOL newVisibility = ![self searchBarIsVisible];
  [self setSearchBarVisible:newVisibility animated:YES];
  NSString *searchBarKey = [self.navigationController gncSearchBarVisibilityKey];
  [[NSUserDefaults standardUserDefaults] setBool:newVisibility forKey:searchBarKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
