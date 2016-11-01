//
//  DosecastNavigationController.m
//  Dosecast
//
//  Created by Jonathan Levene on 9/30/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DosecastNavigationController.h"

@implementation DosecastNavigationController

- (BOOL)shouldAutorotate
{
    return self.topViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return self.topViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return [self.topViewController preferredInterfaceOrientationForPresentation];
}

@end
