//
//  ReminderSound.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 1/4/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "ReminderSound.h"
#import "DosecastUtil.h"

@implementation ReminderSound

@synthesize filename;
@synthesize displayName;

- (id) init
{
    return [self init:nil];
}

-(id)init:(NSString*)soundFilename
{
    if ((self = [super init]))
    {
        filename = soundFilename;
        displayName = nil;
        
        if (filename)
        {
            NSString* filenameNoSpaces = [filename stringByReplacingOccurrencesOfString:@" " withString:@""];
            NSString* localizedStringName = [NSString stringWithFormat:@"ReminderSound%@", filenameNoSpaces];
            displayName = [[NSString alloc] initWithString:NSLocalizedStringWithDefaultValue(localizedStringName, @"Dosecast", [DosecastUtil getResourceBundle], filename, @"The localized display name of a reminder sound"])];
        }
	}
	return self;		
}


@end
