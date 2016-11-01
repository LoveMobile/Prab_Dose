//
//  BarButtonDisabler.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BarButtonDisabler : NSObject
{
}

- (void) setToolbarStateForViewController:(UIViewController*)viewController enabled:(BOOL)enabled;

@end
