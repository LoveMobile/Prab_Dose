//
//  DrugDatabaseSearchController.m
//  Dosecast
//
//  Created by Jonathan Levene on 8/10/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "DrugDatabaseSearchController.h"
#import "DrugPermutationsViewController.h"
#import "DosecastUtil.h"
#import "MedicationSearchManager.h"
#import "Medication.h"
#import "SpinnerViewController.h"
#import "DrugPermutationsViewController.h"

static const int MIN_CHARACTERS = 3;
static const int SPINNER_SHIFT_VERTICAL_HEIGHT=-108;

@implementation DrugDatabaseSearchController

@synthesize tableView;
@synthesize drugCell;
@synthesize noDrugsFoundCell;
@synthesize searchPromptCell;
@synthesize searchTooShortCell;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil delegate:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
			   bundle:(NSBundle *)nibBundleOrNil
			 delegate:(NSObject<DrugDatabaseSearchControllerDelegate>*)d
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		delegate = d;
        searchResults = [[NSMutableArray alloc] init];
        searchText = [[NSMutableString alloc] initWithString:@""];
        searchScope = [[NSMutableString alloc] initWithString:@""];
        self.hidesBottomBarWhenPushed = YES;

		self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);

        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;

        spinnerController = [[SpinnerViewController alloc] init];
        spinnerController.handleOrientationChange = NO;
        
        // Shift the spinner to appear above the keyboard
        [spinnerController shiftSpinnerPositionVertically:SPINNER_SHIFT_VERTICAL_HEIGHT];
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	tableView.sectionHeaderHeight = 4;
	tableView.sectionFooterHeight = 4;	
	    
    // Set search bar scope titles
    UISearchBar* searchBar = self.searchDisplayController.searchBar;
    searchBar.scopeButtonTitles = [NSArray arrayWithObjects:NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchButtonAll", @"Dosecast", [DosecastUtil getResourceBundle], @"All", @"The All filter button in the drug database search view"]),
                                                            NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchButtonPrescription", @"Dosecast", [DosecastUtil getResourceBundle], @"Prescription", @"The Prescription filter button in the drug database search view"]),
                                                            NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchButtonOTC", @"Dosecast", [DosecastUtil getResourceBundle], @"OTC", @"The OTC filter button in the drug database search view"]), nil];
    searchBar.selectedScopeButtonIndex = 0;
    searchBar.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    
    UISearchBar* searchBar = self.searchDisplayController.searchBar;
    [searchBar becomeFirstResponder];
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)popSearchController:(NSTimer*)theTimer
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(popSearchController:) userInfo:nil repeats:NO];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)thisTableView numberOfRowsInSection:(NSInteger)section {
    
	if (thisTableView == self.searchDisplayController.searchResultsTableView)
	{
        if ([searchText length] < MIN_CHARACTERS)
            return 1;
        else
        {
            int numResults = (int)[searchResults count];
            if (numResults == 0)
                numResults = 1; // display the no drug found cell
            return numResults;
        }
    }
	else
	{
        return 1;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)thisTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"PillCellIdentifier";
	
	if (thisTableView == self.searchDisplayController.searchResultsTableView)
	{
        if (indexPath.row == 0 && [searchText length] < MIN_CHARACTERS)
        {
            UILabel* header = (UILabel*)[searchTooShortCell viewWithTag:1];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchTooShort", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter at least 3 characters.", @"The header text in the cell displayed when no drugs are found in the drug database search view"]);            
            return searchTooShortCell;
        }
        else if (indexPath.row == 0 && [searchResults count] == 0)
        {
            UILabel* header = (UILabel*)[noDrugsFoundCell viewWithTag:1];
            header.textColor = [DosecastUtil getDrugWarningLabelColor];
            header.text = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchNoDrugsFoundHeader", @"Dosecast", [DosecastUtil getResourceBundle], @"No Drugs Found in Database", @"The header text in the cell displayed when no drugs are found in the drug database search view"]);
            UILabel* message = (UILabel*)[noDrugsFoundCell viewWithTag:2];
            message.textColor = [UIColor blackColor];
            message.text = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchNoDrugsFoundMessage", @"Dosecast", [DosecastUtil getResourceBundle], @"Either revise your search or tap Cancel to enter a custom medication name.", @"The header text in the cell displayed when no drugs are found in the drug database search view"]);

            return noDrugsFoundCell;
        }
        else
        {
            UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MyIdentifier];
            if (cell == nil) {
                [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugDatabaseSearchCell" owner:self options:nil];
                cell = drugCell;
                drugCell = nil;
            }

            UILabel *cellLabel=(UILabel *)[cell viewWithTag:1];
            cellLabel.text = [searchResults objectAtIndex:indexPath.row];
            
            return cell;
        }
    }
	else
	{
        UILabel* label = (UILabel*)[searchPromptCell viewWithTag:1];
        label.text = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchPrompt", @"Dosecast", [DosecastUtil getResourceBundle], @"Enter some text in the search box to begin searching.", @"The prompt text in the cell displayed when no search string has been entered in the drug database search view"]);
        return searchPromptCell;
    }
}

