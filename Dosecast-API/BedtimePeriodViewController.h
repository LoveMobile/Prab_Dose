//
//  BedtimePeriodViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BedtimePeriodViewControllerDelegate.h"

@interface BedtimePeriodViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	UITableView* tableView;
	UIDatePicker* datePicker;
	UITableViewCell* bedtimeStartCell;
	UITableViewCell* bedtimeEndCell;
	NSObject<BedtimePeriodViewControllerDelegate>* __weak delegate;
	NSDate* bedtimeStartDate;
	NSDate* bedtimeEndDate;
	BOOL bedtimeStartSelected;
	NSDateFormatter* dateFormatter;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
     bedtimeStartDate:(NSDate*)bedtimeStartDateVal
       bedtimeEndDate:(NSDate*)bedtimeEndDateVal
             delegate:(NSObject<BedtimePeriodViewControllerDelegate>*)del;

- (IBAction)handleDateTimeValueChanged:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIDatePicker* datePicker;
@property (nonatomic, strong) IBOutlet UITableViewCell *bedtimeStartCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *bedtimeEndCell;
@property (nonatomic, weak) NSObject<BedtimePeriodViewControllerDelegate>* delegate;

@end
