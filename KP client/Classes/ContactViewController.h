//
//  ContactViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ContactViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                    UIAlertViewDelegate>
{
@private
	UITableView* tableView;
    UITableViewCell* appointmentsAndAdviceCell;
    UIAlertView* phoneConfirmationAlert;
    UITableViewCell* appointmentsAndAdviceHeader;
}

- (IBAction)handleCall:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *appointmentsAndAdviceCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *appointmentsAndAdviceHeader;

@end
