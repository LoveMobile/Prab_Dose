//
//  WhatsNewViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 5/21/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface WhatsNewViewController : UIViewController {
@private
	UITextView* textView;
}

@property (nonatomic, strong) IBOutlet UITextView* textView;

@end
