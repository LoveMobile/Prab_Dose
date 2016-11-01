//
//  main.m
//  CompareLocalizationStrings
//
//  Created by Jonathan Levene on 1/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* getFileContents(const char* fileNameC)
{
    NSString* fileName = [[NSString stringWithCString:fileNameC encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDirectory])
    {
        fprintf(stdout, "Couldn't find the file at %s\n", [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        return nil;                
    }
    else if (isDirectory)
    {
        fprintf(stdout, "The file at %s is a directory\n", [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        return nil;                        
    }
        
    NSError* error = nil;
        
    NSString* fileContents = [NSString stringWithContentsOfFile:fileName encoding:NSUTF16StringEncoding error:&error];
    if (error)
    {
        fprintf(stdout, "Error reading the file at %s: %s\n", [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]], [[error localizedDescription] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        return nil;                
    }
    else
        return fileContents;
}

NSInteger stringCompare(NSString* s1, NSString* s2, void *context)
{
    return [s1 compare:s2 options:NSLiteralSearch];
}

int main (int argc, const char * argv[])
{

    @autoreleasepool {

        fprintf(stdout, "\n");

        if (argc < 3)
        {
            fprintf(stdout, "Usage:\nCompareLocalizationStrings <path to strings file 1> <path to strings file 2>\n");
            fprintf(stdout, "\n");
            return 0;
        }
        else
        {
            NSString* fileContents1 = getFileContents(argv[1]);
            if (!fileContents1)
            {
                fprintf(stdout, "\n");
                return 0;
            }
            
            NSDictionary* dict1 = [fileContents1 propertyListFromStringsFileFormat];
            
            NSString* fileContents2 = getFileContents(argv[2]);
            if (!fileContents2)
            {
                fprintf(stdout, "\n");
                return 0;
            }

            NSDictionary* dict2 = [fileContents2 propertyListFromStringsFileFormat];
            
            NSMutableArray* keys2 = [NSMutableArray arrayWithArray:[dict2 allKeys]];
            [keys2 sortUsingFunction:stringCompare context:NULL];
            
            for (NSString* key in keys2)
            {
                NSString* value1 = [dict1 objectForKey:key];
                if (!value1)
                {
                    fprintf(stdout, "%s missing in first file\n", [key cStringUsingEncoding:[NSString defaultCStringEncoding]]);
                }
            }

            NSMutableArray* keys1 = [NSMutableArray arrayWithArray:[dict1 allKeys]];
            [keys1 sortUsingFunction:stringCompare context:NULL];
            
            for (NSString* key in keys1)
            {
                NSString* value1 = [dict1 objectForKey:key];
                NSString* value2 = [dict2 objectForKey:key];
                if (value2)
                {
                    NSUInteger stringRefs1 = [[value1 componentsSeparatedByString:@"%"] count];
                    NSUInteger stringRefs2 = [[value2 componentsSeparatedByString:@"%"] count];
                    
                    if (stringRefs1 != stringRefs2)
                        fprintf(stdout, "%s string references differ between files\n", [key cStringUsingEncoding:[NSString defaultCStringEncoding]]);
                }
                else
                {
                    fprintf(stdout, "%s missing in second file\n", [key cStringUsingEncoding:[NSString defaultCStringEncoding]]);
                }
            }
            
            fprintf(stdout, "\n");
        }
    }
    return 0;
}

