//
//  LateDoseSettingsViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/24/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol LateDoseSettingsViewControllerDelegate

@required

// Returns whether to pop the view controller
- (BOOL)handleLateDoseSettingsDone:(BOOL)flagLateDoses lateDosePeriodSecs:(int)lateDosePeriodSecs;

@end
