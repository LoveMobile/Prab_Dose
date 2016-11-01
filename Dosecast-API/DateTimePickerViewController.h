//
//  DateTimePickerViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DateTimePickerViewControllerDelegate.h"

typedef enum {
	DateTimePickerViewControllerModePickDate	 = 0,
	DateTimePickerViewControllerModePickTime	 = 1,
	DateTimePickerViewControllerModePickDateTime = 2
} DateTimePickerViewControllerMode;

@interface DateTimePickerViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
{
@private
	UITableView* tableView;
	UIDatePicker* datePicker;
	UITableViewCell* displayCell;
	NSDate* currDate;
	NSObject<DateTimePickerViewControllerDelegate>* __weak controllerDelegate;
	NSString* nibName;
	BOOL displayNeverButton;
	NSDateFormatter* dateFormatter;
	DateTimePickerViewControllerMode controllerMode;
	int uniqueIdentifier; 
    int minuteInterval;
	NSString* cellHeaderText;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
   initialDateTimeVal:(NSDate*)initialDateTimeVal
                 mode:(DateTimePickerViewControllerMode)mode
       minuteInterval:(int)minute // the minute interval to use for time and dateTime modes
           identifier:(int)uniqueID	// a unique identifier for the current picker
            viewTitle:(NSString*)viewTitle
           cellHeader:(NSString*)cellHeader
         displayNever:(BOOL)displayNever
           neverTitle:(NSString*)neverTitle
              nibName:(NSString*)nib
             delegate:(NSObject<DateTimePickerViewControllerDelegate>*)delegate;

- (IBAction)handleDateTimeValueChanged:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView* tableView;
@property (nonatomic, strong) IBOutlet UIDatePicker* datePicker;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayCell;

@end
