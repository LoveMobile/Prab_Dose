//
//  SettingsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BedtimeSettingsViewControllerDelegate.h"
#import	"AccountViewControllerDelegate.h"
#import "PicklistViewControllerDelegate.h"
#import "NumericPickerViewControllerDelegate.h"
#import "LateDoseSettingsViewControllerDelegate.h"
#import "BooleanViewControllerDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
#import "LocalNotificationManagerDelegate.h"
#import "JoinGroupEnterGroupNameViewControllerDelegate.h"
#import "ServerProxyDelegate.h"
#import "ViewDeleteGroupViewControllerDelegate.h"
#import "SyncViewDevicesViewControllerDelegate.h"
#import "TimePeriodViewControllerDelegate.h"
#import <AVFoundation/AVFoundation.h>

@class Group;
@interface SettingsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
														   BedtimeSettingsViewControllerDelegate,
													       AccountViewControllerDelegate,
														   PicklistViewControllerDelegate,
														   NumericPickerViewControllerDelegate,
                                                           LateDoseSettingsViewControllerDelegate,
                                                           BooleanViewControllerDelegate,
                                                           LocalNotificationManagerDelegate,
                                                           JoinGroupEnterGroupNameViewControllerDelegate,
                                                           ServerProxyDelegate,
                                                           ViewDeleteGroupViewControllerDelegate,
                                                           SyncViewDevicesViewControllerDelegate,
                                                           TimePeriodViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* accountCell;
	UITableViewCell* bedtimeCell;
	UITableViewCell* reminderSoundCell;
	UITableViewCell* earlyWarningCell;
    UITableViewCell* displayPostponeEventsCell;
    UITableViewCell* lateDoseCell;
    UITableViewCell* secondaryRemindersPeriodCell;
	UITableViewCell* historyDurationCell;
    UITableViewCell* drugSortOrderCell;
    UITableViewCell* changePasscodeCell;
    UITableViewCell* deleteAllDataCell;
    UITableViewCell* versionCell;
    UITableViewCell* serverUserIDCell;
    UITableViewCell* displayArchivedDrugsCell;
    UITableViewCell* displayDrugImagesCell;
    UITableViewCell* privacyModeCell;
    UITableViewCell* addGroupCell;
    UITableViewCell* groupCell;
    UITableViewCell* syncAddDeviceCell;
    UITableViewCell* syncMoveDeviceCell;
    UITableViewCell* syncViewDevicesCell;
    UITableViewCell* moveScheduledRemindersCell;
    UITableViewCell* refreshAllRemindersCell;
    UITableViewCell* loggingCell;
	NSDateFormatter* dateFormatter;
	NSArray* reminderSounds;
    NSMutableArray* tableViewSections;
    NSMutableArray* tableViewDisplaySectionRows;
    NSMutableArray* tableViewSecurityPrivacySectionRows;
    NSMutableDictionary* setPreferencesDict;
    Group* selectedGroup;
    UIImage* selectedGroupLogo;
    NSIndexPath* deletedGroupIndexPath;
    AVAudioPlayer* player;
    BOOL isMovingScheduledRemindersEarlier;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *bedtimeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *accountCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *reminderSoundCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *earlyWarningCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *lateDoseCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *historyDurationCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayPostponeEventsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugSortOrderCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *changePasscodeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *deleteAllDataCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *versionCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *secondaryRemindersPeriodCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayArchivedDrugsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayDrugImagesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *privacyModeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *serverUserIDCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *addGroupCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *groupCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncAddDeviceCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncMoveDeviceCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncViewDevicesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *moveScheduledRemindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *refreshAllRemindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *loggingCell;

@end
