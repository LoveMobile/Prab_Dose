//
//  SpinnerViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

// View controller for displaying a spinner and a message
@interface SpinnerViewController: UIViewController
{
@private
	BOOL visible;
    NSMutableString* message;
    int shiftY;
    BOOL didLoad;
    BOOL handleOrientationChange;
}

-(void)showInView:(UIView*)v;

// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
-(void)hide:(BOOL)allowAnimation;

// Shift the spinner by a given number of pixels vertically
-(void)shiftSpinnerPositionVertically:(int)pixelsY;

@property (readwrite, weak) NSString* message; // The message to display
@property (nonatomic, readonly) BOOL visible;
@property (nonatomic, assign) BOOL handleOrientationChange;

@end
