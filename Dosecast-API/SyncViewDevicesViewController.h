//
//  SyncViewDevicesViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerProxyDelegate.h"
#import "SyncViewDevicesViewControllerDelegate.h"

@interface SyncViewDevicesViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                           ServerProxyDelegate>
{
@private
	UITableView* tableView;
    UITableViewCell *syncDeviceTableViewCell;
    NSMutableArray* syncDeviceList;
    NSDateFormatter* dateFormatter;
    NSString* hardwareIDToDelete;
    NSObject<SyncViewDevicesViewControllerDelegate>* delegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
       syncDeviceList:(NSArray*)syncDevices
             delegate:(NSObject<SyncViewDevicesViewControllerDelegate>*)del;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncDeviceTableViewCell;

@end
