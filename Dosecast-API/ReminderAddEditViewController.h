//
//  ReminderAddEditViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/22/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DosecastCoreTypes.h"
#import "ReminderAddEditViewControllerDelegate.h"
#import "IntervalPeriodViewControllerDelegate.h"
#import "IntervalDrugReminder.h"
#import "ScheduledDrugReminder.h"
#import "AsNeededDrugReminder.h"
#import "TSQMonthPickerViewControllerDelegate.h"
#import "DateTimePickerViewControllerDelegate.h"
#import "ScheduleRepeatPeriodViewControllerDelegate.h"
#import "DoseLimitViewControllerDelegate.h"
#import "ChecklistViewControllerDelegate.h"

@interface ReminderAddEditViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
																  IntervalPeriodViewControllerDelegate,
																  DateTimePickerViewControllerDelegate,
															      TSQMonthPickerViewControllerDelegate,
                                                                  ScheduleRepeatPeriodViewControllerDelegate,
                                                                  DoseLimitViewControllerDelegate,
                                                                  ChecklistViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* intervalCheckboxCell;
	UITableViewCell* scheduleCheckboxCell;
	UITableViewCell* asNeededCheckboxCell;
	UITableViewCell* dailyCheckboxCell;
	UITableViewCell* weeklyCheckboxCell;
	UITableViewCell* treatmentStartsCell;
	UITableViewCell* treatmentEndsCell;
	UITableViewCell* monthlyCheckboxCell;
	UITableViewCell* customPeriodCheckboxCell;
	UITableViewCell* intervalCell;
    UITableViewCell* doseLimitCell;
	UITableViewCell* addTimeCell;
	UITableViewCell* timeCell;
    UITableViewCell* weekdayCell;
	DrugReminder* currReminder;
	IntervalDrugReminder* intervalReminder;
	ScheduledDrugReminder* scheduledReminder;
	AsNeededDrugReminder* asNeededReminder;
	NSObject<ReminderAddEditViewControllerDelegate>* __weak controllerDelegate;
	NSDateFormatter* dateFormatter;
	NSString* drugId;
    NSMutableArray* scheduledFrequencyRows;
    NSMutableArray* intervalReminderSections;
    NSMutableArray* asNeededReminderSections;
    NSMutableArray* scheduledReminderSections;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			   drugId:(NSString*)d
		 drugReminder:(DrugReminder*)reminder
			 delegate:(NSObject<ReminderAddEditViewControllerDelegate>*)delegate;

- (IBAction)handleCancel:(id)sender;
- (IBAction)handleDone:(id)sender;
- (void)handleSetIntervalPeriod:(int)minutes;
- (BOOL)handleSetDateTimeValue:(NSDate*)dateTimeVal forNibNamed:(NSString*)nibName identifier:(int)uniqueID;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *intervalCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *scheduleCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *asNeededCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *intervalCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseLimitCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *addTimeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *timeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *dailyCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *weeklyCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *monthlyCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *customPeriodCheckboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *treatmentStartsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *treatmentEndsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *weekdayCell;
@end
