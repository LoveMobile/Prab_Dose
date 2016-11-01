//
//  DosecastAlertController.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum DosecastAlertControllerStyle: NSInteger  {
    DosecastAlertControllerStyleActionSheet  = 0,
    DosecastAlertControllerStyleAlert
} DosecastAlertControllerStyle;

@class DosecastAlertAction;
@interface DosecastAlertController : NSObject;

// Factory method for general use
+ (DosecastAlertController*)alertControllerWithTitle:(NSString*)title
                                             message:(NSString*)message
                                               style:(DosecastAlertControllerStyle)style;

// Factory method for specific case of a simple confirmation (OK) alert. Will automatically add a single 'OK' cancel action with no handler.
+ (DosecastAlertController*)simpleConfirmationAlertWithTitle:(NSString*)title
                                             message:(NSString*)message;

- (void) addAction:(DosecastAlertAction*)action;
- (void) showInViewController:(UIViewController*)viewController;
- (void) showInViewController:(UIViewController*)viewController sourceView:(UIView*)sourceView;
- (void) showInViewController:(UIViewController*)viewController sourceBarButtonItem:(UIBarButtonItem*)sourceBarButtonItem;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, assign) DosecastAlertControllerStyle style;
@property (nonatomic, readonly) NSArray* actions;

@end
