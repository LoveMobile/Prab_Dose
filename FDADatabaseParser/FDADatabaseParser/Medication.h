//
//  Medication.h
//  MedsDischargeDBUtil
//
//  Created by Jonathan Levene on 7/13/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Medication : NSManagedObject

@property (nonatomic, strong) NSString * brandName;
@property (nonatomic, strong) NSString * genericName;
@property (nonatomic, strong) NSString * medForm;
@property (nonatomic, strong) NSString * medFormType;
@property (nonatomic, strong) NSString * medType;
@property (nonatomic, strong) NSString * ndc;
@property (nonatomic, strong) NSString * route;
@property (nonatomic, strong) NSString * strength;
@property (nonatomic, strong) NSString * unit;

@end
