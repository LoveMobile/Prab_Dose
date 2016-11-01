//
//  DrugDosageUnitManagerEntry.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 10/17/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DrugDosageUnitManagerEntry : NSObject {
@private
    NSString* stringTableName;
    BOOL canPluralize;
}

- (id)init:(NSString*)stringName canPluralize:(BOOL)pluralize;

@property (nonatomic, strong) NSString* stringTableName;
@property (nonatomic, assign) BOOL canPluralize;

@end
