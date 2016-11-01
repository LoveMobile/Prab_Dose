//
//  NumericPickerViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/21/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 
#import "DosecastCoreTypes.h"

@protocol NumericPickerViewControllerDelegate

@required

// Callback for numeric quantity
// If val is negative, this corresponds to 'None'. Returns whether to pop the view controller.
- (BOOL)handleSetNumericQuantity:(float)val unit:(NSString*)unit identifier:(NSString*)Id subIdentifier:(NSString*)subId;

@end
