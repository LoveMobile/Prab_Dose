//
//  DrugViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DrugAddEditViewControllerDelegate.h"
#import "DrugViewControllerDelegate.h"
#import "AddressBookUI/ABPersonViewController.h"
#import "AddressBook/AddressBook.h"
#import "LocalNotificationManagerDelegate.h"

@class DrugDosage;
@interface DrugViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
													   DrugAddEditViewControllerDelegate,
                                                       ABPersonViewControllerDelegate,
                                                       LocalNotificationManagerDelegate>
{
@private
	UITableView* tableView;
    UIImageView *drugPlaceholderImageView;
	NSString* drugId;
    UIImage *drugImage;
	UITableViewCell* nameCell;
	UITableViewCell* typeCell;
    UITableViewCell *drugImageCell;
	UITableViewCell* dosageCell;
	UITableViewCell* directionsCell;
	UITableViewCell* takeDrugScheduledCell;
	UITableViewCell* takeDrugIntervalCell;
	UITableViewCell* takeDrugAsNeededCell;
	UITableViewCell* remainingRefillCell;
    UITableViewCell* personCell;
    UITableViewCell* archivedCell;
	UITableViewCell* remindersCell;
    UITableViewCell* secondaryRemindersCell;
    UITableViewCell* doctorCell;
    UITableViewCell* pharmacyCell;
    UITableViewCell* prescriptionNumCell;
    UITableViewCell* logMissedDosesCell;
    UITableViewCell* notesCell;
    UITableViewCell* expirationCell;
    UIView* notificationMessage;
	NSDateFormatter* dateFormatter;
    BOOL allowEditing;
    NSMutableArray* tableViewSections;
    NSMutableArray* doctorPharmacyRows;
	NSObject<DrugViewControllerDelegate>* __weak delegate;
    NSDate* viewDate;
    BOOL isNewManagedDrug;
    BOOL isExistingManagedDrugRequiringNotification;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               drugId:(NSString*)Id
             viewDate:(NSDate*)date
         allowEditing:(BOOL)allow
             delegate:(NSObject<DrugViewControllerDelegate>*) del;
	
- (void)handleEdit:(id)sender;
- (void)handleViewLog:(id)sender;
- (void)handleRefill:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UIImageView *drugPlaceholderImageView;
@property (nonatomic, strong) IBOutlet UITableViewCell *nameCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *typeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *drugImageCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *dosageCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *directionsCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugScheduledCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugIntervalCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *takeDrugAsNeededCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *remainingRefillCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *archivedCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *remindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *secondaryRemindersCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *doctorCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *personCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *pharmacyCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *prescriptionNumCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *notesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *logMissedDosesCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *expirationCell;
@property (nonatomic, strong) IBOutlet UIView *notificationMessage;

@end
