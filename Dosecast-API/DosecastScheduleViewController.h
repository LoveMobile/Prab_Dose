//
//  DosecastScheduleViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "DrugViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface DosecastScheduleViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
												       DrugViewControllerDelegate,
                                                       LocalNotificationManagerDelegate>
{
@private
	UITableView *tableView;
    UITableViewCell *examplePillTableViewCell;
    UITableViewCell *localNotificationWarningCell;
    UIView *scheduleToolbarView;
	UITableViewCell *pillTableViewCell;
	NSDateFormatter* dateFormatter;
	NSString* undoDrugId;
    NSDate* scheduleDay;
    CGFloat buttonMinimumScaleFactor;
    BOOL checkForDrugsWithScheduledDosesAlreadyAtDoseLimit;
    NSMutableSet* drugIdsWithScheduledDosesAlreadyAtDoseLimit;
    NSMutableArray* scheduleViewDoseTimes;
    NSMutableDictionary *drugImagesDictionary;
    UIImageView *drugPlaceholderImageView;
    UITableViewController* tableViewController;
    UIRefreshControl* refreshControl;
    BOOL isExceedingMaxLocalNotifications;
    NSMutableDictionary* wouldExceedDoseLimitIfTakenDict; // dictionary to cache whether dose limit would be exceeded if taken now
    NSMutableDictionary* nextAvailableDoseTimeDict; // dictionary to cache the next available dose time (if taking it now would exceed the dose limit)
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil;

- (IBAction)handlePostponePill:(id)sender;
- (IBAction)handleTakePill:(id)sender;
- (IBAction)handleUndoPill:(id)sender;
- (IBAction)handleSkipPill:(id)sender;
- (IBAction)handleAddDrug:(id)sender;
- (IBAction)handlePrevScheduleDay:(id)sender;
- (IBAction)handleNextScheduleDay:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UIView *scheduleToolbarView;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *localNotificationWarningCell;
@property (nonatomic, strong) IBOutlet UIImageView *drugPlaceholderImageView;

@end
