//
//  MessagePanelViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MessagePanelViewController: UIViewController
{
@private
	UIViewController* topController;
}

-(void)showOnViewController:(UIViewController*)controller;
-(void)hide:(BOOL)animated;

@property (nonatomic, readonly) BOOL visible;
@property (readwrite, weak) NSString* message; // The message to display

@end
