//
//  TSQMonthPickerViewControllerCalendarRowCell.m
//  TimesSquare
//
//  Created by Jim Puls on 12/5/12.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "TSQMonthPickerViewControllerCalendarRowCell.h"
#import "DosecastUtil.h"

@implementation TSQMonthPickerViewControllerCalendarRowCell

- (void)layoutViewsForColumnAtIndex:(NSUInteger)index inRect:(CGRect)rect;
{
    // Move down for the row at the top
    rect.origin.y += self.columnSpacing;
    rect.size.height -= (self.bottomRow ? 2.0f : 1.0f) * self.columnSpacing;
    [super layoutViewsForColumnAtIndex:index inRect:rect];
}

- (UIImage *)todayBackgroundImage;
{
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@", [[DosecastUtil getResourceBundle] resourcePath], @"CalendarTodaysDate.png"];

    return [[UIImage imageNamed:imagePath] stretchableImageWithLeftCapWidth:4 topCapHeight:4];
}

- (UIImage *)selectedBackgroundImage;
{
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@", [[DosecastUtil getResourceBundle] resourcePath], @"CalendarSelectedDate.png"];

    return [[UIImage imageNamed:imagePath] stretchableImageWithLeftCapWidth:4 topCapHeight:4];
}

- (UIImage *)notThisMonthBackgroundImage;
{
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@", [[DosecastUtil getResourceBundle] resourcePath], @"CalendarPreviousMonth.png"];

    return [[UIImage imageNamed:imagePath] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
}

- (UIImage *)backgroundImage;
{
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@", [[DosecastUtil getResourceBundle] resourcePath],
                           [NSString stringWithFormat:@"CalendarRow%@.png", self.bottomRow ? @"Bottom" : @""]];

    return [UIImage imageNamed:imagePath];
}

@end
