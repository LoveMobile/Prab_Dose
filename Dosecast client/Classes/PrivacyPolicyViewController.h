//
//  PrivacyPolicyViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/10/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DosecastAPI;
@interface PrivacyPolicyViewController : UIViewController {
@private
    DosecastAPI* api;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dosecastAPI:(DosecastAPI*)a;

@end
