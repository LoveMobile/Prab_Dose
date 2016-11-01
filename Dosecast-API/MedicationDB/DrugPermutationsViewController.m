//
//  DrugPermutationsViewController.m
//  Dosecast-API
//
//  Created by David Sklenar on 9/10/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DrugPermutationsViewController.h"
#import "DosecastUtil.h"
#import "Medication.h"
#import "PermutationSearchResult.h"

@implementation DrugPermutationsViewController


#pragma mark - Properties

@synthesize permutationCell;// = _permutationCell;
@synthesize drugPermutations = _drugPermutations;
@synthesize selectedPermutationIndexPath = _selectedPermutationIndexPath;
@synthesize delegate = _delegate;

#pragma mark - Private API

- (void)handleCancel:(id)sender
{	    
	[self.navigationController popViewControllerAnimated:YES];			
}

- (void)handleDone:(id)sender
{
    if ( [self.delegate respondsToSelector:@selector(didSelectDrugPermutation:resultMatch:)] )
    {
        PermutationSearchResult *permutation = [self.drugPermutations objectAtIndex:self.selectedPermutationIndexPath.row];
        [self.delegate didSelectDrugPermutation:permutation.medication resultMatch:permutation.matchType];
    }    
}

#pragma mark - View lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
          medications:(NSArray *)arrayMedications
             delegate:(id <DrugPermutationsDelegate>)delegate
{
	if ( (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) ) 
    {
        _drugPermutations = [[NSArray alloc] initWithArray:arrayMedications];
        _delegate = delegate;
	}
	return self;
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
    
    self.title = NSLocalizedStringWithDefaultValue(@"ViewDrugEditDrugName", @"Dosecast", [DosecastUtil getResourceBundle], @"Drug Name", @"The Drug Name label in the Drug Edit view"]);

    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the cancel button in the navigation bar.
    
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	
    // Set the done button in the navigation bar.
    
	NSString *doneButtonText = NSLocalizedStringWithDefaultValue( @"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"] );
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
	self.navigationItem.rightBarButtonItem = doneButton;
    doneButton.enabled = NO;
    
    self.selectedPermutationIndexPath = nil;

    [self.tableView reloadData];
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.drugPermutations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"PermutationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        
    if ( cell == nil ) 
    {        
        [[DosecastUtil getResourceBundle] loadNibNamed:@"DrugPermutationCell" owner:self options:nil];

        cell = permutationCell;
        permutationCell = nil;
        
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    
    PermutationSearchResult *permutationResult=(PermutationSearchResult *)[self.drugPermutations objectAtIndex:indexPath.row];
    
    Medication *medication = permutationResult.medication;
    
    if(permutationResult.matchType == MedicationResultMatchBrandName)
    {
        [(UILabel *)[cell.contentView viewWithTag:100] setText:medication.brandName];
    }else{
        [(UILabel *)[cell.contentView viewWithTag:100] setText:medication.genericName];
    }

    
    // Build the drug info line by checking for the existance of each value.
    NSMutableString *drugInfoString=[NSMutableString stringWithString:@""];
    if(medication.unit && [medication.unit length] > 0)
    {
        if ([drugInfoString length] > 0)
            [drugInfoString appendString:@", "];
        [drugInfoString appendString:medication.unit];
    }
    if(medication.strength && [medication.strength length] > 0)
    {
        if ([drugInfoString length] > 0)
            [drugInfoString appendString:@", "];
        [drugInfoString appendString:medication.strength];
    }
    if(medication.medFormType && [medication.medFormType length] > 0)
    {
        if ([drugInfoString length] > 0)
            [drugInfoString appendString:@", "];
        [drugInfoString appendString:medication.medFormType];
    }
    if(medication.route && [medication.route length] > 0)
    {
        if ([drugInfoString length] > 0)
            [drugInfoString appendString:@", "];
        [drugInfoString appendString:medication.route];
    }

    [(UILabel *)[cell.contentView viewWithTag:101] setText:drugInfoString];

    return cell;
}


#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 58.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    // Manage checkmark selection and update Done button accordingly.
    
    if ( self.selectedPermutationIndexPath && [indexPath compare:self.selectedPermutationIndexPath] == NSOrderedSame )
    {
        [(UITableViewCell *)[tableView cellForRowAtIndexPath:self.selectedPermutationIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
        self.selectedPermutationIndexPath = nil;
    }
    else
    {
        [(UITableViewCell *)[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
        
        if ( self.selectedPermutationIndexPath ) 
            [(UITableViewCell *)[tableView cellForRowAtIndexPath:self.selectedPermutationIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
            
        self.selectedPermutationIndexPath = indexPath;
    }
    
    self.navigationItem.rightBarButtonItem.enabled = ( self.selectedPermutationIndexPath != nil );
}

@end
