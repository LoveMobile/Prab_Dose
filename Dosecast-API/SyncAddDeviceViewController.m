//
//  SyncAddDeviceViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/17/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "SyncAddDeviceViewController.h"
#import "DosecastUtil.h"

static const CGFloat LABEL_BASE_HEIGHT = 18.0f;
static const CGFloat CELL_MIN_HEIGHT = 40.0f;
static const CGFloat INSTRUCTIONS_MARGIN = 20.0f;

@implementation SyncAddDeviceViewController

@synthesize tableView;
@synthesize instructionsCell;
@synthesize syncCodeCell;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil rendezvousCode:nil expires:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
       rendezvousCode:(NSString*)code
              expires:(NSDate*)expires
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        if (!code)
            code = @"";
        rendezvousCode = code;
        expirationMinsLeft = -1;
        self.hidesBottomBarWhenPushed = YES;
        if (expires)
        {
            NSTimeInterval interval = [expires timeIntervalSinceNow];
            if (interval > 0)
                expirationMinsLeft = (int)((interval / 60.0) + 0.5);
        }
        updateTimer = nil;
        if (expirationMinsLeft > 0)
            updateTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(handleTimerUpdate:) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)dealloc
{
    if (updateTimer && updateTimer.isValid)
    {
        [updateTimer invalidate];
        updateTimer = nil;
    }
}

-(void) handleTimerUpdate:(NSTimer*)theTimer
{
    expirationMinsLeft -= 1;
    [tableView reloadData];
    if (expirationMinsLeft == 0)
    {
        [updateTimer invalidate];
        updateTimer = nil;
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.title = NSLocalizedStringWithDefaultValue(@"ViewSyncAddDeviceTitle", @"Dosecast", [DosecastUtil getResourceBundle], @"Add Device", @"The title of the Sync Add Device view"]);
		
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;
	tableView.allowsSelection = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void) recalcDynamicCellWidths
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int screenWidth = 0;
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait ||
        self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        screenWidth = screenBounds.size.width;
    }
    else
        screenWidth = screenBounds.size.height;
    instructionsCell.frame = CGRectMake(instructionsCell.frame.origin.x, instructionsCell.frame.origin.y, screenWidth, instructionsCell.frame.size.height);
    [instructionsCell layoutIfNeeded];
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
    [self recalcDynamicCellWidths];
    
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
	{
		UILabel* instructions = (UILabel*)[instructionsCell viewWithTag:1];
        instructions.text = [NSString stringWithFormat:
                                  NSLocalizedStringWithDefaultValue(@"ViewSyncAddDeviceInstructions", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The instructions in the Sync Add Device view"]),
                                  [DosecastUtil getProductAppName]];
		return instructionsCell;
	}
    else if (indexPath.section == 1)
    {
        UILabel* code = (UILabel*)[syncCodeCell viewWithTag:1];
        
        NSMutableString* displayCode = [NSMutableString stringWithFormat:@""];
        int numCodeSegments = (int)([rendezvousCode length] / 4);
        if ([rendezvousCode length] % 4 > 0)
            numCodeSegments += 1;
        for (int i = 0; i < numCodeSegments; i++)
        {
            NSString* codeSegment = [[rendezvousCode substringWithRange:NSMakeRange(i*4, 4)] uppercaseString];
            if ([displayCode length] > 0)
                [displayCode appendString:@"-"];
            [displayCode appendString:codeSegment];
        }
        
        code.text = displayCode;
        return syncCodeCell;
    }
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
}

- (CGFloat) getHeightForCellLabel:(UITableViewCell*)cell tag:(int)tag withString:(NSString*)value
{
    UILabel* label = (UILabel*)[cell viewWithTag:tag];
    CGSize labelMaxSize = CGSizeMake(label.frame.size.width, LABEL_BASE_HEIGHT * (float)label.numberOfLines);
    CGRect rect = [value boundingRectWithSize:labelMaxSize
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName: label.font}
                                      context:nil];
    CGSize labelSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
    if (labelSize.height <= CELL_MIN_HEIGHT)
        return CELL_MIN_HEIGHT;
    else
        return labelSize.height+2.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        NSString* instructions = [NSString stringWithFormat:
                                  NSLocalizedStringWithDefaultValue(@"ViewSyncAddDeviceInstructions", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The instructions in the Sync Add Device view"]),
                                  [DosecastUtil getProductAppName]];
        CGFloat height = (int)ceilf([self getHeightForCellLabel:instructionsCell tag:1 withString:instructions]);
        height += INSTRUCTIONS_MARGIN;
        return height;
    }
	else
		return 40;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1)
        return NSLocalizedStringWithDefaultValue(@"ViewSyncMoveDeviceSyncCode", @"Dosecast", [DosecastUtil getResourceBundle], @"", @"The sync code in the Sync Move Device view"]);
    else
        return nil;
}

// Returns the string label to display for the given number of hours
-(NSString*)stringLabelForHours:(int)numHours
{
    NSString* hourSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"hour", @"The singular name for hour in interval drug descriptions"]);
    NSString* hourPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugHourNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"hours", @"The plural name for hour in interval drug descriptions"]);
    
    NSString* unit = nil;
    if (![DosecastUtil shouldUseSingularForInteger:numHours])
        unit = hourPlural;
    else
        unit = hourSingular;
    
    return [NSString stringWithFormat:@"%d %@", numHours, unit];
}

// Returns the string label to display for the given number of minutes
-(NSString*)stringLabelForMinutes:(int)numMins
{
    NSString* minSingular = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNameSingular", @"Dosecast", [DosecastUtil getResourceBundle], @"min", @"The singular name for minute in interval drug descriptions"]);
    NSString* minPlural = NSLocalizedStringWithDefaultValue(@"IntervalDrugMinNamePlural", @"Dosecast", [DosecastUtil getResourceBundle], @"mins", @"The plural name for minute in interval drug descriptions"]);
    
    NSString* unit = nil;
    if (![DosecastUtil shouldUseSingularForInteger:numMins])
        unit = minPlural;
    else
        unit = minSingular;
    
    return [NSString stringWithFormat:@"%d %@", numMins, unit];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1 && expirationMinsLeft > 0)
    {
        NSMutableString* timePhrase = [NSMutableString stringWithFormat:@""];

        int numHours = expirationMinsLeft/60;
        int numMinutesLeft = expirationMinsLeft%60;
        if (numHours > 0)
            [timePhrase appendString:[self stringLabelForHours:numHours]];
        if (numMinutesLeft > 0 || numHours == 0)
        {
            if (numHours > 0)
                [timePhrase appendString:@" "];
            [timePhrase appendString:[self stringLabelForMinutes:numMinutesLeft]];
        }
        
        return [NSString stringWithFormat:
                NSLocalizedStringWithDefaultValue(@"ViewSyncAddDeviceFooterPhrase", @"Dosecast", [DosecastUtil getResourceBundle], @"This code will expire in %@", @"The footer phrase in the Sync Add Device view"]),
                timePhrase];
    }
    else
        return nil;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

@end
