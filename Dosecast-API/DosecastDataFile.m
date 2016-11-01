//
//  DosecastDataFile.m
//  Dosecast-API
//
//  Created by Jonathan Levene on 9/10/11.
//  Copyright (c) 2011 Montuno Software, LLC. All rights reserved.
//

#import "DosecastDataFile.h"
#import "HistoryManager.h"
#import "DosecastUtil.h"

@implementation DosecastDataFile

@synthesize fileUrl;

- (id)init
{
    return [self initWithURL:nil];		
}

- (id)initWithURL:(NSURL *)file
{
	if ((self = [super init]))
    {
        fileUrl = file;
	}
	
    return self;		
}

// Reads persistent part of data model from file. Returns whether successful. If so, returns the read dictionary. If not, returns an error message if possible.
- (BOOL)readFromFile:(NSMutableDictionary**)dict
        errorMessage:(NSString**)errorMessage
{        
    if (dict)
        *dict = nil;
    
	if (errorMessage)
		*errorMessage = nil;
	
    if (!fileUrl || ![fileUrl isFileURL] || !dict)
        return NO;
    
    DebugLog(@"readFromFile start");
	
	// See if file exists
	if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path] == YES)
	{		
		// Read XML from file 
		NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:fileUrl.path];
		
        if (!plistXML)
        {
            if (errorMessage)
                *errorMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorFileReadFailed", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not open the %@ data file.", @"The error message returned if the data file can't be read from."]), [DosecastUtil getProductAppName]];
            
			DebugLog(@"readFromFile end: XML error");
            
			return NO;
        }
        
		// Generate mutable dictionary from XML
        NSString *error = nil;
		NSPropertyListFormat format;
        *dict = (NSMutableDictionary *)[NSPropertyListSerialization
                                        propertyListFromData:plistXML
                                        mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                        format:&format
                                        errorDescription:&error];
        
		if (!(*dict) || error)
		{
            if (errorMessage)
            {
                NSMutableString* errorText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorFileReadFailed", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not open the %@ data file.", @"The error message returned if the data file can't be read from."]), [DosecastUtil getProductAppName]];
                if (error)
                    [errorText appendFormat:@" %@", error];
                *errorMessage = errorText;
            }
            
			DebugLog(@"readFromFile end: error%@", (error ? [NSString stringWithFormat:@" (%@)", error] : @""));
            
			return NO;
		}
		
		DebugLog(@"readFromFile end");
        
		return YES;
	}
	else
	{
		DebugLog(@"readFromFile end: no file exists");
        
		return NO;
	}
}

// Writes the given dictionary to the file at the URL. Returns whether successful. If not, returns an error message if possible.
- (BOOL)writeToFile:(NSMutableDictionary*)dict
       errorMessage:(NSString**)errorMessage
{
	if (errorMessage)
		*errorMessage = nil;
	
    if (!fileUrl || ![fileUrl isFileURL] || !dict)
        return NO;

	DebugLog(@"writeToFile start");
    
	if (errorMessage)
		*errorMessage = nil;
			
	// Generate XML from dictionary
	NSString *serializationError = nil;
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:dict
																   format:NSPropertyListXMLFormat_v1_0
														 errorDescription:&serializationError];
	if (!plistData || serializationError)
	{
		if (errorMessage)
		{
			NSMutableString* errorText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorFileWriteFailed", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not save changes to the %@ data file.", @"The error message returned if the data file can't be written to."]), [DosecastUtil getProductAppName]];
			if (serializationError)
				[errorText appendFormat:@" %@", serializationError];
			*errorMessage = errorText;
		}
		
		DebugLog(@"writeToFile end: error%@", (serializationError ? [NSString stringWithFormat:@" (%@)", serializationError] : @""));
        
		return NO;
	}
    
	// Write to file
	NSError* writeError = nil;
	if([plistData writeToFile:fileUrl.path options:(NSAtomicWrite | NSDataWritingFileProtectionNone) error:&writeError])
	{
		DebugLog(@"writeToFile end");
		return YES;
	}
	else
	{
		if (errorMessage)
		{
			NSMutableString* errorText = [NSMutableString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ErrorFileWriteFailed", @"Dosecast", [DosecastUtil getResourceBundle], @"Could not save changes to the %@ data file.", @"The error message returned if the data file can't be written to."]), [DosecastUtil getProductAppName]];
			if (writeError)
				[errorText appendFormat:@" %@", [writeError localizedDescription]];
			*errorMessage = errorText;			
		}
		
		DebugLog(@"writeToFile end: error%@", (writeError ? [NSString stringWithFormat:@" (%@)", [writeError localizedDescription]] : @""));
        
		return NO;
	}		    
}


@end
