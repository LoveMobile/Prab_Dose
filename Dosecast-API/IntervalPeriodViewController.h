//
//  IntervalPeriodViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IntervalPeriodViewControllerDelegate.h"

@interface IntervalPeriodViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															     UIPickerViewDelegate, UIPickerViewDataSource>
{
@private
	UITableView* tableView;
	UIPickerView* pickerView;
	UITableViewCell* displayCell;
	NSObject<IntervalPeriodViewControllerDelegate>* __weak controllerDelegate;
	int minutes;
	UIBarButtonItem *doneButton;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
       initialMinutes:(int)initialMinutes
             delegate:(NSObject<IntervalPeriodViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIPickerView* pickerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayCell;

@end
