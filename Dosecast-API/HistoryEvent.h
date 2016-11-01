//
//  HistoryEvent.h
//  Dosecast
//
//  Created by Jonathan Levene on 8/1/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <CoreData/CoreData.h>

typedef enum {
	HistoryEventServerStatusSynched = 0,
	HistoryEventServerStatusSynching = 1,
    HistoryEventServerStatusNew = 2
} HistoryEventServerStatus;

@interface HistoryEvent :  NSManagedObject  
{
}

@property (nonatomic, strong) NSString * drugId;
@property (nonatomic, strong) NSString * operation;
@property (nonatomic, strong) NSDate * creationDate;
@property (nonatomic, strong) NSString * operationData;
@property (nonatomic, strong) NSString * eventDescription; // legacy
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSNumber * serverStatus;
@property (nonatomic, strong) NSDate * scheduleDate;
@property (nonatomic, strong) NSString * dosageType;
@property (nonatomic, strong) NSString * dosageTypePrefKey1;
@property (nonatomic, strong) NSString * dosageTypePrefValue1;
@property (nonatomic, strong) NSString * dosageTypePrefKey2;
@property (nonatomic, strong) NSString * dosageTypePrefValue2;
@property (nonatomic, strong) NSString * dosageTypePrefKey3;
@property (nonatomic, strong) NSString * dosageTypePrefValue3;
@property (nonatomic, strong) NSString * dosageTypePrefKey4;
@property (nonatomic, strong) NSString * dosageTypePrefValue4;
@property (nonatomic, strong) NSString * dosageTypePrefKey5;
@property (nonatomic, strong) NSString * dosageTypePrefValue5;

@end



