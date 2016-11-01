//
//  DosecastDataFile.h
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/10/11.
//  Copyright (c) 2011 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DosecastDataFile : NSObject
{
@private
    NSURL* fileUrl;
}

- (id)initWithURL:(NSURL*)file;

// Reads from the file at the URL. Returns whether successful. If so, returns the read dictionary. If not, returns an error message if possible.
- (BOOL)readFromFile:(NSMutableDictionary**)dict
        errorMessage:(NSString**)errorMessage;

// Writes the given dictionary to the file at the URL. Returns whether successful. If not, returns an error message if possible.
- (BOOL)writeToFile:(NSMutableDictionary*)dict
       errorMessage:(NSString**)errorMessage;

@property (nonatomic, readonly) NSURL* fileUrl;

@end
