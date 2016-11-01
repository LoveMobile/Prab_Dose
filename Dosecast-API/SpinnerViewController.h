//
//  SpinnerViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

// View controller for displaying a spinner and a message
@class BarButtonDisabler;
@interface SpinnerViewController: UIViewController
{
@private
    NSMutableString* message;
    int shiftY;
    BOOL didLoad;
    BOOL handleOrientationChange;
    UIViewController* topController;
    BarButtonDisabler* barButtonDisabler;
}

-(void)showOnViewController:(UIViewController*)controller animated:(BOOL)animated;

-(void)hide:(BOOL)animated;

// Shift the spinner by a given number of pixels vertically
-(void)shiftSpinnerPositionVertically:(int)pixelsY;

@property (readwrite, weak) NSString* message; // The message to display
@property (nonatomic, readonly) BOOL visible;
@property (nonatomic, assign) BOOL handleOrientationChange;

@end
