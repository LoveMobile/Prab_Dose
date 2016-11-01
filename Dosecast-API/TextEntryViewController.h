//
//  TextEntryViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextEntryViewControllerDelegate.h"

@interface TextEntryViewController : UIViewController<UITextFieldDelegate, UITableViewDelegate,
															UITableViewDataSource,
                                                            UITextViewDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* textEntryCell;
    UITableViewCell* textEntryMultilineCell;
	int numTextFields;
	NSArray* initialValues;
	NSArray* placeholderStrings;
	UITextAutocapitalizationType capitalizationType;
	UITextAutocorrectionType correctionType;
	UIKeyboardType keyboardType;
	BOOL secureTextEntry;
	NSString* identifier;
	NSString* subIdentifier;
	NSObject<TextEntryViewControllerDelegate>* __weak controllerDelegate;
	int textItemWithFocus; // during an orientation transition, the text item with focus
    BOOL multiline;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			viewTitle:(NSString*)viewTitle
		numTextFields:(int)numFields
            multiline:(BOOL)multi
		initialValues:(NSArray*)initialVals
   placeholderStrings:(NSArray*)placeholders
   capitalizationType:(UITextAutocapitalizationType)capitalization
	   correctionType:(UITextAutocorrectionType)correction
		 keyboardType:(UIKeyboardType)keyboard
	  secureTextEntry:(BOOL)secure
           identifier:(NSString*)Id
        subIdentifier:(NSString*)subId
			 delegate:(NSObject<TextEntryViewControllerDelegate>*)delegate;

- (void)handleCancel:(id)sender;
- (void)handleDone:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *textEntryCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *textEntryMultilineCell;

@end
