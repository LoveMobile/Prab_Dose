//
//  TakePillsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TakePillsViewControllerDelegate.h"
#import "DateTimePickerViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"

@interface TakePillsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
														    DateTimePickerViewControllerDelegate,
                                                            LocalNotificationManagerDelegate>
{
@private
	UITableViewCell *pillTableViewCell;
    UITableViewCell *examplePillTableViewCell;
	UITableView *tableView;
	NSMutableDictionary* takePillsDict; // Dictionary containing a time for each overdue drug
	NSMutableArray* takenDrugIDs;
	NSObject<TakePillsViewControllerDelegate>* __weak takePillsDelegate;
	NSDateFormatter* dateFormatter;
	NSIndexPath* takePillIndexPath; // The index path of a drug being taken
	UIBarButtonItem *doneButton;
	NSDate* takePillTime;
    NSArray* drugIds;
    NSMutableArray* drugListGroupIndices; // A list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
              drugIds:(NSArray*)ids
			 delegate:(NSObject<TakePillsViewControllerDelegate>*)delegate;

- (IBAction)handleCancel:(id)sender;
- (IBAction)handleDone:(id)sender;
- (NSString*)nextDrugToTake; // Returns the next drug to take

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;
@property (nonatomic, weak) NSObject<TakePillsViewControllerDelegate> *takePillsDelegate;

@end
