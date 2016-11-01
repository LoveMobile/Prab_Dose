//
//  TimePeriodViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimePeriodViewControllerDelegate.h"

@interface TimePeriodViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
															    UIPickerViewDelegate, UIPickerViewDataSource>
{
@private
	UITableView* tableView;
	UIPickerView* pickerView;
	UITableViewCell* displayCell;
    int timePeriodSecs;
	NSObject<TimePeriodViewControllerDelegate>* __weak controllerDelegate;
    NSString* nibName;
	BOOL displayNeverButton;
    int uniqueIdentifier; 
    int minuteInterval;
    int maxHours;
    NSString* cellHeaderText;
    BOOL allowZero;
    UIBarButtonItem *doneButton;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
initialTimePeriodSecs:(int)initialTimePeriodSecs
       minuteInterval:(int)minute // the minute interval to use
             maxHours:(int)hours
           identifier:(int)uniqueID	// a unique identifier for the current picker
            viewTitle:(NSString*)viewTitle
           cellHeader:(NSString*)cellHeader
         displayNever:(BOOL)displayNever
           neverTitle:(NSString*)neverTitle
            allowZero:(BOOL)zero
              nibName:(NSString*)nib
             delegate:(NSObject<TimePeriodViewControllerDelegate>*)delegate;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIPickerView* pickerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayCell;

@end
