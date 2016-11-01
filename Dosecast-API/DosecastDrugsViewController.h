//
//  DosecastDrugsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DrugViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface DosecastDrugsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
													            DrugViewControllerDelegate,
                                                                LocalNotificationManagerDelegate>
{
@private
	UITableView *tableView;
    UITableViewCell *examplePillTableViewCell;
	UITableViewCell *pillTableViewCell;
    UITableViewCell *localNotificationWarningCell;
	NSIndexPath* deletedIndexPath;
    BOOL deletedLastRowInSection;
    NSMutableArray* preDeletedDrugListGroupIndices;
    BOOL deletedLastSection;
    BOOL isDeletingFromThisController;
    NSMutableDictionary *drugImagesDictionary;
    UIImageView *drugPlaceholderImageView;
    NSMutableArray* drugList;
    NSMutableArray* drugListGroupIndices;
    NSString* discontinuedDrugId;
    UITableViewController* tableViewController;
    UIRefreshControl* refreshControl;
    BOOL isExceedingMaxLocalNotifications;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil;

- (IBAction)handleAddDrug:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *localNotificationWarningCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;
@property (nonatomic, strong) IBOutlet UIImageView *drugPlaceholderImageView;

@end     
