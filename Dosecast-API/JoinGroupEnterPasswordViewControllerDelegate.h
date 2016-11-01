//
//  JoinGroupEnterPasswordViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

@protocol JoinGroupEnterPasswordViewControllerDelegate

@required

// Callback for successful joining of a group
- (void)handleJoinGroupSuccess;

@end
