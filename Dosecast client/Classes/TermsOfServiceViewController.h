//
//  TermsOfServiceViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/27/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DosecastAPI;
@interface TermsOfServiceViewController : UIViewController {
@private
    DosecastAPI* api;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dosecastAPI:(DosecastAPI*)a;

@end
