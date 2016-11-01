//
//  LateDoseSettingsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LateDoseSettingsViewControllerDelegate.h"
#import "TimePeriodViewControllerDelegate.h"


@interface LateDoseSettingsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
																  TimePeriodViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* lateDoseSwitchCell;
	UITableViewCell* lateDosePeriodCell;
	NSObject<LateDoseSettingsViewControllerDelegate>* __weak delegate;
    BOOL flagLateDoses;
    int lateDosePeriodSecs;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<LateDoseSettingsViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *lateDoseSwitchCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *lateDosePeriodCell;
@property (nonatomic, weak) NSObject<LateDoseSettingsViewControllerDelegate>* delegate;

@end
