//
//  ChecklistViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//



@protocol ChecklistViewControllerDelegate

@required

- (BOOL)handleDoneCheckingItemsInList:(NSArray*)checkedItems identifier:(NSString*)Id subIdentifier:(NSString*)subId; // Returns whether to allow the controller to be popped

@end
