//
//  HistoryAddEditEventViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HistoryAddEditEventViewControllerDelegate.h"
#import "DosecastCoreTypes.h"
#import "PicklistViewControllerDelegate.h"
#import "DateTimePickerViewControllerDelegate.h"
#import "TimePeriodViewControllerDelegate.h"
#import "NumericPickerViewControllerDelegate.h"

@interface HistoryAddEditEventViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															      PicklistViewControllerDelegate,
													              DateTimePickerViewControllerDelegate,
                                                                  TimePeriodViewControllerDelegate,
                                                                  NumericPickerViewControllerDelegate>
{
@private
	UITableView* tableView;
	NSArray* possibleDrugIds;
    NSString* drugId;
    NSString* viewTitle;
	NSString* actionName;
	NSDate* eventTime;
    NSDate* scheduledTime;
    int postponePeriodSecs;
    float refillAmount;
	UITableViewCell *drugNameCell;
	UITableViewCell *actionCell;
	UITableViewCell *eventTimeCell;	
    UITableViewCell *scheduledTimeCell;
    UITableViewCell *postponePeriodCell;
    UITableViewCell *refillAmountCell;
	NSDateFormatter* dateFormatter;
    NSMutableArray* tableViewSections;
	NSObject<HistoryAddEditEventViewControllerDelegate>* __weak controllerDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            viewTitle:(NSString*)title
               drugId:(NSString*)Id
      possibleDrugIds:(NSArray*)possibleIds
           actionName:(NSString*)action
            eventTime:(NSDate*)event
        scheduledTime:(NSDate*)scheduled
   postponePeriodSecs:(int)postponePeriod
         refillAmount:(float)refAmount
			 delegate:(NSObject<HistoryAddEditEventViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugNameCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *actionCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *eventTimeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *scheduledTimeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *postponePeriodCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *refillAmountCell;

@end
