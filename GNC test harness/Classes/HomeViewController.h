//
//  HomeViewController.h
//  Sephora
//
//  Created by Dan Gilliam on 7/1/10.
//  Copyright Branding Brand, LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DosecastAPIDelegate.h"
#import "HomeViewControllerDelegate.h"

@class GNCDosecastAPI;
@class SpinnerViewController;
@class ProgressViewController;

@interface HomeViewController : UIViewController<DosecastAPIDelegate, UIAlertViewDelegate>
{
    SpinnerViewController* _spinnerViewController;
    ProgressViewController* _progressViewController;
    BOOL _dosecastUIInitialized;
    BOOL _isRegisteringDosecastUser;
    BOOL _isDisplayingSpinner;
    BOOL _isDisplayingProgress;
}

- (void) registerDosecastUser;

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) GNCDosecastAPI* dosecastAPI;
@property (nonatomic, weak) NSObject<HomeViewControllerDelegate>* delegate;

- (IBAction)openDosecast:(id)sender;

@end
