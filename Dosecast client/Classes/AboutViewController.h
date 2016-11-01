//
//  AboutViewController.h
//  Dosecast
//
//  Created by Jonathan Levene on 4/5/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@class DosecastAPI;
@interface AboutViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                  MFMailComposeViewControllerDelegate>
{
@private
	UITableView* tableView;
	UITableViewCell* productInfoCell;
	UITableViewCell* termsOfServiceCell;
	UITableViewCell* privacyPolicyCell;
	UITableViewCell* feedbackCell;
	UITableViewCell* reportProblemCell;
	UITableViewCell* faqCell;
	UITableViewCell* websiteCell;
	UITableViewCell* whatsNewCell;
	UITableViewCell* writeReviewCell;
	UITableViewCell* tellFriendCell;
	UITableViewCell* facebookCell;
	UITableViewCell* twitterCell;
    NSMutableArray* tableViewSections;
    DosecastAPI* api;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dosecastAPI:(DosecastAPI*)a;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *productInfoCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *termsOfServiceCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *privacyPolicyCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *feedbackCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *reportProblemCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *faqCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *websiteCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *whatsNewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *writeReviewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *tellFriendCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *facebookCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *twitterCell;

@end
