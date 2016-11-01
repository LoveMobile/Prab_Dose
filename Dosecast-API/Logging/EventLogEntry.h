//
//  EventLogEntry.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 8/28/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface EventLogEntry : NSManagedObject

@property (nonatomic, strong) NSDate * dateAdded;
@property (nonatomic, strong) NSData * entry;
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSDate * lastUploadAttempt;
@property (nonatomic, strong) NSString * lastUploadResponse;

@end
