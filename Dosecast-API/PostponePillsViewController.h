//
//  PostponePillsViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PostponePillsViewControllerDelegate.h"
#import "LocalNotificationManagerDelegate.h"
@interface PostponePillsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															    UIPickerViewDelegate, UIPickerViewDataSource,
															    LocalNotificationManagerDelegate>
{
@private
	UITableView* tableView;
	UIPickerView* pickerView;
	UITableViewCell* pillTableViewCell;
    UITableViewCell *examplePillTableViewCell;
	NSObject<PostponePillsViewControllerDelegate>* __weak controllerDelegate;
	NSMutableDictionary* postponePillsDict; // Dictionary containing an interval for each drug
	NSString* activeDrugId; // The drug whose postpone value is being set
	NSArray* drugIds;
	NSString* footerMessage;
	UIBarButtonItem *doneButton;
    NSMutableArray* postponedDrugIDs;
    NSMutableArray* drugListGroupIndices; // A list of NSNumbers indicating the indices of drugs in the drug list for distinct groups
}

// Initialize the controller to display numbers in the range [1..maxVal],
// optionally with a text suffix after each one
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
      drugsToPostpone:(NSArray*)drugsToPostpone
        footerMessage:(NSString*)footer
             delegate:(NSObject<PostponePillsViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIPickerView* pickerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *pillTableViewCell;

@end
