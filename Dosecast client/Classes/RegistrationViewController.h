//
//  RegistrationViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "RegistrationViewControllerDelegate.h"

@interface RegistrationViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	UITableViewCell *termsCell;
	UITableViewCell *submitButtonCell;
	UITableView* tableView;
	NSObject<RegistrationViewControllerDelegate>* __weak registrationDelegate;
}

- (IBAction)handleSubmit:(id)sender;

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil;

@property (nonatomic, strong) IBOutlet UITableViewCell *termsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *submitButtonCell;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, weak) NSObject<RegistrationViewControllerDelegate>* registrationDelegate;

@end
