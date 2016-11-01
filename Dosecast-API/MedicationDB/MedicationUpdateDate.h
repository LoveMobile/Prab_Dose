//
//  Medication_update_date.h
//  MedsDischargeDBUtil
//
//  Created by Jonathan Levene on 7/13/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MedicationUpdateDate : NSManagedObject

@property (nonatomic, strong) NSString * lastUpdateDatetime;

@end
