//
//  DrugNameViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DrugNameViewControllerDelegate.h"
#import "DrugDatabaseSearchControllerDelegate.h"

@interface DrugNameViewController : UIViewController<UITextFieldDelegate, UITableViewDelegate,
															UITableViewDataSource,
                                                            DrugDatabaseSearchControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* drugNameCell;
    UITableViewCell* drugDatabaseCell;
	NSMutableString* drugName;
	NSString* placeholderValue;
	NSObject<DrugNameViewControllerDelegate>* __weak controllerDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
             drugName:(NSString*)name
     placeholderValue:(NSString*)placeholder
			 delegate:(NSObject<DrugNameViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugNameCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugDatabaseCell;

@end
