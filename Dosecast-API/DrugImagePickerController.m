//
//  DrugImagePickerController.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 12/26/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DrugImagePickerController.h"

@interface DrugImagePickerController ()

@end

@implementation DrugImagePickerController

- (id) init
{
    self = [super init];
    if (self) {
        // Custom initialization
    }
    return self;    
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

@end
