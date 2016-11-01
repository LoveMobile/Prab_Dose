//
//  AccountViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/24/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//


@protocol AccountViewControllerDelegate

@required

// Called when the user initiated a subscribe and it completed successfully
- (void)handleSubscribeComplete;

@end
