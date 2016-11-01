//
//  DrugDatabaseSearchController.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DrugDatabaseSearchControllerDelegate.h"
#import "DrugPermutationsViewController.h"

@class SpinnerViewController;
@interface DrugDatabaseSearchController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                                 UISearchDisplayDelegate, UISearchBarDelegate,
                                                                 DrugPermutationsDelegate,
                                                                 UISearchBarDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* drugCell;
    UITableViewCell* noDrugsFoundCell;
    UITableViewCell* searchPromptCell;
    UITableViewCell* searchTooShortCell;
    NSMutableArray* searchResults;
    NSMutableString* searchText;
    NSMutableString* searchScope;
	NSObject<DrugDatabaseSearchControllerDelegate>* __weak delegate;
    SpinnerViewController* spinnerController;
}
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<DrugDatabaseSearchControllerDelegate>*)d;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *noDrugsFoundCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *searchPromptCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *searchTooShortCell;

@end
