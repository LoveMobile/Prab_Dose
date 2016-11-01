//
//  AppDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//
#import <CoreData/CoreData.h>
#import "DosecastAPIDelegate.h"

#import "VCGeneralDialog.h"
#import "VCActivityIndicator.h"
#import "TouchCapturingWindow.h"
#import "MessageVC.h"

@protocol MobileCareAppDelegateDelegate <NSObject>
- (void)merlinClosed;
@end

@class DosecastAPI;
@class SpinnerViewController;
@class ProgressViewController;
@interface AppDelegate : NSObject <UIApplicationDelegate, UIAlertViewDelegate,
                                   DosecastAPIDelegate,
                                   VCMerlinDelegate,
                                   UITabBarControllerDelegate>
{
@private   
    TouchCapturingWindow *window;
	DosecastAPI* dosecastAPI;
    SpinnerViewController* spinnerViewController;
    ProgressViewController* progressViewController;
    UITabBarController* tabBarController;
    BOOL isInitializingDosecast;
    BOOL isMerlinPerformingActivation;
    BOOL allowSpinnerProgressViewController;
    BOOL needsApplicationDidBecomeActiveCall;
    BOOL shouldAvoidResettingDevice;
    UIAlertView* registrationErrorAlert;
    UIAlertView* signOutConfirmation;
}

@property (strong, nonatomic) TouchCapturingWindow *window;

@property (strong, nonatomic) UITabBarController *tabBarController;

@property (nonatomic, strong) VCGeneralDialog* m_vcMerlin;

@property (nonatomic, strong) VCActivityIndicator* m_ai;

@property (nonatomic, strong) UIColor  *navBarColor;

@property (nonatomic, strong) MessageVC* m_msgVC; 

@property (weak) id<MobileCareAppDelegateDelegate> delegate;

@property (nonatomic, retain) NSMutableArray *alerts;

- (NSString*)getAppEnvironmentAsString;

- (int)getAppEnvironment;

@end

