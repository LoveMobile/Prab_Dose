//
//  PicklistViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PicklistViewControllerDelegate.h"
#import "TextEntryViewControllerDelegate.h"

@class PicklistEditedItem;

@interface PicklistViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                           TextEntryViewControllerDelegate>
{
@private
	NSArray* nonEditableItems;
    NSMutableArray* editableItems;
	int selectedItem;
	UITableView* tableView;
	UITableViewCell* checkboxCell;
	UITableViewCell* addItemCell;
    UITableViewCell *exampleCheckboxCell;
    NSString* viewTitle;
	NSString* headerText;
	NSString* footerText;
	NSObject<PicklistViewControllerDelegate>* __weak delegate;
	NSString* identifier;
	NSString* subIdentifier;
	BOOL displayNoneButton;
    BOOL allowEditing;
    NSString* addItemCellText;
    NSString* addItemPlaceholderText;
    NSMutableArray* renamedItems;
    NSMutableArray* deletedItems;
    NSMutableArray* createdItems;  
    NSMutableArray* editedItems;      
    BOOL isEditing;
    UIBarButtonItem* doneButton;
}
- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
     nonEditableItems:(NSArray*)nei
        editableItems:(NSArray*)ei
		 selectedItem:(int)s
         allowEditing:(BOOL)editing
			viewTitle:(NSString*)title
		   headerText:(NSString*)header
		   footerText:(NSString*)footer
      addItemCellText:(NSString*)addItemText
addItemPlaceholderText:(NSString*)addPlaceholderText
		  displayNone:(BOOL)displayNone
		   identifier:(NSString*)Id
		subIdentifier:(NSString*)subId
			 delegate:(NSObject<PicklistViewControllerDelegate>*)d;

// called to commit pending renames and deletes
- (void) commitEdits:(NSArray*)deleted // deleted item indices are relative to the original editableItems list passed-in to PicklistViewController init
        renamedItems:(NSArray*)renamed // renamed item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)
        createdItems:(NSArray*)created; // created item indices are relative to the original editableItems list *post-deletions* (i.e. assuming the deleted items have already been applied)

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *checkboxCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *addItemCell;

@end
