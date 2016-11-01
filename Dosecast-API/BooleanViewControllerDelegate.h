//
//  BooleanViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

@protocol BooleanViewControllerDelegate

@required

// Returns whether to allow the controller to be popped
- (BOOL)handleBooleanDone:(BOOL)value identifier:(NSString*)Id subIdentifier:(NSString*)subId;

@end
