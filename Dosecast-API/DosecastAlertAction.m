//
//  DosecastAlertAction.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "DosecastAlertAction.h"

@implementation DosecastAlertAction

@synthesize title;
@synthesize style;
@synthesize handler;

- (id)init:(NSString*)thisTitle
     style:(DosecastAlertActionStyle)thisStyle
   handler:(void (^)(DosecastAlertAction *action))thisHandler
{
    if ((self = [super init]))
    {
        title = thisTitle;
        style = thisStyle;
        handler = thisHandler;
    }
    return self;
}

+ (id)actionWithTitle:(NSString*)title
                style:(DosecastAlertActionStyle)style
              handler:(void (^)(DosecastAlertAction *action))handler
{
    return [[DosecastAlertAction alloc] init:title style:style handler:handler];
}

@end


