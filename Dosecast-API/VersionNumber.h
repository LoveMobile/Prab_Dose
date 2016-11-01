//
//  VersionNumber.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 7/24/14.
//  Copyright (c) 2014 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VersionNumber : NSObject<NSCopying>
{
@private
    int major;
    int minor;
    int maintenance;
}

- (id) init:(int)maj
      minor:(int)min
maintenance:(int)maint;

- (id) initWithVersionString:(NSString*)versionString;

+ (id) versionNumberWithVersionString:(NSString*)versionString;

// Returns whether this version is lower, equal, or higher than the given version
- (NSComparisonResult) compare:(VersionNumber*)anotherVersion;
- (NSComparisonResult) compareWithVersionString:(NSString*)anotherVersionString;

@property (nonatomic, readonly) int major;
@property (nonatomic, readonly) int minor;
@property (nonatomic, readonly) int maintenance;
@property (nonatomic, readonly) NSString* versionString;

@end
