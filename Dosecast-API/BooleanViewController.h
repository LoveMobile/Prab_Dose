//
//  BooleanViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BooleanViewControllerDelegate.h"

@interface BooleanViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
    BOOL value;
	UITableView* tableView;
	UITableViewCell* booleanCell;
    NSString* displayTitle;
	NSString* headerText;
	NSString* footerText;
	NSObject<BooleanViewControllerDelegate>* __weak delegate;
	NSString* identifier;
	NSString* subIdentifier;
}
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
         initialValue:(BOOL)v
			viewTitle:(NSString*)vTitle
         displayTitle:(NSString*)dTitle
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<BooleanViewControllerDelegate>*)d;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *booleanCell;

@end
