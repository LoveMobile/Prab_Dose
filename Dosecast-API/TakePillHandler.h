//
//  TakePillHandler.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 8/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TakePillsViewControllerDelegate.h"
#import "DateTimePickerViewControllerDelegate.h"
#import "TakePillHandlerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface TakePillHandler : NSObject<TakePillsViewControllerDelegate,
                                      DateTimePickerViewControllerDelegate,
                                      LocalNotificationManagerDelegate>
{
@private
    NSMutableArray* untakenDrugIds; // The drug IDs of drugs to take
	NSMutableArray* takenDrugIds;
	NSDate* takePillTime; // The time of the drug being taken
    NSObject<TakePillHandlerDelegate>* __weak delegate;
    UIButton* sourceButton;
}

- (id)init:(NSArray*)drugIds // drug IDs of available drugs to take
sourceButton:(UIButton*)button
  delegate:(NSObject<TakePillHandlerDelegate>*)del;

@end
