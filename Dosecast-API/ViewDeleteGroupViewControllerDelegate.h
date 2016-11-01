//
//  ViewDeleteGroupViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

@protocol ViewDeleteGroupViewControllerDelegate

@optional

// Callback for when user taps on the left nav button
- (void)handleViewGroupTapLeftNavButton;

// Callback for when user taps on the right nav button
- (void)handleViewGroupTapRightNavButton;

// Callback for when user requests to leave the group
- (void)handleLeaveGroup;

@end
