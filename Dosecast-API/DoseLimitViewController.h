//
//  DoseLimitViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DoseLimitViewControllerDelegate.h"
#import "NumericPickerViewControllerDelegate.h"

typedef enum {
	DoseLimitViewControllerLimitTypeNever       = 0,
	DoseLimitViewControllerLimitTypePerDay     = 1,
	DoseLimitViewControllerLimitTypePer24Hours = 2
} DoseLimitViewControllerLimitType;

@interface DoseLimitViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                            NumericPickerViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* doseLimitNoneCell;
	UITableViewCell* doseLimitPerDayCell;
    UITableViewCell* doseLimitPer24HrsCell;
    UITableViewCell* maxNumDosesCell;
	NSObject<DoseLimitViewControllerDelegate>* __weak delegate;
    DoseLimitViewControllerLimitType limitType;
    int maxNumDoses;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            limitType:(DoseLimitViewControllerLimitType)limit
          maxNumDoses:(int)max
			 delegate:(NSObject<DoseLimitViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseLimitNoneCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseLimitPerDayCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseLimitPer24HrsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *maxNumDosesCell;
@property (nonatomic, weak) NSObject<DoseLimitViewControllerDelegate>* delegate;

@end
