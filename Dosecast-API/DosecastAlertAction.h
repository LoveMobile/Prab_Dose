//
//  DosecastAlertAction.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum DosecastAlertActionStyle: NSInteger  {
    DosecastAlertActionStyleDefault = 0,
    DosecastAlertActionStyleCancel ,
    DosecastAlertActionStyleDestructive
} DosecastAlertActionStyle;

@interface DosecastAlertAction : NSObject
{
@private
    NSString* title;
    DosecastAlertActionStyle style;
    void (^handler)(DosecastAlertAction* action);
}

+ (id)actionWithTitle:(NSString*)title
                style:(DosecastAlertActionStyle)style
              handler:(void (^)(DosecastAlertAction *action))handler;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) DosecastAlertActionStyle style;

typedef void (^DosecastAlertActionHandler)(DosecastAlertAction* action);
@property (nonatomic, strong) DosecastAlertActionHandler handler;

@end
