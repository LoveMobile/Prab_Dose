//
//  ChecklistViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChecklistViewControllerDelegate.h"

@interface ChecklistViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	NSArray* items;
	NSMutableDictionary* checkedStatusDict;
	UITableView* tableView;
	UITableViewCell* checkboxCell;
	NSString* headerText;
	NSString* footerText;
	NSObject<ChecklistViewControllerDelegate>* __weak delegate;
	NSString* identifier;
	NSString* subIdentifier;
	BOOL allowNone;
    UIBarButtonItem *doneButton;
}
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
				items:(NSArray*)i // An array of strings
		 checkedItems:(NSArray*)ci // An array of NSNumbers indicating which indices are checked
			viewTitle:(NSString*)viewTitle
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
            allowNone:(BOOL)none
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<ChecklistViewControllerDelegate>*)d;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *checkboxCell;

@end
