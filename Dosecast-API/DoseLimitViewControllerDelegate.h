//
//  DoseLimitViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/24/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol DoseLimitViewControllerDelegate

@required

- (void)handleSetDoseLimit:(int)limitType // for enum representing none, per day, per 24 hrs
               maxNumDoses:(int)maxNumDoses; // -1 if none

@end
