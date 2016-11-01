//
//  DosecastAlertControllerImp.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "DosecastAlertController.h"

@interface DosecastAlertControllerImp : DosecastAlertController<UIAlertViewDelegate, UIActionSheetDelegate>
{
@private
    NSString* title;
    NSString* message;
    DosecastAlertControllerStyle style;
    DosecastAlertAction* cancelAction;
    DosecastAlertAction* destructiveAction;
    NSMutableArray* otherActions;
}

- (id)initWithTitle:(NSString*)t
            message:(NSString*)m
              style:(DosecastAlertControllerStyle)s;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, assign) DosecastAlertControllerStyle style;
@property (nonatomic, readonly) NSArray* actions;

@end
