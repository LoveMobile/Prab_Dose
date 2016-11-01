//
//  DrugAddEditViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DrugAddEditViewControllerDelegate.h"
#import "ReminderAddEditViewControllerDelegate.h"
#import "DosecastCoreTypes.h"
#import "TextEntryViewControllerDelegate.h"
#import "NumericPickerViewControllerDelegate.h"
#import "DrugNameViewControllerDelegate.h"
#import "DrugReminder.h"
#import "DrugDosage.h"
#import "PicklistViewControllerDelegate.h"
#import "AddressBookUI/ABPeoplePickerNavigationController.h"
#import "AddressBookUI/ABPersonViewController.h"
#import "DrugChooseImageViewController.h"
#import "LocalNotificationManagerDelegate.h"
#import "TSQMonthPickerViewControllerDelegate.h"

typedef enum {
	DrugAddEditViewControllerModeAddDrug	= 0,
	DrugAddEditViewControllerModeEditDrug	= 1
} DrugAddEditViewControllerMode;

@class AddressBookContact;
@class CustomNameIDList;
@class DrugChooseImageViewController;

@interface DrugAddEditViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
	                                                          ReminderAddEditViewControllerDelegate,
														      TextEntryViewControllerDelegate, NumericPickerViewControllerDelegate,
															  PicklistViewControllerDelegate, ABPeoplePickerNavigationControllerDelegate,
                                                              ABPersonViewControllerDelegate, DrugNameViewControllerDelegate,
                                                              DrugChooseImageDelegate, UIImagePickerControllerDelegate,
                                                              UINavigationControllerDelegate,
                                                              LocalNotificationManagerDelegate,
                                                              TSQMonthPickerViewControllerDelegate>
{
@private
	UITableView* tableView;
    UIImageView *drugPlaceholderImageView;
	NSString* drugId;
	NSMutableString* drugName;
    NSMutableString* drugImageGUID;
    NSMutableString* tempDrugImageGUID;
    BOOL shouldClearDrugImage;
    UIImage *drugImage;
	NSMutableString* directions;
    NSMutableString* notes;
    NSMutableString* personId;
    NSMutableString* prescriptionNum;
	DrugAddEditViewControllerMode controllerMode;
	UITableViewCell *drugNameCell;
	UITableViewCell *drugTypeCell;
    UITableViewCell *drugImageCell;
	UITableViewCell *doseInputCell;
    UITableViewCell *doseInputTextCell;
	UITableViewCell *directionsCell;
	UITableViewCell *remainingCell;
	UITableViewCell *refillCell;
    UITableViewCell *refillsRemainingCell;
	UITableViewCell *refillAlertCell;
	UITableViewCell *takeDrugScheduledCell;
	UITableViewCell *takeDrugIntervalCell;
	UITableViewCell *takeDrugAsNeededCell;
    UITableViewCell *doctorCell;
    UITableViewCell *pharmacyCell;
    UITableViewCell *personCell;
    UITableViewCell *prescriptionNumCell;
    UITableViewCell *archiveButtonCell;
    UITableViewCell *unarchiveButtonCell;
	UITableViewCell *remindersCell;
    UITableViewCell *secondaryRemindersCell;
    UITableViewCell *logMissedDosesCell;
	UITableViewCell *deleteButtonCell;
    UITableViewCell *notesCell;
    UITableViewCell *exampleDoseInputTextCell;
    UITableViewCell *expirationDateCell;
    UITableViewCell *expirationAlertCell;
	NSDateFormatter* dateFormatter;
	NSObject<DrugAddEditViewControllerDelegate>* __weak controllerDelegate;
	DrugDosage* dosage;
	DrugReminder* reminder;
    AddressBookContact* doctorContact;
    AddressBookContact* pharmacyContact;
    NSMutableArray* tableViewSections;
    NSMutableArray* remainingRefillRows;
    NSMutableArray* doctorPharmacyRows;
    BOOL pickingDoctor; // whether a doctor or a pharmacy is being picked
    NSMutableDictionary* preferencesDict;
    NSMutableArray* deletedItems;
    NSMutableArray* renamedItems;
    NSMutableArray* createdItems;
    DrugChooseImageViewController *chooseImageViewController;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
				 mode:(DrugAddEditViewControllerMode)mode
			   drugId:(NSString*)Id
   treatmentStartDate:(NSDate*)treatmentStartDate
			 delegate:(NSObject<DrugAddEditViewControllerDelegate>*)del;

- (IBAction)handleArchive:(id)sender;
- (IBAction)handleDelete:(id)sender;
- (IBAction)addDrugImage:(id)sender;
- (IBAction)editDrugImage:(id)sender;
- (IBAction)clearDrugImage:(id)sender;

- (void)updateClientSpecificButtonImages;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UIImageView *drugPlaceholderImageView;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugNameCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugTypeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugImageCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseInputCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doseInputTextCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *directionsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *remainingCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *refillCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *refillsRemainingCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *refillAlertCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugScheduledCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugIntervalCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugAsNeededCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doctorCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *pharmacyCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *personCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *prescriptionNumCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *archiveButtonCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *unarchiveButtonCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *remindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *secondaryRemindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *logMissedDosesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *deleteButtonCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *notesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *expirationDateCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *expirationAlertCell;

@property (strong, nonatomic) UIPopoverController *sharedPopover;


@end
