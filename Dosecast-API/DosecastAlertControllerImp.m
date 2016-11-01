//
//  DosecastAlertControllerImp.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import "DosecastAlertControllerImp.h"
#import "DosecastUtil.h"
#import "DosecastAlertAction.h"

static NSMutableArray *gAlerts = nil;

@implementation DosecastAlertControllerImp

@synthesize title;
@synthesize message;
@synthesize style;

- (id)initWithTitle:(NSString*)t
            message:(NSString*)m
              style:(DosecastAlertControllerStyle)s
{
    if ((self = [super init]))
    {
        title = t;
        message = m;
        style = s;
        otherActions = [[NSMutableArray alloc] init];
        cancelAction = nil;
        destructiveAction = nil;
    }
    return self;
}

+ (NSMutableArray*) getAlerts
{
    @synchronized(self)
    {
        if (!gAlerts)
            gAlerts = [[NSMutableArray alloc] init];
    }
    
    return(gAlerts);
}

- (void) addAction:(DosecastAlertAction*)action
{
    if (action)
    {
        if (action.style == DosecastAlertActionStyleCancel && !cancelAction)
            cancelAction = action;
        else if (action.style == DosecastAlertActionStyleDestructive && !destructiveAction)
            destructiveAction = action;
        else
            [otherActions addObject:action];
    }
}

- (NSArray*) actions
{
    NSMutableArray* allActions = [[NSMutableArray alloc] init];
    if (cancelAction)
        [allActions addObject:cancelAction];
    if (destructiveAction)
        [allActions addObject:destructiveAction];
    [allActions addObjectsFromArray:otherActions];
    
    return allActions;
}

- (void) showInViewController:(UIViewController*)viewController
                   sourceView:(UIView*)sourceView
          sourceBarButtonItem:(UIBarButtonItem*)sourceBarButtonItem
{
    [[DosecastAlertControllerImp getAlerts] addObject:self];
    
    if ([DosecastUtil getOSVersionFloat] >= 8.0f)
    {
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:(UIAlertControllerStyle)style];
        NSArray* allActions = self.actions;
        for (DosecastAlertAction* action in allActions)
        {
            UIAlertAction* alertAction = [UIAlertAction actionWithTitle:action.title
                                                                  style:(UIAlertActionStyle)action.style
                                                                handler:^(UIAlertAction *UIAction){
                                                                    if (action.handler)
                                                                        action.handler(action);
                                                                    [[DosecastAlertControllerImp getAlerts] removeObjectIdenticalTo:self];
                                                                }];
            [alertController addAction:alertAction];
        }
        
        if ([DosecastUtil isIPad] && alertController.popoverPresentationController)
        {
            if (sourceView)
            {
                alertController.popoverPresentationController.sourceView = sourceView;
                alertController.popoverPresentationController.sourceRect = sourceView.bounds;
            }
            else if (sourceBarButtonItem)
                alertController.popoverPresentationController.barButtonItem = sourceBarButtonItem;
        }
        
        // Make sure this alert gets displayed over everything else
        if (viewController.navigationController)
        {
            if (viewController != viewController.navigationController.visibleViewController)
                viewController = viewController.navigationController.visibleViewController;
        }
        
        [viewController presentViewController:alertController animated:YES completion:nil];
    }
    else
    {
        if (style == DosecastAlertControllerStyleActionSheet)
        {
            UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                                     delegate:self
                                                            cancelButtonTitle:nil
                                                       destructiveButtonTitle:nil
                                                            otherButtonTitles:nil];
            
            for (DosecastAlertAction* action in otherActions)
            {
                [actionSheet addButtonWithTitle:action.title];
            }
            
            if (destructiveAction)
            {
                actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle:destructiveAction.title];
            }
            else
                actionSheet.destructiveButtonIndex = -1;
            
            if (cancelAction)
            {
                actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:cancelAction.title];
            }
            else
                actionSheet.cancelButtonIndex = -1;
            
            if (![DosecastUtil isIPad] && viewController.navigationController && !viewController.navigationController.toolbarHidden)
                [actionSheet showFromToolbar:viewController.navigationController.toolbar];
            else if (![DosecastUtil isIPad] && viewController.tabBarController)
                [actionSheet showFromTabBar:viewController.tabBarController.tabBar];
            else
                [actionSheet showInView:[viewController view]];
        }
        else // DosecastAlertControllerStyleAlert
        {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title
                                                                message:message
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:nil];
            
            if (cancelAction)
            {
                alertView.cancelButtonIndex = [alertView addButtonWithTitle:cancelAction.title];
            }
            else
                alertView.cancelButtonIndex = -1;
            
            if (destructiveAction)
            {
                [alertView addButtonWithTitle:destructiveAction.title];
            }
            
            for (DosecastAlertAction* action in otherActions)
            {
                [alertView addButtonWithTitle:action.title];
            }
            
            [alertView show];
        }
    }
}

