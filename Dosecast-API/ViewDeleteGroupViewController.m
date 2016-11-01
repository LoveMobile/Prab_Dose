//
//  ViewDeleteGroupViewController.m
//  Dosecast
//
//  Created by Jonathan Levene on 3/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import "ViewDeleteGroupViewController.h"
#import "DataModel.h"
#import "DosecastUtil.h"
#import "Group.h"

static const int GROUP_LOGO_MARGIN = 8;
static const int GROUP_CONTENT_MARGIN = 5;

@implementation ViewDeleteGroupViewController

@synthesize tableView;
@synthesize groupCell;
@synthesize leaveButtonCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	return [self initWithNibName:nibNameOrNil
						  bundle:nibBundleOrNil
                       logoImage:nil
                           group:nil
                       viewTitle:nil
                      headerText:nil
                      footerText:nil
            showLeaveGroupButton:NO
              leftNavButtonTitle:nil
             rightNavButtonTitle:nil
						delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
            logoImage:(UIImage*)logo
                group:(Group*)g
            viewTitle:(NSString*)viewTitle
           headerText:(NSString*)header
           footerText:(NSString*)footer
 showLeaveGroupButton:(BOOL)showLeaveGroup
   leftNavButtonTitle:(NSString*)leftNavButton
  rightNavButtonTitle:(NSString*)rightNavButton
			 delegate:(NSObject<ViewDeleteGroupViewControllerDelegate>*)delegate
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

		self.title = viewTitle;
        logoImage = logo;
        group = g;
        headerText = header;
        footerText = footer;
        showLeaveGroupButton = showLeaveGroup;
        leftNavButtonTitle = leftNavButton;
        rightNavButtonTitle = rightNavButton;
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.hidesBottomBarWhenPushed = YES;
		controllerDelegate = delegate;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
    // Set background image in table
    tableView.backgroundColor = [DosecastUtil getViewBackgroundColor];

	// Set left nav button
    if (leftNavButtonTitle)
    {
        UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:leftNavButtonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(handleLeftNavButton:)];
        self.navigationItem.leftBarButtonItem = leftButton;
    }
	 
	// Set left nav button
    if (rightNavButtonTitle)
    {
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:rightNavButtonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(handleRightNavButton:)];
        self.navigationItem.rightBarButtonItem = rightButton;
    }
	
	tableView.sectionHeaderHeight = 16;
	tableView.sectionFooterHeight = 16;
	tableView.allowsSelection = YES;
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
    
    if (self.hidesBottomBarWhenPushed != self.navigationController.toolbarHidden)
        [self.navigationController setToolbarHidden:self.hidesBottomBarWhenPushed];
}

// Called prior to rotating the device orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{	
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	[tableView reloadData];
}

// Called after rotating the device orientation
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	[super didRotateFromInterfaceOrientation:interfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
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

- (void)handleLeftNavButton:(id)sender
{
    if (controllerDelegate && [controllerDelegate respondsToSelector:@selector(handleViewGroupTapLeftNavButton)])
    {
        [controllerDelegate handleViewGroupTapLeftNavButton];
    }
}

- (void)handleRightNavButton:(id)sender
{
    if (controllerDelegate && [controllerDelegate respondsToSelector:@selector(handleViewGroupTapRightNavButton)])
    {
        [controllerDelegate handleViewGroupTapRightNavButton];
    }
}

- (IBAction)handleLeave:(id)sender
{
    if (controllerDelegate && [controllerDelegate respondsToSelector:@selector(handleLeaveGroup)])
    {
        [controllerDelegate handleLeaveGroup];
    }
}

#pragma mark Table view methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (showLeaveGroupButton)
        return 2;
    else
        return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        UIImageView* groupLogoImage = (UIImageView*)[groupCell viewWithTag:1];
        UILabel* groupDisplayName = (UILabel*)[groupCell viewWithTag:2];
        UITextView* groupDescription = (UITextView*)[groupCell viewWithTag:3];
        
        groupDisplayName.text = group.displayName;
        groupDescription.text = group.description;
        if (logoImage)
        {
            groupLogoImage.image = logoImage;
            groupLogoImage.hidden = NO;
            CGFloat displayNameX = groupLogoImage.frame.origin.x + groupLogoImage.frame.size.width + GROUP_LOGO_MARGIN;
            groupDisplayName.frame = CGRectMake(displayNameX,
                                                groupDisplayName.frame.origin.y,
                                                groupCell.contentView.frame.size.width - GROUP_CONTENT_MARGIN - displayNameX,
                                                groupDisplayName.frame.size.height);
            groupDescription.frame = CGRectMake(displayNameX,
                                                groupDescription.frame.origin.y,
                                                groupCell.contentView.frame.size.width - GROUP_CONTENT_MARGIN - displayNameX,
                                                groupDescription.frame.size.height);
        }
        else
        {
            groupLogoImage.hidden = YES;
            groupDisplayName.frame = CGRectMake(groupLogoImage.frame.origin.x,
                                                groupDisplayName.frame.origin.y,
                                                groupCell.contentView.frame.size.width - GROUP_CONTENT_MARGIN - groupLogoImage.frame.origin.x,
                                                groupDisplayName.frame.size.height);
            groupDescription.frame = CGRectMake(groupLogoImage.frame.origin.x,
                                                groupDescription.frame.origin.y,
                                                groupCell.contentView.frame.size.width - GROUP_CONTENT_MARGIN - groupLogoImage.frame.origin.x,
                                                groupDescription.frame.size.height);
        }
        
        return groupCell;
    }
    else // indexPath.section == 1
    {
        UIView *backView = [[UIView alloc] initWithFrame:CGRectZero];
		backView.backgroundColor = [UIColor clearColor];
		leaveButtonCell.backgroundView = backView;
        leaveButtonCell.backgroundColor = [UIColor clearColor];
		
		// Dynamically set the color of the button if an image isn't already set.
		UIButton* leaveButton = (UIButton *)[leaveButtonCell viewWithTag:1];
        UIImage* leaveButtonImage = leaveButton.currentImage;
        if (!leaveButtonImage)
        {
            [leaveButton setTitle:NSLocalizedStringWithDefaultValue(@"ViewSettingsGroupsLeaveGroup", @"Dosecast", [DosecastUtil getResourceBundle], @"Leave Group", @"The Leave Group label in the Settings view"]) forState:UIControlStateNormal];
            [DosecastUtil setBackgroundColorForButton:leaveButton color:[DosecastUtil getDeleteButtonColor]];
        }
        
		return leaveButtonCell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
        return 170;
    else // indexPath.section == 1
        return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return headerText;
    else // section == 1
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
        return footerText;
    else // section == 1
        return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    
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
