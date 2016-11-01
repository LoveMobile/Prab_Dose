//
//  PillAlertViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/15/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PillAlertViewControllerDelegate.h"

@class BarButtonDisabler;
@interface PillAlertViewController: UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	UIViewController* topController;
    NSObject<PillAlertViewControllerDelegate>* __weak delegate;
    NSDateFormatter* dateFormatter;
    UITableView *tableView;
    UITableViewCell *tableViewCell;
    UITableViewCell *exampleTableViewCell;
    UILabel *alertTitle;
    UILabel *alertMessage;
    UIButton *takeButton;
    UIButton *skipButton;
    UIButton *postponeButton;
    UIRefreshControl* refreshControl;
    UITableViewController* tableViewController;
    NSMutableDictionary* drugDosageExtraHeightDict; // A dictionary of additional height needed to display the dosage for each drug
    NSMutableDictionary* drugDirectionsExtraHeightDict; // A dictionary of additional height needed to display the dosage for each drug
    BarButtonDisabler* barButtonDisabler;
}

// The designated initializer.
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
             delegate:(NSObject<PillAlertViewControllerDelegate>*)del;
-(void)refresh;
-(void)showOnViewController:(UIViewController*)controller animated:(BOOL)animated;
-(void)hide:(BOOL)animated;

- (IBAction)handlePostponeDose:(id)sender;
- (IBAction)handleTakeDose:(id)sender;
- (IBAction)handleSkipDose:(id)sender;

@property (nonatomic, readonly) BOOL visible;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *tableViewCell;
@property (nonatomic, strong) IBOutlet UILabel *alertTitle;
@property (nonatomic, strong) IBOutlet UILabel *alertMessage;
@property (nonatomic, strong) IBOutlet UIButton *takeButton;
@property (nonatomic, strong) IBOutlet UIButton *skipButton;
@property (nonatomic, strong) IBOutlet UIButton *postponeButton;

@end
