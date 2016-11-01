//
//  GNCAppDelegate.m
//  GNC
//
//  Created by Dan Gilliam on 7/27/10.
//  Copyright Branding Brand, LLC 2010. All rights reserved.
//

#import "GNCAppDelegate.h"
#import "WebAppViewController.h"
#import "HomeViewController.h"
#import "GNCDosecastAPI.h"

@implementation GNCAppDelegate



#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
	[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
	
	static NSString* kLaunchCountKey = @"kLaunchCountKey";
	_launchCount = (int)[[NSUserDefaults standardUserDefaults] integerForKey:kLaunchCountKey];
	_launchCount++;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:_launchCount] forKey:kLaunchCountKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
    
    GNCDosecastAPI* dosecastAPI = [[GNCDosecastAPI alloc] initWithDelegate:_homeController
                                                        launchOptions:launchOptions];
        
    _homeController.dosecastAPI = dosecastAPI;
    _homeController.delegate = self;
    
	[_window addSubview:_tabBarController.view];
	[_window makeKeyAndVisible];
	
	return YES;
}

- (void) doneInitializingDosecast
{
    [_homeController registerDosecastUser];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    
    [_homeController.dosecastAPI applicationWillResignActive:application];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	/*
	 Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	 If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
	 */
    
    [_homeController.dosecastAPI applicationDidEnterBackground:application];
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	/*
	 Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
	 */
    
    [_homeController.dosecastAPI applicationWillEnterForeground:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	
	/*
	 Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	 */
    
    [_homeController.dosecastAPI applicationDidBecomeActive:application];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	/*
	 Called when the application is about to terminate.
	 See also applicationDidEnterBackground:.
	 */
    
    [_homeController.dosecastAPI applicationWillTerminate:application];
}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
	[_homeController.dosecastAPI didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
	[_homeController.dosecastAPI didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	[_homeController.dosecastAPI didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
	[_homeController.dosecastAPI didReceiveRemoteNotification:userInfo];
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	/*
	 Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
	 */
}

- (void) displayHomeTab
{
    _tabBarController.selectedViewController = _homeController.navigationController;
}

- (BOOL) isHomeTabVisible
{
    return (_tabBarController.selectedViewController == _homeController.navigationController);
}



@end



#pragma mark -
#pragma mark UINavigationController extensions

// Maintain separate search bar visibility state depending on the tab.
// 
// two settings are stored:
//    1) does home tab show the search bar?       (key="HomeTabSearchBarVisible")
//    2) do all other tabs show the search bar?   (key="OtherTabSearchBarVisible")
//
// If this navigation controller is in the Home tab, search defaults to visible.
// For all other tabs, search defaults to hidden.

@implementation UINavigationController (GNCExtensions)

- (NSString*)gncSearchBarVisibilityKey
{
	GNCAppDelegate *appDelegate = (GNCAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if (self == [[appDelegate homeController] navigationController])
	{
		return @"HomeTabSearchBarVisible";
	}
	else
	{
		return @"OtherTabSearchBarVisible";
	}
}

- (BOOL)gncSearchBarVisibilityDefault
{
	GNCAppDelegate *appDelegate = (GNCAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if (self == [[appDelegate homeController] navigationController])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}



@end

