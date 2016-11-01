//
//  MedDoseUnit.h
//  MedsDischargeDBUtil
//
//  Created by Jonathan Levene on 8/3/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MedDoseUnit : NSManagedObject

@property (nonatomic, strong) NSString * medFormType;
@property (nonatomic, strong) NSString * unitDesc;

@end
