//
//  VersionNumber.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/14.
//  Copyright (c) 2014 Montuno Software, LLC. All rights reserved.
//

#import "VersionNumber.h"

@implementation VersionNumber
@synthesize major;
@synthesize minor;
@synthesize maintenance;

- (id) init:(int)maj
      minor:(int)min
maintenance:(int)maint
{
    if ((self = [super init]))
    {
        major = maj;
        minor = min;
        maintenance = maint;
	}
	return self;
}

- (id) initWithVersionString:(NSString*)versionString
{
    NSArray* versionParts = [versionString componentsSeparatedByString:@" "];
    NSArray* versionDigits = [[versionParts objectAtIndex:1] componentsSeparatedByString:@"."];
    if ([versionDigits count] == 1)
    {
        return [self init:[[versionDigits objectAtIndex:0] intValue]
                    minor:0
              maintenance:0];
    }
    else if ([versionDigits count] == 2)
    {
        return [self init:[[versionDigits objectAtIndex:0] intValue]
                    minor:[[versionDigits objectAtIndex:1] intValue]
              maintenance:0];
    }
    else
    {
        return [self init:[[versionDigits objectAtIndex:0] intValue]
                    minor:[[versionDigits objectAtIndex:1] intValue]
              maintenance:[[versionDigits objectAtIndex:2] intValue]];
    }
}

+ (id) versionNumberWithVersionString:(NSString*)versionString
{
    return [[VersionNumber alloc] initWithVersionString:versionString];
}

-(NSUInteger) hash
{
    return [self.versionString hash];
}

// Returns whether this version is lower, equal, or higher than the given version
- (NSComparisonResult) compare:(VersionNumber*)anotherVersion
{
    if (self.major < anotherVersion.major)
        return NSOrderedAscending;
    else if (self.major > anotherVersion.major)
        return NSOrderedDescending;
    else if (self.minor < anotherVersion.minor)
        return NSOrderedAscending;
    else if (self.minor > anotherVersion.minor)
        return NSOrderedDescending;
    else if (self.maintenance < anotherVersion.maintenance)
        return NSOrderedAscending;
    else if (self.maintenance > anotherVersion.maintenance)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (NSComparisonResult) compareWithVersionString:(NSString*)anotherVersionString
{
    return [self compare:[VersionNumber versionNumberWithVersionString:anotherVersionString]];
}

- (NSString*) versionString
{
    return [NSString stringWithFormat:@"Version %d.%d.%d", major, minor, maintenance];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[VersionNumber alloc] init:major
                                 minor:minor
                           maintenance:maintenance];
}

@end
