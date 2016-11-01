//
//  JoinGroupEnterGroupNameViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JoinGroupEnterGroupNameViewControllerDelegate.h"
#import "ServerProxyDelegate.h"
#import "ViewDeleteGroupViewControllerDelegate.h"
#import "JoinGroupEnterPasswordViewControllerDelegate.h"

@class Group;

@interface JoinGroupEnterGroupNameViewController : UIViewController<UITextFieldDelegate, UITableViewDelegate,
															UITableViewDataSource, ServerProxyDelegate,
                                                            ViewDeleteGroupViewControllerDelegate,
                                                            JoinGroupEnterPasswordViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* groupNameCell;
	NSMutableString* groupName;
    UIImage* thisLogo;
    Group* thisGroup;
	NSObject<JoinGroupEnterGroupNameViewControllerDelegate>* __weak controllerDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<JoinGroupEnterGroupNameViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *groupNameCell;

@end
