//
//  ViewDeleteGroupViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewDeleteGroupViewControllerDelegate.h"

@class Group;
@interface ViewDeleteGroupViewController : UIViewController<UITableViewDelegate,
															UITableViewDataSource>
{
@private
	UITableView* tableView;
	UITableViewCell* groupCell;
    UITableViewCell* leaveButtonCell;
    NSString* headerText;
    NSString* footerText;
    BOOL showLeaveGroupButton;
    NSString* leftNavButtonTitle;
    NSString* rightNavButtonTitle;
    UIImage* logoImage;
    Group* group;
	NSObject<ViewDeleteGroupViewControllerDelegate>* __weak controllerDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            logoImage:(UIImage*)logo
                group:(Group*)g
            viewTitle:(NSString*)viewTitle
           headerText:(NSString*)header
           footerText:(NSString*)footer
 showLeaveGroupButton:(BOOL)showLeaveGroup
   leftNavButtonTitle:(NSString*)leftNavButton
  rightNavButtonTitle:(NSString*)rightNavButton
			 delegate:(NSObject<ViewDeleteGroupViewControllerDelegate>*)delegate;

- (IBAction)handleLeave:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *groupCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *leaveButtonCell;

@end
