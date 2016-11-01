//
//  HomeViewControllerDelegate.h
//  GNC test harness
//
//  Created by Jonathan Levene on 12/23/11.
//  Copyright (c) 2011 Branding Brand, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HomeViewControllerDelegate <NSObject>

@required

- (void) displayHomeTab;
- (BOOL) isHomeTabVisible;
- (void) doneInitializingDosecast;

@end
