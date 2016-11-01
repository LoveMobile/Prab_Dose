//
//  Medication_route.h
//  MedsDischargeDBUtil
//
//  Created by Jonathan Levene on 7/13/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MedicationRoute : NSManagedObject

//@property (nonatomic, retain) NSString * medFormType;
@property (nonatomic, strong) NSString * route;

@end
