//
//  PostponePillHandler.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PostponePillsViewControllerDelegate.h"
#import "PostponePillHandlerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface PostponePillHandler : NSObject<PostponePillsViewControllerDelegate,
                                      LocalNotificationManagerDelegate>
{
@private
    NSMutableArray* unpostponedDrugIds; // The drug IDs of drugs to postpone
	NSMutableArray* postponedDrugIds;
    NSObject<PostponePillHandlerDelegate>* __weak delegate;
    int postponeDurationMin;
    UIButton* sourceButton;
}

- (id)init:(NSArray*)drugIds // drug IDs of available drugs to postpone
sourceButton:(UIButton*)button
  delegate:(NSObject<PostponePillHandlerDelegate>*)del;

// Returns the minimum postpone period in minutes
+ (int) minimumPostponePeriodMin;

@end
