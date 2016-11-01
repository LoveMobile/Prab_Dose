//
//  DrugAddEditViewControllerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 
#import "DosecastCoreTypes.h"

@protocol DrugAddEditViewControllerDelegate

@required

- (void)handleEditDrugComplete;
- (void)handleDrugDelete;

@optional

- (void)handleEditDrugCancel;

@end