- (CGFloat)tableView:(UITableView *)thisTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (thisTableView == self.searchDisplayController.searchResultsTableView)
    {
        if (indexPath.row == 0 && [searchText length] >= MIN_CHARACTERS && [searchResults count] == 0)
            return 132;
        else
            return 44;
    }
    else
        return 66;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}


- (void)tableView:(UITableView *)thisTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    spinnerController.message = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchLoading", @"Dosecast", [DosecastUtil getResourceBundle], @"Loading...", @"The loading text displayed in the drug database search view"]);
    [spinnerController showOnViewController:self animated:YES];

	[self.tableView deselectRowAtIndexPath:indexPath animated:NO]; // deselect the row
    
	if (thisTableView == self.searchDisplayController.searchResultsTableView)        
    {
        if ( indexPath.row != 0 || ([searchText length] >= MIN_CHARACTERS && [searchResults count] != 0) )
        {
            [[MedicationSearchManager sharedManager] getMedicationsWithMedicationName:[searchResults objectAtIndex:indexPath.row]
                   withMedicationTypeString:searchScope
                  completionBlock:^(NSArray *resultsArray) {
                      DrugPermutationsViewController *permutations = [[DrugPermutationsViewController alloc] initWithNibName:[DosecastUtil getDeviceSpecificNibName:@"DrugPermutationsViewController"]
                                                                                                                      bundle:[DosecastUtil getResourceBundle]
                                                                                                                 medications:resultsArray
                                                                                                                    delegate:self];
                      [spinnerController hide:YES];
                      [self.navigationController pushViewController:permutations animated:YES];
                      
                  }];
        }
    }
            
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods

- (void)filterContentForSearchText:(NSString*)text scope:(NSString*)scope
{
    [searchText setString:text];
    [searchScope setString:scope];
    
    if ([searchText length] < MIN_CHARACTERS){
        [[MedicationSearchManager sharedManager] cancelMedicationNameSearch];
        [searchResults removeAllObjects];
        [self.searchDisplayController.searchResultsTableView reloadData];
        if (spinnerController.visible)
            [spinnerController hide:YES];
        return;
    }

    
    MedicationSearchType searchType;
    if([scope isEqualToString:@"Prescription"]){
        searchType=MedicationSearchTypeRX;
    }else if ([scope isEqualToString:@"OTC"]){
        searchType=MedicationSearchTypeOTC;
    }else{
        searchType=MedicationSearchTypeAll;
    }
    
    spinnerController.message = NSLocalizedStringWithDefaultValue(@"ViewDrugDatabaseSearchSearching", @"Dosecast", [DosecastUtil getResourceBundle], @"Searching...", @"The searching text displayed in the drug database search view"]);
    [spinnerController showOnViewController:self animated:YES];
    
    [[MedicationSearchManager sharedManager] searchForMedicationName:searchText withSearchType:searchType completionBlock:^(NSArray *resultsArray) {
        [searchResults removeAllObjects];
        [searchResults addObjectsFromArray:resultsArray];
        [self.searchDisplayController.searchResultsTableView reloadData];
        [spinnerController hide:YES];
    }];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    // Return YES to cause the search result table view to be reloaded.
    //We are going to return NO because we will reload the table after the search results are updated
    return NO;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    
    // Return YES to cause the search result table view to be reloaded.
    //We are going to return NO because we will reload the table after the search results are updated
    return NO;
}


//This method was added so that any existing searches are automatically cancelled when the searchResultsTableView is hidden
-(void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView{
    [[MedicationSearchManager sharedManager] cancelMedicationNameSearch];
    if (spinnerController.visible)
        [spinnerController hide:YES];
}

# pragma mark - DrugPermutationsDelegate

- (void)didSelectDrugPermutation:(Medication *)permutation resultMatch:(MedicationResultMatch)resultMatch {
    
    if (delegate && [delegate respondsToSelector:@selector(handleDrugDatabaseSearchResult:resultMatch:)])
    {
        [delegate handleDrugDatabaseSearchResult:permutation resultMatch:resultMatch];
    }				
}



@end

