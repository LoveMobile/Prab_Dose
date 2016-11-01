//
//  SkipPillHandler.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SkipPillsViewControllerDelegate.h"
#import "SkipPillHandlerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface SkipPillHandler : NSObject<SkipPillsViewControllerDelegate,
                                      LocalNotificationManagerDelegate>
{
@private
    NSMutableArray* unskippedDrugIds; // The drug IDs of drugs to skip
	NSMutableArray* skippedDrugIds;
    NSObject<SkipPillHandlerDelegate>* __weak delegate;
    BOOL displayActions;
    UIButton* sourceButton;
}

    - (id)init:(NSArray*)drugIds // drug IDs of available drugs to skip
displayActions:(BOOL)actions // whether to show the possible action choices
  sourceButton:(UIButton*)button
      delegate:(NSObject<SkipPillHandlerDelegate>*)del;

@end
