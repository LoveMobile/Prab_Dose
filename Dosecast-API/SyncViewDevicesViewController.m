//
//  SyncViewDevicesViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "SyncViewDevicesViewController.h"
#import "DosecastUtil.h"
#import "DataModel.h"
#import "ServerProxy.h"
#import "SyncDevice.h"
#import "HistoryManager.h"
#import "DosecastAlertController.h"
#import "DosecastAlertAction.h"

@implementation SyncViewDevicesViewController

@synthesize tableView;
@synthesize syncDeviceTableViewCell;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil syncDeviceList:nil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
       syncDeviceList:(NSArray*)syncDevices
             delegate:(NSObject<SyncViewDevicesViewControllerDelegate>*)del
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        self.hidesBottomBarWhenPushed = YES;
        if (!syncDevices)
            syncDevices = [[NSArray alloc] init];
        syncDeviceList = [NSMutableArray arrayWithArray:syncDevices];
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        hardwareIDToDelete = nil;
        delegate = del;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSyncViewDevicesTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"View Devices", @"The title of the Sync View Devices view"]);
		
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
        
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	tableView.allowsSelection = YES;
    
    [self.tableView setEditing:YES animated:NO];
    self.tableView.allowsSelectionDuringEditing = NO;

}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)detachDeviceServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage
{
    DataModel* dataModel = [DataModel getInstance];
    
    [syncDeviceList setArray:syncDevices];
    [tableView reloadData];
    
    if (status == ServerProxySuccess)
    {
        if ([hardwareIDToDelete isEqualToString:dataModel.hardwareID])
        {
            [dataModel performDeleteAllData];
            [dataModel allowDosecastUserInteractionsWithMessage:YES];
        }
        else
        {
            [dataModel allowDosecastUserInteractionsWithMessage:YES];

            DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil message:NSLocalizedStringWithDefaultValue(@"ViewSyncRemoveDeviceSuccessMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The title on the alert appearing when a general error occurs"]) style:DosecastAlertControllerStyleAlert];
            [alert addAction:
             [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                            style:DosecastAlertActionStyleCancel
                                          handler:^(DosecastAlertAction *action){
                                              if (delegate && [delegate respondsToSelector:@selector(handleDeviceDetached)])
                                              {
                                                  [delegate handleDeviceDetached];
                                              }
                                          }]];

            [alert showInViewController:self];
        }
    }
    else
    {
        [dataModel allowDosecastUserInteractionsWithMessage:YES];
        
        NSString* errorCategory = nil;
        if (status == ServerProxyCommunicationsError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerUnavailableTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Unavailable", @"The title on the alert appearing when the server is unavailable"]);
        else if (status == ServerProxyServerError)
            errorCategory = NSLocalizedStringWithDefaultValue(@"ErrorServerInternalErrorTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Server Error", @"The title on the alert appearing when the server experiences an internal error"]);
        
        if (status == ServerProxyDeviceDetached)
        {
            DebugLog(@"detach device: detect device detach");

            errorMessage = NSLocalizedStringWithDefaultValue(@"ViewDevicesDeviceRemovedMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"This device has been removed from your account and all data has been deleted from the device.", @"The message appearing when a device has been removed from a user's account"]);
            DataModel* dataModel = [DataModel getInstance];
            dataModel.wasDetached = NO; // clear the wasDetached flag since we are displaying the error message to the user
            [dataModel writeToFile:nil];
        }
        
        NSMutableString* finalErrorMessage = [NSMutableString stringWithString:@""];
        if (errorCategory)
            [finalErrorMessage appendFormat:@"%@: ", errorCategory];
        [finalErrorMessage appendString:errorMessage];
        
        DosecastAlertController* alert = [DosecastAlertController simpleConfirmationAlertWithTitle:nil
                                                                                           message:finalErrorMessage];
        [alert showInViewController:self];
    }
    
    hardwareIDToDelete = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    	
    self.navigationController.navigationBar.barTintColor = [DosecastUtil getNavigationBarColor];
    self.navigationController.toolbar.barTintColor = [DosecastUtil getToolbarColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;

    if ( animated )
        [self.tableView reloadData];
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [syncDeviceList count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"DeviceCellIdentifier";
    
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        [[DosecastUtil getResourceBundle] loadNibNamed:@"SyncDeviceTableViewCell" owner:self options:nil];
        
        cell = syncDeviceTableViewCell;
        syncDeviceTableViewCell = nil;
    }
    
    UILabel* deviceNameLabel = (UILabel*)[cell viewWithTag:1];
    UILabel* lastSeenLabel = (UILabel*)[cell viewWithTag:2];
    
    SyncDevice* device = [syncDeviceList objectAtIndex:indexPath.row];
    NSMutableString* deviceName = [NSMutableString stringWithString:device.friendlyName];
    if ([device isCurrentDevice])
        [deviceName appendFormat:@" (%@)", NSLocalizedStringWithDefaultValue(@"ViewSyncViewDevicesThisDevice", @"Dosecast", [DosecastUtil getResourceBundle], @"this device", @"The title of the Sync View Devices view"])];
    deviceNameLabel.text = deviceName;
    
    lastSeenLabel.hidden = !device.lastSeen;
    if (device.lastSeen)
    {
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        NSString* dateStr = [dateFormatter stringFromDate:device.lastSeen];
        [dateFormatter setDateStyle:NSDateFormatterNoStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        NSString* timeStr = [dateFormatter stringFromDate:device.lastSeen];
        NSString* dateFormatText = NSLocalizedStringWithDefaultValue(@"ViewDateTimePickerFutureTime", @"Dosecast", [DosecastUtil getResourceBundle], @"%@ at %@", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
        NSString* lastUpdatedText =NSLocalizedStringWithDefaultValue(@"ViewSyncViewDevicesLastUpdated", @"Dosecast", [DosecastUtil getResourceBundle], @"Last updated", @"The text in the main cell of the DateTimePicker view when the date is in the future"]);
        lastSeenLabel.text = [NSString stringWithFormat:@"%@: %@", lastUpdatedText,
                              [NSString stringWithFormat:dateFormatText, dateStr, timeStr]];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return nil;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        SyncDevice* deviceToDelete = [syncDeviceList objectAtIndex:indexPath.row];
        hardwareIDToDelete = deviceToDelete.hardwareID;
        
        
        DosecastAlertController* alert = [DosecastAlertController alertControllerWithTitle:nil
                                                                                   message:NSLocalizedStringWithDefaultValue(@"ViewSyncRemoveDeviceConfirmation", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The text on the OK button in an alert"])
                                                                                     style:DosecastAlertControllerStyleAlert];
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonCancel", @"Dosecast", [DosecastUtil getResourceBundle], @"Cancel", @"The text on the Cancel button in an alert"])
                                        style:DosecastAlertActionStyleCancel
                                      handler:^(DosecastAlertAction* action){
                                          hardwareIDToDelete = nil;
                                      }]];
        
        [alert addAction:
         [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"ViewSyncRemoveDeviceButton", @"Dosecast", [DosecastUtil getResourceBundle], @"Remove Device", @"The title of the Sync Move Device view"])
                                        style:DosecastAlertActionStyleDefault
                                      handler:^(DosecastAlertAction* action){
                                          [[DataModel getInstance] disallowDosecastUserInteractionsWithMessage:NSLocalizedStringWithDefaultValue(@"ViewSpinnerUpdatingAccount", @"Dosecast", [DosecastUtil getResourceBundle], @"Updating account", @"The message appearing in the spinner view when updating the account"])];
                                          
                                          [[ServerProxy getInstance] detachDevice:hardwareIDToDelete respondTo:self];
                                      }]];
        
        [alert showInViewController:self];
    }
}

@end
