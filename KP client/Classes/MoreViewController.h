//
//  MoreViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@class DosecastAPI;
@class SpinnerViewController;

@interface MoreViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                  MFMailComposeViewControllerDelegate,
                                                  UIActionSheetDelegate, UIAlertViewDelegate>
{
@private
	UITableView* tableView;
    UIActionSheet* emailConfirmSheet;
    DosecastAPI* dosecastAPI;
    SpinnerViewController* spinnerViewController;
    UIAlertView* emailDrugListWarningAlert;
    UIAlertView* emailDrugHistoryWarningAlert;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
          dosecastAPI:(DosecastAPI*)api;

@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end
