//
//  NumericPickerViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NumericPickerViewControllerDelegate.h"

@interface NumericPickerViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															    UIPickerViewDelegate, UIPickerViewDataSource>
{
@private
	UITableView* tableView;
	UIPickerView* pickerView;
	UITableViewCell* displayCell;
	NSObject<NumericPickerViewControllerDelegate>* __weak controllerDelegate;
	int numSigDigits;
	int numDecimals;
	NSString* displayTitle;
	float val;
	NSString* unit;
	NSArray* possibleUnits;
	BOOL displayNoneButton;
	BOOL allowZeroVal;
	UIBarButtonItem *doneButton;
	NSString* identifier;
	NSString* subIdentifier;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 sigDigits:(int)sigDigits
          numDecimals:(int)decimals
            viewTitle:(NSString*)viewTitle
         displayTitle:(NSString*)dispTitle
           initialVal:(float)initialVal
          initialUnit:(NSString*)initialUnit
        possibleUnits:(NSArray*)units
          displayNone:(BOOL)displayNone
         allowZeroVal:(BOOL)allowZero
           identifier:(NSString*)Id
        subIdentifier:(NSString*)subId
             delegate:(NSObject<NumericPickerViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIPickerView* pickerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayCell;

@end
