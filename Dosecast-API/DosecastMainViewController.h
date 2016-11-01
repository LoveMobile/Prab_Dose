//
//  DosecastMainViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DrugViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface DosecastMainViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
												       DrugViewControllerDelegate,
                                                       LocalNotificationManagerDelegate>
{
@private
    UITableView *tableView;
	UITableViewCell *pillTableViewCell;
    UITableViewCell *examplePillTableViewCell;
    UITableViewCell* localNotificationWarningCell;
	NSDateFormatter* dateFormatter;
	NSIndexPath* deletedIndexPath;
    BOOL deletedLastRowInSection;
    BOOL isDeletingFromThisController;
    NSMutableArray* preDeletedDrugListGroupIndices;
    BOOL deletedLastSection;
	NSString* undoDrugId;
    UITableViewController* tableViewController;
    UIRefreshControl* refreshControl;
    CGFloat buttonMinimumScaleFactor;
    BOOL checkForDrugsWithScheduledDosesAlreadyAtDoseLimit;
    NSMutableArray* drugIdsWithScheduledDosesAlreadyAtDoseLimit;
    NSMutableDictionary *drugImagesDictionary;
    UIImageView *drugPlaceholderImageView;
    NSMutableArray* drugList;
    NSMutableArray* drugListGroupIndices; // A list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
    BOOL isExceedingMaxLocalNotifications;
    NSMutableDictionary* wouldExceedDoseLimitIfTakenDict; // dictionary to cache whether dose limit would be exceeded if taken now
    NSMutableDictionary* nextAvailableDoseTimeDict; // dictionary to cache the next available dose time (if taking it now would exceed the dose limit)
}

- (IBAction)handlePostponePill:(id)sender;
- (IBAction)handleTakePill:(id)sender;
- (IBAction)handleUndoPill:(id)sender;
- (IBAction)handleSkipPill:(id)sender;
- (IBAction)handleAddDrug:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *localNotificationWarningCell;
@property (nonatomic, strong) IBOutlet UIImageView *drugPlaceholderImageView;

@end     
