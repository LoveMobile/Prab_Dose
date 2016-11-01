//
//  BedtimeSettingsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BedtimeSettingsViewControllerDelegate.h"
#import "BedtimePeriodViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface BedtimeSettingsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
																  BedtimePeriodViewControllerDelegate,
                                                                  LocalNotificationManagerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* bedtimeCell;
	UITableViewCell* bedtimePeriodCell;
	NSDateFormatter* dateFormatter;
	NSObject<BedtimeSettingsViewControllerDelegate>* __weak delegate;
	BOOL bedtimeDefined;
	int bedtimeStart;
	int bedtimeEnd;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<BedtimeSettingsViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *bedtimeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *bedtimePeriodCell;
@property (nonatomic, weak) NSObject<BedtimeSettingsViewControllerDelegate>* delegate;

@end
