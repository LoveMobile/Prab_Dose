//
//  BedtimePeriodViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/24/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol BedtimePeriodViewControllerDelegate

@required

- (void)handleSetBedtimePeriod:(NSDate*)bedtimeStartDate bedtimeEndDate:(NSDate*)bedtimeEndDate;

@end
