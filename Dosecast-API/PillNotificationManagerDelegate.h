//
//  PillNotificationManagerDelegate.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/23/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol PillNotificationManagerDelegate

@required

// Get the main navigation controller
- (UINavigationController*)getUINavigationController;

// Callback for when the Dosecast component must be made visible. If Dosecast is embedded in a UITabBarController
// or other UI component, this component must be made visible at the time of this call if it is not already.
- (void)displayDosecastComponent;

// Callback to find out if the Dosecast component is visible. If Dosecast is embedded in a UITabBarController
// or other UI component, return whether the component is active/selected.
- (BOOL)isDosecastComponentVisible;

@end
