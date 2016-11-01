//
//  ScheduleRepeatPeriodViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ScheduleRepeatPeriodViewControllerDelegate.h"

typedef enum {
	ScheduleRepeatPeriodDays  = 0,
	ScheduleRepeatPeriodWeeks = 1
} ScheduleRepeatPeriod;

@interface ScheduleRepeatPeriodViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                                       UIPickerViewDelegate, UIPickerViewDataSource>
{
@private
	UITableView* tableView;
	UIPickerView* pickerView;
	UITableViewCell* displayCell;
    int scheduleRepeatPeriodNum;
    ScheduleRepeatPeriod scheduleRepeatPeriod;
	NSObject<ScheduleRepeatPeriodViewControllerDelegate>* __weak controllerDelegate;
    NSString* nibName;
    int uniqueIdentifier; 
    NSString* cellHeaderText;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
initialScheduleRepeatPeriodNum:(int)initialScheduleRepeatPeriodNum
scheduleRepeatPeriod:(ScheduleRepeatPeriod)initialScheduleRepeatPeriod
          identifier:(int)uniqueID	// a unique identifier for the current picker
           viewTitle:(NSString*)viewTitle
          cellHeader:(NSString*)cellHeader
             nibName:(NSString*)nib
            delegate:(NSObject<ScheduleRepeatPeriodViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIPickerView* pickerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayCell;

@end
