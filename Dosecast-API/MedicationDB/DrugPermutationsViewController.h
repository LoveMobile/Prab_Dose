//
//  DrugPermutationsViewController.h
//  Dosecast-API
//
//  Created by David Sklenar on 9/10/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

/*
 * View controller to display and manage selection of drug permutations
 * found from searching the database.
 */

#import <UIKit/UIKit.h>
#import "MedicationConstants.h"

@protocol DrugPermutationsDelegate;
@class Medication;

@interface DrugPermutationsViewController : UITableViewController
{
    UITableViewCell *permutationCell;
}

@property (nonatomic, strong) IBOutlet UITableViewCell *permutationCell;

@property (nonatomic, strong) NSArray *drugPermutations;
@property (nonatomic, strong) NSIndexPath *selectedPermutationIndexPath;
@property (nonatomic, weak) id <DrugPermutationsDelegate> delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
          medications:(NSArray *)arrayMedications
             delegate:(id <DrugPermutationsDelegate>)delegate;

@end


/*
 * Delegate to return the selected Medication object.
 */

@protocol DrugPermutationsDelegate <NSObject>
@optional
- (void)didSelectDrugPermutation:(Medication *)permutation resultMatch:(MedicationResultMatch)resultMatch;

@end


