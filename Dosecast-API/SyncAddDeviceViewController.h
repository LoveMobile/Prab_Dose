//
//  SyncAddDeviceViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SyncAddDeviceViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	UITableView* tableView;
	UITableViewCell* instructionsCell;
	UITableViewCell* syncCodeCell;
    NSString* rendezvousCode;
    int expirationMinsLeft;
    NSTimer* updateTimer;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               rendezvousCode:(NSString*)code
              expires:(NSDate*)expires;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *instructionsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncCodeCell;

@end
