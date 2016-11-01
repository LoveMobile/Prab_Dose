//
//  DrugHistoryViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 7/31/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "DateTimePickerViewControllerDelegate.h"
#import "HistoryAddEditEventViewControllerDelegate.h"

@interface DrugHistoryViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															  MFMailComposeViewControllerDelegate,
														      HistoryAddEditEventViewControllerDelegate>
{
@private
	NSString* drugId;
    NSString* personId;
	NSDateFormatter* dateFormatter;
	UITableView *tableView;
	UITableViewCell *timeTableViewCell;
	UITableViewCell *noteTableViewCell;
	UITableViewCell *addEntryTableViewCell;
    UITableViewCell *exampleTimeTableViewCell;
	NSMutableArray* historyDateEventsList;
	NSMutableArray* deletedEvents;
	NSMutableArray* insertedEvents;
	NSIndexPath* editedIndexPath;
	BOOL isEditing;
    BOOL refreshNeeded;
    NSMutableDictionary* quantityRemainingOffsetByDrugId;
    NSMutableDictionary* refillRemainingOffsetByDrugId;
    UIBarButtonItem* editButton;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
             personId:(NSString*)pId
               drugId:(NSString*)Id;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *timeTableViewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *noteTableViewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *addEntryTableViewCell;

@end
