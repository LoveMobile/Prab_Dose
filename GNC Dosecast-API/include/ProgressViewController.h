//
//  ProgressViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

// View controller for displaying a progress bar and a message
@interface ProgressViewController: UIViewController
{
@private
	BOOL visible;
    NSMutableString* message;
    float progress;
}

-(void)showInView:(UIView*)v;

// allowAnimation indicates whether there is enough time for any animation or whether the transition needs to be immediate
-(void)hide:(BOOL)allowAnimation;

@property (readwrite, weak) NSString* message; // The message to display
@property (readwrite, assign) float progress;    // The progress so far
@property (nonatomic, readonly) BOOL visible;

@end
