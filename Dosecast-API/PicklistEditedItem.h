//
//  PicklistEditedItem.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/11.
//  Copyright 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PicklistEditedItem : NSObject
{
@private
    NSString* value;
    int index;
}

- (id)init:(NSString*)val index:(int)i;

@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) int index;

@end
