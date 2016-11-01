//
//  BarButtonDisabler.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "BarButtonDisabler.h"

@implementation BarButtonDisabler

- (id)init
{
    if ((self = [super init]))
    {
	}
    return self;
}

- (void) setToolbarStateForViewController:(UIViewController*)viewController enabled:(BOOL)enabled
{
    for (UIBarButtonItem* toolbarItem in viewController.navigationItem.leftBarButtonItems)
        [toolbarItem setEnabled:enabled];
    
    for (UIBarButtonItem* toolbarItem in viewController.navigationItem.rightBarButtonItems)
        [toolbarItem setEnabled:enabled];
    
    if (viewController.navigationItem.backBarButtonItem)
        viewController.navigationItem.backBarButtonItem.enabled = enabled;
    
    for (UIBarButtonItem* toolbarItem in viewController.toolbarItems)
        [toolbarItem setEnabled:enabled];
    
    UITabBarController* tabBarController = viewController.tabBarController;
    if (tabBarController)
    {
        for (UITabBarItem* tabBarItem in [tabBarController.tabBar items])
        {
            [tabBarItem setEnabled:enabled];
        }
    }
}



@end


