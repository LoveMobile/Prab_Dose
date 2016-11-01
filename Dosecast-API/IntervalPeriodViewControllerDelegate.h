//
//  IntervalPeriodViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 5/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol IntervalPeriodViewControllerDelegate

@required

- (void)handleSetIntervalPeriod:(int)minutes;

@end
