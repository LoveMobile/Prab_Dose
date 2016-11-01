//
//  DebugLogEvent.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 12/30/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface DebugLogEvent :  NSManagedObject  
{
}

@property (nonatomic, strong) NSString * apiVersion;
@property (nonatomic, strong) NSDate * creationDate;
@property (nonatomic, strong) NSString * eventDescription;
@property (nonatomic, strong) NSString * file;
@property (nonatomic, strong) NSNumber* line;

@end



