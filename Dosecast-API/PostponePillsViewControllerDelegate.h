//
//  PostponePillsViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol PostponePillsViewControllerDelegate

@required

- (void)handlePostponePillsDone:(NSArray*)postponedDrugIDs;
- (void)handlePostponePillsCancel;

@end
