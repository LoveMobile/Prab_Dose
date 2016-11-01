//
//  GNCAppDelegate.h
//  GNC
//
//  Created by Dan Gilliam on 9/27/10.
//  Copyright Branding Brand, LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HomeViewControllerDelegate.h"
@class WebAppViewController;
@class HomeViewController;

@interface GNCAppDelegate : NSObject <UIApplicationDelegate, HomeViewControllerDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet UITabBarController *tabBarController;
@property (nonatomic, strong) IBOutlet HomeViewController   *homeController;
@property (nonatomic, strong) IBOutlet WebAppViewController *shopController;
@property (nonatomic, readonly) int launchCount;


@end


@interface UINavigationController (GNCExtensions)

- (NSString*)gncSearchBarVisibilityKey;
- (BOOL)gncSearchBarVisibilityDefault;

@end
