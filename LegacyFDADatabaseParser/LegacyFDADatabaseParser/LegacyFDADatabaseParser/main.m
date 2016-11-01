//
//  main.m
//  LegacyFDADatabaseParser
//
//  Created by Jonathan Levene on 11/13/14.
//  Copyright (c) 2014 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* getFileContents(NSString* fileName)
{
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
    
    NSString* fileContents = [NSString stringWithContentsOfFile:fileName encoding:[NSString defaultCStringEncoding] error:&error];
    if (error)
    {
        fprintf(stdout, "Error reading the file at %s: %s\n", [fileName cStringUsingEncoding:[NSString defaultCStringEncoding]], [[error localizedDescription] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        return nil;
    }
    else
        return fileContents;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        fprintf(stdout, "\n");
        
        if (argc < 3)
        {
            fprintf(stdout, "Usage:\nLegacyFDADatabaseParser <path to FDA's legacy NDC database files> <path to output .txt file>\n");
            fprintf(stdout, "Example: ./LegacyFDADatabaseParser . .\n");
            fprintf(stdout, "\n");
            return 0;
        }

        // Read listings
        NSString* listingsContents = getFileContents([[[NSString stringWithCString:argv[1] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath] stringByAppendingString:@"/listings.TXT"]);
        if (!listingsContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }

        __weak NSMutableDictionary* listingsMapping = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        [listingsContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            __weak NSMutableDictionary* entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
            
            NSString* ndcSegmentA = [[[line substringWithRange:NSMakeRange(8, 6)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] stringByReplacingOccurrencesOfString:@"*" withString:@""];
            NSString* ndcSegmentB = [[[line substringWithRange:NSMakeRange(15, 4)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] stringByReplacingOccurrencesOfString:@"*" withString:@""];
            [entry setObject:[NSString stringWithFormat:@"%@-%@", ndcSegmentA, ndcSegmentB] forKey:@"PRODUCTNDC"];
            
            [entry setObject:[[line substringWithRange:NSMakeRange(20, 10)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"ACTIVE_NUMERATOR_STRENGTH"];
            [entry setObject:[[line substringWithRange:NSMakeRange(31, 10)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"ACTIVE_INGRED_UNIT"];

            NSString* rxOrOTC = [[line substringWithRange:NSMakeRange(42, 1)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([rxOrOTC isEqualToString:@"R"])
                [entry setObject:@"HUMAN PRESCRIPTION DRUG" forKey:@"PRODUCTTYPENAME"];
            else if ([rxOrOTC isEqualToString:@"O"])
                [entry setObject:@"HUMAN OTC DRUG" forKey:@"PRODUCTTYPENAME"];
            else
                [entry setObject:@"OTHER" forKey:@"PRODUCTTYPENAME"];
            
            [entry setObject:[[line substringWithRange:NSMakeRange(44, 100)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"PROPRIETARYNAME"];
            [entry setObject:@"" forKey:@"NONPROPRIETARYNAME"];
            [entry setObject:@"" forKey:@"DOSAGEFORMNAME"];
            [entry setObject:@"" forKey:@"ROUTENAME"];

            NSNumber* LISTING_SEQ_NO = [NSNumber numberWithInt:
                                        [[[line substringWithRange:NSMakeRange(0, 7)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue]];
            [listingsMapping setObject:entry forKey:LISTING_SEQ_NO];

        }];

        // Read listings
        NSString* formulationContents = getFileContents([[[NSString stringWithCString:argv[1] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath] stringByAppendingString:@"/FORMULAT.TXT"]);
        if (!formulationContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }

        __weak NSMutableDictionary* formulationsMapping = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];

        [formulationContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            
            NSNumber* LISTING_SEQ_NO = [NSNumber numberWithInt:
                                        [[[line substringWithRange:NSMakeRange(0, 7)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue]];

            
            __weak NSMutableDictionary* entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
            
            [entry setObject:[[line substringWithRange:NSMakeRange(8, 10)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"ACTIVE_NUMERATOR_STRENGTH"];
            [entry setObject:[[line substringWithRange:NSMakeRange(19, 5)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"ACTIVE_INGRED_UNIT"];
            
            [entry setObject:[[line substringWithRange:NSMakeRange(25, 100)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"INGREDIENT_NAME"];
            
            NSMutableArray* array = [formulationsMapping objectForKey:LISTING_SEQ_NO];
            if (!array)
                array = [NSMutableArray arrayWithObjects:nil];
            [array addObject:entry];
            [formulationsMapping setObject:array forKey:LISTING_SEQ_NO];
        }];
    
        NSArray* allKeys = [formulationsMapping allKeys];
        for (NSNumber* LISTING_SEQ_NO in allKeys)
        {
            NSArray* array = [formulationsMapping objectForKey:LISTING_SEQ_NO];
            NSMutableSet* ingredients = [NSMutableSet setWithObjects:nil];
            for (NSMutableDictionary* formulation in array)
            {
                [ingredients addObject:[[formulation objectForKey:@"INGREDIENT_NAME"] capitalizedString]];
            }
            
            NSMutableString* genericName = [NSMutableString stringWithString:@""];
            NSUInteger numIngred = [ingredients count];
            int i = 0;
            for (NSString* ingredient in ingredients)
            {
                if ([genericName length] > 0)
                {
                    if (i == numIngred-1)
                        [genericName appendString:@" and "];
                    else
                        [genericName appendString:@", "];
                }
                [genericName appendString:ingredient];
                i++;
            }
            
            NSMutableDictionary* entry = [listingsMapping objectForKey:LISTING_SEQ_NO];
            if (entry){
                [entry setObject:genericName forKey:@"NONPROPRIETARYNAME"];
                [listingsMapping setObject:entry forKey:LISTING_SEQ_NO];
            }
        }
        
        // Read listings
        NSString* routesContents = getFileContents([[[NSString stringWithCString:argv[1] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath] stringByAppendingString:@"/ROUTES.TXT"]);
        if (!routesContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }

        [routesContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            
            NSNumber* LISTING_SEQ_NO = [NSNumber numberWithInt:
                                        [[[line substringWithRange:NSMakeRange(0, 7)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue]];
            
            
            NSString* route = [[line substringWithRange:NSMakeRange(12, 240)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

            NSMutableDictionary* entry = [listingsMapping objectForKey:LISTING_SEQ_NO];
            if (entry)
            {
                [entry setObject:route forKey:@"ROUTENAME"];
                [listingsMapping setObject:entry forKey:LISTING_SEQ_NO];
            }

        }];

        // Read listings
        NSString* formContents = getFileContents([[[NSString stringWithCString:argv[1] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath] stringByAppendingString:@"/DOSEFORM.TXT"]);
        if (!formContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }
        
        [formContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            
            NSNumber* LISTING_SEQ_NO = [NSNumber numberWithInt:
                                        [[[line substringWithRange:NSMakeRange(0, 7)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue]];
            
            
            NSString* form = [[line substringWithRange:NSMakeRange(12, 240)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            NSMutableDictionary* entry = [listingsMapping objectForKey:LISTING_SEQ_NO];
            if (entry)
            {
                if ([[entry objectForKey:@"DOSAGEFORMNAME"] length] == 0)
                    [entry setObject:form forKey:@"DOSAGEFORMNAME"];
                [listingsMapping setObject:entry forKey:LISTING_SEQ_NO];
            }
            
        }];

        
        // Output MedDoseUnit
        NSMutableString* outputFile = [NSMutableString stringWithString:@""];
        [outputFile appendString:@"PRODUCTNDC\tPRODUCTTYPENAME\tPROPRIETARYNAME\tNONPROPRIETARYNAME\tDOSAGEFORMNAME\tROUTENAME\tACTIVE_NUMERATOR_STRENGTH\tACTIVE_INGRED_UNIT\n"];
        for (NSString* key in [listingsMapping allKeys])
        {
            NSMutableDictionary* listing = [listingsMapping objectForKey:key];
            
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"PRODUCTNDC"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"PRODUCTTYPENAME"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"PROPRIETARYNAME"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"NONPROPRIETARYNAME"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"DOSAGEFORMNAME"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"ROUTENAME"]];
            [outputFile appendFormat:@"%@\t", [listing objectForKey:@"ACTIVE_NUMERATOR_STRENGTH"]];
            [outputFile appendFormat:@"%@\n", [listing objectForKey:@"ACTIVE_INGRED_UNIT"]];
        }
        [outputFile writeToFile:[[[NSString stringWithCString:argv[2] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath] stringByAppendingString:@"/legacyproduct.txt"] atomically:YES encoding:NSASCIIStringEncoding error:nil];

        
    }
    return 0;
}
