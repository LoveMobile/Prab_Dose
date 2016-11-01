//
//  TSQMonthPickerViewController.h
//  TimesSquare
//
//  Created by Jim Puls on 12/5/12.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <UIKit/UIKit.h>
#import "TSQMonthPickerViewControllerDelegate.h"

@interface TSQMonthPickerViewController : UIViewController
{
@private
    NSObject<TSQMonthPickerViewControllerDelegate>* __weak delegate;
    int uniqueIdentifier;
    NSDate* initialDate;
    BOOL displayNeverButton;
};

-(id)init:(NSString*)viewTitle
initialDate:(NSDate*)date
displayNever:(BOOL)displayNever
uniqueIdentifier:(int)Id
 delegate:(NSObject<TSQMonthPickerViewControllerDelegate>*)del;

@end
