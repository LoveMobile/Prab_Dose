//
//  WebAppViewController.h
//  Sephora
//
//  Created by Dan Gilliam on 7/2/10.
//  Copyright 2010 Branding Brand, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebAppViewController : UIViewController <UIWebViewDelegate>
{
  
  NSString *_staticTitle;
  BOOL _deferInitialLoad;
  BOOL _loadedFromData;
}

@property (nonatomic, strong) IBOutlet UIImageView *placeholderView;
@property (nonatomic, strong) IBOutlet UIWebView *webView;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) IBOutlet UIView *navbarButtonView;
@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UIButton *brandsButton;
@property (nonatomic, strong) NSURL *initialURL;
@property (nonatomic, strong) NSData *initialData;
@property (nonatomic, strong) NSURL *initialDataBaseURL;
@property (nonatomic, weak) id webAppViewDelegate;
@property (nonatomic, assign) BOOL showsHomeButton;
@property (nonatomic, assign) BOOL contentFlushed;

+ (void)pushWebAppURL:(NSURL*)inURL sender:(id)sender;
+ (void)pushWebAppURL:(NSURL*)inURL sender:(id)sender delegate:(id)inDelegate;

+ (void)pushWebAppURLRequest:(NSURLRequest*)inRequest sender:(id)sender;
+ (void)pushWebAppURLRequest:(NSURLRequest*)inRequest sender:(id)sender delegate:(id)inDelegate;

+ (void)loadWebAppURLInBackground:(NSURL*)inURL sender:(id)sender delegate:(id)inDelegate;

- (void)setSearchBarVisible:(BOOL)visible animated:(BOOL)animated;
- (BOOL)searchBarIsVisible;
- (IBAction)toggleSearchBar:(id)sender;

- (void)reloadInitialURL;
- (void)clearContent;

@end
