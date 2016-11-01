//
//  SyncMoveDeviceViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerProxyDelegate.h"

@interface SyncMoveDeviceViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                           ServerProxyDelegate,
                                                           UITextFieldDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* warningCell;
	UITableViewCell* instructionsCell;
    UITableViewCell* syncCodeCell;
    UITableViewCell* submitCell;
    NSString* syncCode;
}

- (IBAction)handleSubmit:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *warningCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *instructionsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncCodeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *submitCell;

@end
