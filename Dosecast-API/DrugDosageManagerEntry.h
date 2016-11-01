//
//  DrugDosageManagerEntry.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DrugDosage.h"

@interface DrugDosageManagerEntry : NSObject {
@private
	Class dosageClass;
}

- (id)initWithClass:(Class)cl;

@property (nonatomic, readonly) Class dosageClass;

@end
