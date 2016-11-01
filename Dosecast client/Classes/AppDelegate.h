//
//  AppDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 1/17/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//
#import <CoreData/CoreData.h>
#import "DosecastAPIDelegate.h"
#import "RegistrationViewControllerDelegate.h"
#import <MessageUI/MFMailComposeViewController.h>

@class DosecastAPI;
@class SpinnerViewController;
@class ProgressViewController;
@interface AppDelegate : NSObject <UIApplicationDelegate,
                                   DosecastAPIDelegate,
                                   MFMailComposeViewControllerDelegate,
                                   RegistrationViewControllerDelegate>
{
@private   
    UIWindow *window;
	DosecastAPI* dosecastAPI;
	UIViewController* launchScreenViewController;
    SpinnerViewController* spinnerViewController;
    ProgressViewController* progressViewController;
    UINavigationController* mainNavigationController;
    UINavigationController* registrationNavigationController;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;

@end

