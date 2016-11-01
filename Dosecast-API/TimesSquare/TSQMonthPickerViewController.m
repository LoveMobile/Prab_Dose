//
//  TSQMonthPickerViewController.m
//  TimesSquare
//
//  Created by Jim Puls on 12/5/12.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "TSQMonthPickerViewController.h"
#import "TSQMonthPickerViewControllerCalendarRowCell.h"
#import "TimesSquare.h"
#import "DosecastUtil.h"

static const int NUM_YEARS_BACK = 10;
static const int NUM_YEARS_FORWARD = 10;

@interface TSQCalendarView (AccessingPrivateStuff)

@property (nonatomic, readonly) UITableView *tableView;

@end

@implementation TSQMonthPickerViewController

-(id)init:(NSString*)viewTitle
initialDate:(NSDate*)date
displayNever:(BOOL)displayNever
uniqueIdentifier:(int)Id
 delegate:(NSObject<TSQMonthPickerViewControllerDelegate>*)del
{
    if ((self = [super init]))
    {
        delegate = del;
        uniqueIdentifier = Id;
        displayNeverButton = displayNever;
        if (!date)
            date = [NSDate date];
        initialDate = date;

        self.title = viewTitle;
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        
        // Set Cancel button
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        
        // Set Done button
        NSString* doneButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonDone", @"Dosecast", [DosecastUtil getResourceBundle], @"Done", @"The text on the Done toolbar button"]);
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)];
        self.navigationItem.rightBarButtonItem = doneButton;
        
        // Setup toolbar and never button
        if (displayNever)
        {
            UIBarButtonItem *flexSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            NSString* neverButtonText = NSLocalizedStringWithDefaultValue(@"ToolbarButtonNever", @"Dosecast", [DosecastUtil getResourceBundle], @"Never", @"The text on the Never toolbar button"]);
            UIBarButtonItem *neverButton = [[UIBarButtonItem alloc] initWithTitle:neverButtonText style:UIBarButtonItemStyleBordered target:self action:@selector(handleNever:)];
            self.toolbarItems = [NSArray arrayWithObjects:flexSpaceButton, neverButton, nil];
        }
        
        self.hidesBottomBarWhenPushed = !displayNever;
    }
    return self;
}

- (void)loadView;
{
    NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.locale = [NSLocale currentLocale];

    TSQCalendarView *calendarView = [[TSQCalendarView alloc] init];
    calendarView.calendar = calendar;
    calendarView.rowCellClass = [TSQMonthPickerViewControllerCalendarRowCell class];

    calendarView.firstDate = [DosecastUtil addMonthsToDate:[NSDate date] numMonths:-12 * NUM_YEARS_BACK];
    calendarView.lastDate = [DosecastUtil addMonthsToDate:[NSDate date] numMonths:12 * NUM_YEARS_FORWARD];
    calendarView.selectedDate = initialDate;
    calendarView.backgroundColor = [DosecastUtil getViewBackgroundColor];
    calendarView.pagingEnabled = YES;
    CGFloat onePixel = 1.0f / [UIScreen mainScreen].scale;
    calendarView.contentInset = UIEdgeInsetsMake(0.0f, onePixel, 0.0f, onePixel);

    self.view = calendarView;
}

- (void)viewDidLayoutSubviews;
{
    [super viewDidLayoutSubviews];
    
  // Set the calendar view to show today date on start
  [(TSQCalendarView *)self.view scrollToDate:initialDate animated:NO];
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

- (void)handleCancel:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)handleNever:(id)sender
{
    if ([delegate respondsToSelector:@selector(handleSetDateValue:uniqueIdentifier:)])
    {
        [delegate handleSetDateValue:nil uniqueIdentifier:uniqueIdentifier];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)handleDone:(id)sender
{
    BOOL success = YES;
    if ([delegate respondsToSelector:@selector(handleSetDateValue:uniqueIdentifier:)])
    {
        success = [delegate handleSetDateValue:((TSQCalendarView *)self.view).selectedDate uniqueIdentifier:uniqueIdentifier];
    }
    if (success)
        [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationMaskAll;
}

@end
