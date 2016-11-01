//
//  JoinGroupEnterPasswordViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JoinGroupEnterPasswordViewControllerDelegate.h"
#import "ServerProxyDelegate.h"

@class Group;

@interface JoinGroupEnterPasswordViewController : UIViewController<UITextFieldDelegate, UITableViewDelegate,
															UITableViewDataSource, ServerProxyDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* passwordCell;
    UITableViewCell* termsCell;
    UITableViewCell* submitButtonCell;
    Group* group;
    NSMutableString* password;
    NSMutableArray* tableViewSections;
	NSObject<JoinGroupEnterPasswordViewControllerDelegate>* __weak controllerDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
                group:(Group*)g
			 delegate:(NSObject<JoinGroupEnterPasswordViewControllerDelegate>*)delegate;

- (IBAction)handleSubmit:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *termsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *submitButtonCell;

@end
