//
//  SkipPillsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SkipPillsViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"


@interface SkipPillsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                            LocalNotificationManagerDelegate>
{
@private
	UITableViewCell *pillTableViewCell;
    UITableViewCell *examplePillTableViewCell;
	UITableView *tableView;
	NSMutableDictionary* skipPillsDict; // Dictionary containing a bit for each overdue drug
	NSObject<SkipPillsViewControllerDelegate>* __weak skipPillsDelegate;
	UIBarButtonItem *doneButton;
    NSArray* drugIds;
    NSMutableArray* skippedDrugIDs;
    NSMutableArray* drugListGroupIndices; // A list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
              drugIds:(NSArray*)ids
			 delegate:(NSObject<SkipPillsViewControllerDelegate>*)delegate;

- (IBAction)handleCancel:(id)sender;
- (IBAction)handleDone:(id)sender;
- (NSString*)nextDrugToSkip; // Returns the next drug to skip

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;
@property (nonatomic, weak) NSObject<SkipPillsViewControllerDelegate> *skipPillsDelegate;

@end
