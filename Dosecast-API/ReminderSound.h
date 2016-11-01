//
//  ReminderSound.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 1/4/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReminderSound : NSObject
{
@private
NSString* filename;
NSString* displayName;
}

- (id) init:(NSString*)soundFilename;

@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) NSString *displayName;

@end