- (void) showInViewController:(UIViewController*)viewController sourceView:(UIView*)sourceView
{
    [self showInViewController:viewController sourceView:sourceView sourceBarButtonItem:nil];
}

- (void) showInViewController:(UIViewController*)viewController sourceBarButtonItem:(UIBarButtonItem*)sourceBarButtonItem
{
    [self showInViewController:viewController sourceView:nil sourceBarButtonItem:sourceBarButtonItem];
}

- (void) showInViewController:(UIViewController*)viewController
{
    [self showInViewController:viewController sourceView:nil sourceBarButtonItem:nil];
}

- (DosecastAlertAction*) findActionWithTitle:(NSString*)thisTitle
{
    NSArray* allActions = self.actions;

    for (DosecastAlertAction* action in allActions)
    {
        if ([action.title isEqualToString:thisTitle])
            return action;
    }
    return nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* titleClicked = [alertView buttonTitleAtIndex:buttonIndex];
    DosecastAlertAction* actionClicked = [self findActionWithTitle:titleClicked];
    if (actionClicked)
    {
        if (actionClicked.handler)
            actionClicked.handler(actionClicked);
        alertView.delegate = nil;
        [[DosecastAlertControllerImp getAlerts] removeObjectIdenticalTo:self];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* titleClicked = [actionSheet buttonTitleAtIndex:buttonIndex];
    DosecastAlertAction* actionClicked = [self findActionWithTitle:titleClicked];
    if (actionClicked)
    {
        if (actionClicked.handler)
            actionClicked.handler(actionClicked);
        actionSheet.delegate = nil;
        [[DosecastAlertControllerImp getAlerts] removeObjectIdenticalTo:self];
    }
}

@end


@implementation DosecastAlertController

// Factory method for general use
+ (DosecastAlertController*)alertControllerWithTitle:(NSString*)title
                                             message:(NSString*)message
                                               style:(DosecastAlertControllerStyle)style
{
    return [[DosecastAlertControllerImp alloc] initWithTitle:title message:message style:style];
}

// Factory method for specific case of a simple confirmation (OK) alert. Will automatically add a single 'OK' cancel action with no handler.
+ (DosecastAlertController*)simpleConfirmationAlertWithTitle:(NSString*)title
                                                     message:(NSString*)message
{
    DosecastAlertController* alert = [[DosecastAlertControllerImp alloc] initWithTitle:title message:message style:DosecastAlertControllerStyleAlert];
    [alert addAction:
     [DosecastAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"AlertButtonOK", @"Dosecast", [DosecastUtil getResourceBundle], @"OK", @"The text on the OK button in an alert"])
                                    style:DosecastAlertActionStyleCancel
                                  handler:nil]];
    return alert;
}

- (void) addAction:(DosecastAlertAction *)action
{
}

- (void) showInViewController:(UIViewController*)viewController sourceView:(UIView*)sourceView
{
    
}

- (void) showInViewController:(UIViewController*)viewController sourceBarButtonItem:(UIBarButtonItem*)sourceBarButtonItem
{
    
}

- (void) showInViewController:(UIViewController*)viewController
{
}

@end
