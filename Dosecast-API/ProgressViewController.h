//
//  ProgressViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

// View controller for displaying a progress bar and a message
@class BarButtonDisabler;
@interface ProgressViewController: UIViewController
{
@private
    NSMutableString* message;
    float progress;
    UIViewController* topController;
    BarButtonDisabler* barButtonDisabler;
}

-(void)showOnViewController:(UIViewController*)controller animated:(BOOL)animated;

-(void)hide:(BOOL)animated;

@property (readwrite, weak) NSString* message; // The message to display
@property (readwrite, assign) float progress;    // The progress so far
@property (nonatomic, readonly) BOOL visible;

@end
