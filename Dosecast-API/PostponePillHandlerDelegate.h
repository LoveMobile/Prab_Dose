//
//  PostponePillHandlerDelegate.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PostponePillHandlerDelegate

@required

// Get the main navigation controller
- (UINavigationController*)getUINavigationController;

- (void)handlePostponePillHandlerDone:(NSArray*)postponedDrugIds;

@end
