//
//  SkipPillsViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//



@protocol SkipPillsViewControllerDelegate

@required

- (void)handleSkipPillsDone:(NSArray*)skippedDrugIDs;
- (void)handleSkipPillsCancel;

@end
