//
//  AccountViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PurchaseManagerDelegate.h"
#import "AccountViewControllerDelegate.h"
#import "ServerProxyDelegate.h"
#import "DosecastCoreTypes.h"

@class SKProduct;
@interface AccountViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
														  PurchaseManagerDelegate,
                                                          ServerProxyDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* accountTypeCell;
    UITableViewCell* subscriptionDescriptionCell;
	UITableViewCell* subscriptionProductCell;
	UITableViewCell* restorePurchaseCell;
	NSDateFormatter* dateFormatter;
	BOOL hasRefreshedProductList;
	NSObject<AccountViewControllerDelegate>* __weak delegate;
    AccountType origAccountType;
    NSDate* origSubscriptionExpires;
    UITableViewCell* exampleSubscriptionProductCell;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(NSObject<AccountViewControllerDelegate>*)del;

- (IBAction)handlePurchase:(id)sender;
- (IBAction)handleRestorePurchase:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *accountTypeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionDescriptionCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionProductCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *restorePurchaseCell;
@property (nonatomic, weak) NSObject<AccountViewControllerDelegate>* delegate;

@end
