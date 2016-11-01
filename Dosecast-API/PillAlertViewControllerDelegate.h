//
//  PillAlertViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/24/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol PillAlertViewControllerDelegate

@required

- (void)handleAlertViewDrug:(NSString*)drugId;
- (void)handleAlertTakeDose:(id)sender;
- (void)handleAlertSkipDose:(id)sender;
- (void)handleAlertPostponeDose:(id)sender;

@end
