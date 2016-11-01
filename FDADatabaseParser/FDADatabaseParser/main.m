//
//  main.m
//  FDADatabaseParser
//
//  Created by Jonathan Levene on 10/21/12.
//  Copyright (c) 2012 Jonathan Levene. All rights reserved.
//
#import "Medication.h"
#import "MedFormType.h"
#import "MedicationUpdateDate.h"
#import "MedicationRoute.h"
#import "MedStrengthUnit.h"
#import "MedDoseUnit.h"
#import "MedApplyLocation.h"

static NSManagedObjectModel *managedObjectModel()
{
    static NSManagedObjectModel *model = nil;
    if (model != nil) {
        return model;
    }
    
    NSString *path = @"FDADatabaseParser";
    path = [path stringByDeletingPathExtension];
    NSURL *modelURL = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"momd"]];
    model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    return model;
}

static NSManagedObjectContext *managedObjectContext(NSString* outputPath)
{
    static NSManagedObjectContext *context = nil;
    if (context != nil) {
        return context;
    }

    @autoreleasepool {
        context = [[NSManagedObjectContext alloc] init];
        
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel()];
        [context setPersistentStoreCoordinator:coordinator];
        
        NSString *STORE_TYPE = NSSQLiteStoreType;
        NSDictionary* options = @{ NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"} };
        
        NSString *path = outputPath;
        path = [path stringByDeletingPathExtension];
        NSURL *url = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"sqlite"]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path])
            [[NSFileManager defaultManager] removeItemAtPath:url.path error:nil];

        NSError *error;
        NSPersistentStore *newStore = [coordinator addPersistentStoreWithType:STORE_TYPE configuration:nil URL:url options:options error:&error];
        
        if (newStore == nil) {
            NSLog(@"Store Configuration Failure %@", ([error localizedDescription] != nil) ? [error localizedDescription] : @"Unknown Error");
        }
    }
    return context;
}

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

NSString* getDrugField(NSString* fieldName, NSMutableDictionary* drug)
{
    return [[drug objectForKey:fieldName] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
}

void processRawDrugDict(NSMutableDictionary* drug, NSMutableDictionary* formMapping, NSMutableDictionary** processedDrug, NSString** ndc)
{
    *processedDrug = nil;
    *ndc = nil;
    
    NSMutableString* brandName = [NSMutableString stringWithString:@""];
    [brandName appendString:getDrugField(@"PROPRIETARYNAME", drug)];
    if (getDrugField(@"PROPRIETARYNAMESUFFIX", drug) && [getDrugField(@"PROPRIETARYNAMESUFFIX", drug) length] > 0)
    {
        [brandName appendFormat:@" %@", getDrugField(@"PROPRIETARYNAMESUFFIX", drug)];
    }
    [brandName setString:[[brandName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString]];
    
    NSString* genericName = [[[NSString stringWithString:getDrugField(@"NONPROPRIETARYNAME", drug)]
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                             uppercaseString];
    NSString* thisNDC = [[NSString stringWithString:getDrugField(@"PRODUCTNDC", drug)]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString* rawMedForm = getDrugField(@"DOSAGEFORMNAME", drug);
    NSString* medForm = [[[NSString stringWithString:rawMedForm]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] capitalizedString];
    NSString* medFormTypeResult = [formMapping objectForKey:rawMedForm];
    if (!medFormTypeResult && [rawMedForm length] == 0)
        medFormTypeResult = @"OTHER";
    if (!medFormTypeResult)
    {
        fprintf(stdout, "Couldn't find mapping for dosage form name: %s\n", [rawMedForm cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        return;
    }
    else
    {
        NSString* medFormType = [[medFormTypeResult
                                  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] capitalizedString];
        NSString* medType = [getDrugField(@"PRODUCTTYPENAME", drug)
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([medType caseInsensitiveCompare:@"HUMAN PRESCRIPTION DRUG"] == NSOrderedSame)
            medType = @"Rx";
        else if ([medType caseInsensitiveCompare:@"HUMAN OTC DRUG"] == NSOrderedSame)
            medType = @"OTC";
        NSString* route = [[getDrugField(@"ROUTENAME", drug)
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] capitalizedString];
        NSRange routeSCRange = [route rangeOfString:@";"];
        if (routeSCRange.location != NSNotFound ||
            [route caseInsensitiveCompare:@"Occlusive Dressing Technique"] == NSOrderedSame ||
            [route caseInsensitiveCompare:@"Not Applicable"] == NSOrderedSame)
        {
            route = @"";
        }
        else if ([route caseInsensitiveCompare:@"Auricular (Otic)"] == NSOrderedSame)
        {
            route = @"Auricular";
        }
        else if ([route caseInsensitiveCompare:@"Respiratory (Inhalation)"] == NSOrderedSame)
        {
            route = @"Respiratory";
        }
        
        NSString* strengthRaw = [[getDrugField(@"ACTIVE_NUMERATOR_STRENGTH", drug)
                                 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
        NSString* unitRaw = [[getDrugField(@"ACTIVE_INGRED_UNIT", drug)
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
        NSRange strengthSCRange = [strengthRaw rangeOfString:@";"];
        NSRange unitSCRange = [unitRaw rangeOfString:@";"];
        
        if (strengthSCRange.location != NSNotFound || unitSCRange.location != NSNotFound)
        {
            strengthRaw = @"";
            unitRaw = @"";
        }
        
        NSString* strength = strengthRaw;
        NSString* unit = unitRaw;
        NSRange unitSlashRange = [unitRaw rangeOfString:@"/"];
        if (unitSlashRange.location != NSNotFound)
        {
            NSArray* components = [unitRaw componentsSeparatedByString:@"/"];
            strength = [NSString stringWithFormat:@"%@%@", strengthRaw, [components objectAtIndex:0]];
            unit = [components objectAtIndex:1];
            
            NSRange letterRange = [unit rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
            if (letterRange.location == NSNotFound)
                unit = @"";
        }
        
        *processedDrug = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        [*processedDrug setObject:brandName forKey:@"brandName"];
        [*processedDrug setObject:genericName forKey:@"genericName"];
        [*processedDrug setObject:medForm forKey:@"medForm"];
        [*processedDrug setObject:medFormType forKey:@"medFormType"];
        [*processedDrug setObject:medType forKey:@"medType"];
        [*processedDrug setObject:route forKey:@"route"];
        [*processedDrug setObject:strength forKey:@"strength"];
        [*processedDrug setObject:unit forKey:@"unit"];
        *ndc = thisNDC;
    }
}


int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        fprintf(stdout, "\n");
        
        if (argc < 4)
        {
            fprintf(stdout, "Usage:\nFDADatabaseParser <path to FDA's product.txt file from NDC database> <path to FDA's legacyproduct.txt file from NDC database> <path to output .sqlite file>\n");
            fprintf(stdout, "Example: ./FDADatabaseParser ./product.txt ./legacyproduct.txt ./medicationDB\n");
            fprintf(stdout, "\n");
            return 0;
        }
        
        // Read form mapping
        NSString* mappingContents = getFileContents(@"Mapping.txt");
        if (!mappingContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }

        __weak NSMutableDictionary* formMapping = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        __block BOOL isHeaderLine = YES;
        [mappingContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            NSArray* components = [line componentsSeparatedByString:@"\t"];
            if (isHeaderLine)
            {
                isHeaderLine = NO;
            }
            else
            {
                NSString* firstColumn = [[components objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
                NSString* secondColumn = [[[components objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]] capitalizedString];
                [formMapping setObject:secondColumn forKey:firstColumn];
            }
        }];

        __weak NSMutableArray* headers = [NSMutableArray arrayWithObjects:nil];
        __weak NSMutableDictionary* drugDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        __block BOOL didError = NO;
        
        // Read drugs
        NSString* fileContents = getFileContents([[NSString stringWithCString:argv[1] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath]);
        if (!fileContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }
        
        isHeaderLine = YES;
        [fileContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            NSArray* components = [line componentsSeparatedByString:@"\t"];
            if (isHeaderLine)
            {
                isHeaderLine = NO;
                [headers setArray:components];
            }
            else
            {
                NSMutableDictionary* drug = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
                for (int i = 0; i < [headers count]; i++)
                {
                    NSString* key = [headers objectAtIndex:i];
                    NSString* value = [components objectAtIndex:i];
                    [drug setObject:value forKey:key];
                }
                
                NSMutableDictionary* processedDrug = nil;
                NSString* ndc = nil;
                processRawDrugDict(drug, formMapping, &processedDrug, &ndc);
                
                if (!processedDrug || !ndc)
                {
                    didError = YES;
                    *stop = YES;
                }
                else
                {
                    [drugDict setObject:processedDrug forKey:ndc];
                }
            }
        }];

        if (didError)
            return 0;
        
        // Read legacy drugs
        NSString* legacyFileContents = getFileContents([[NSString stringWithCString:argv[2] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath]);
        if (!legacyFileContents)
        {
            fprintf(stdout, "\n");
            return 0;
        }

        isHeaderLine = YES;
        [headers removeAllObjects];
        [legacyFileContents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            NSArray* components = [line componentsSeparatedByString:@"\t"];
            if (isHeaderLine)
            {
                isHeaderLine = NO;
                [headers setArray:components];
            }
            else
            {
                NSMutableDictionary* drug = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
                for (int i = 0; i < [headers count]; i++)
                {
                    NSString* key = [headers objectAtIndex:i];
                    NSString* value = [components objectAtIndex:i];
                    [drug setObject:value forKey:key];
                }
                
                NSMutableDictionary* processedDrug = nil;
                NSString* ndc = nil;
                processRawDrugDict(drug, formMapping, &processedDrug, &ndc);
                
                if (!processedDrug || !ndc)
                {
                    didError = YES;
                    *stop = YES;
                }
                else
                {
                    NSMutableDictionary* newerDrug = [drugDict objectForKey:ndc];
                    if (!newerDrug)
                        [drugDict setObject:processedDrug forKey:ndc];
                }
            }
        }];
        
        
        if (didError)
            return 0;
        
        NSManagedObjectContext *context = managedObjectContext([[NSString stringWithCString:argv[3] encoding:[NSString defaultCStringEncoding]] stringByStandardizingPath]);

        NSMutableSet* routes = [NSMutableSet setWithObjects:nil];
        NSMutableDictionary* strengthUnits = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        NSMutableDictionary* doseUnits = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];

        NSMutableCharacterSet* unitTrimSet = [NSMutableCharacterSet decimalDigitCharacterSet];
        [unitTrimSet addCharactersInString:@".,)':"];
        [unitTrimSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];

        NSMutableString* medicationFile = [NSMutableString stringWithString:@""];
        [medicationFile appendString:@"brandName\tgenericName\tmedForm\tmedFormType\tmedType\tndc\troute\tstrength\tunit\n"];
        for (NSString* ndc in [drugDict allKeys])
        {
            NSMutableDictionary* drug = [drugDict objectForKey:ndc];
            Medication *med=(Medication *)[NSEntityDescription insertNewObjectForEntityForName:@"Medication" inManagedObjectContext:context];
            med.brandName = getDrugField(@"brandName", drug);
            med.genericName = getDrugField(@"genericName", drug);
            med.ndc = ndc;
            med.medForm = getDrugField(@"medForm", drug);
            med.medFormType = getDrugField(@"medFormType", drug);
            med.medType = getDrugField(@"medType", drug);
            med.route = getDrugField(@"route", drug);
            med.strength = getDrugField(@"strength", drug);
            med.unit = getDrugField(@"unit", drug);
            
            if ([med.route length] > 0)
                [routes addObject:med.route];
            
            NSString* strengthUnit = [med.strength stringByTrimmingCharactersInSet:unitTrimSet];
            if ([strengthUnit length] > 0)
            {
                NSMutableSet* strengthUnitsForType = [strengthUnits objectForKey:med.medFormType];
                if (!strengthUnitsForType)
                    strengthUnitsForType = [NSMutableSet setWithObjects:nil];
                [strengthUnitsForType addObject:strengthUnit];
                [strengthUnits setObject:strengthUnitsForType forKey:med.medFormType];
            }
            NSString* doseUnit = [med.unit stringByTrimmingCharactersInSet:unitTrimSet];
            if ([doseUnit length] > 0)
            {
                NSMutableSet* doseUnitsForType = [doseUnits objectForKey:med.medFormType];
                if (!doseUnitsForType)
                    doseUnitsForType = [NSMutableSet setWithObjects:nil];
                [doseUnitsForType addObject:doseUnit];
                [doseUnits setObject:doseUnitsForType forKey:med.medFormType];
            }
            
            [medicationFile appendFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\n", med.brandName, med.genericName, med.medForm, med.medFormType, med.medType, med.ndc, med.route, med.strength, med.unit];
        }
        [medicationFile writeToFile:@"Medication.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedFormType
        NSMutableString* medFormTypeFile = [NSMutableString stringWithString:@""];
        [medFormTypeFile appendString:@"medFormType\n"];
        NSMutableSet* medFormTypes = [NSMutableSet setWithObjects:nil];
        for (NSString* key in [formMapping allKeys])
        {
            if ([key length] > 0)
                [medFormTypes addObject:[formMapping objectForKey:key]];
        }
        for (NSString* key in [medFormTypes allObjects])
        {
            MedFormType *medFormType=(MedFormType *)[NSEntityDescription insertNewObjectForEntityForName:@"MedFormType" inManagedObjectContext:context];
            medFormType.medFormType = key;
            [medFormTypeFile appendFormat:@"%@\n", medFormType.medFormType];
        }
        [medFormTypeFile writeToFile:@"MedFormType.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedicationRoute
        NSMutableString* medicationRouteFile = [NSMutableString stringWithString:@""];
        [medicationRouteFile appendString:@"route\n"];
        for (NSString* key in [routes allObjects])
        {
            MedicationRoute *route=(MedicationRoute *)[NSEntityDescription insertNewObjectForEntityForName:@"MedicationRoute" inManagedObjectContext:context];
            route.route = key;
            [medicationRouteFile appendFormat:@"%@\n", route.route];
        }
        [medicationRouteFile writeToFile:@"MedicationRoute.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedStrengthUnit
        NSMutableString* medStrengthUnitFile = [NSMutableString stringWithString:@""];
        [medStrengthUnitFile appendString:@"medFormType\tunitDesc\n"];
        for (NSString* key in [strengthUnits allKeys])
        {
            NSMutableSet* allValues = [strengthUnits objectForKey:key];
            
            for (NSString* value in allValues)
            {
                MedStrengthUnit *strengthUnit=(MedStrengthUnit *)[NSEntityDescription insertNewObjectForEntityForName:@"MedStrengthUnit" inManagedObjectContext:context];
                strengthUnit.medFormType = key;
                strengthUnit.unitDesc = value;
                [medStrengthUnitFile appendFormat:@"%@\t%@\n", strengthUnit.medFormType, strengthUnit.unitDesc];
            }
        }
        [medStrengthUnitFile writeToFile:@"MedStrengthUnit.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedDoseUnit
        NSMutableString* medDoseUnitFile = [NSMutableString stringWithString:@""];
        [medDoseUnitFile appendString:@"medFormType\tunitDesc\n"];
        for (NSString* key in [doseUnits allKeys])
        {
            NSMutableSet* allValues = [doseUnits objectForKey:key];
            
            for (NSString* value in allValues)
            {
                MedDoseUnit *doseUnit=(MedDoseUnit *)[NSEntityDescription insertNewObjectForEntityForName:@"MedDoseUnit" inManagedObjectContext:context];
                doseUnit.medFormType = key;
                doseUnit.unitDesc = value;
                [medDoseUnitFile appendFormat:@"%@\t%@\n", doseUnit.medFormType, doseUnit.unitDesc];
            }
        }
        [medDoseUnitFile writeToFile:@"MedDoseUnit.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedApplyLocation
        NSMutableSet* medFormTypesApplyLocation = [NSMutableSet setWithObjects:nil];
        [medFormTypesApplyLocation addObject:@"Spray"];
        [medFormTypesApplyLocation addObject:@"Drops"];
        NSMutableSet* applyLocations = [NSMutableSet setWithObjects:nil];
        [applyLocations addObject:@"Mouth"];
        [applyLocations addObject:@"Left eye"];
        [applyLocations addObject:@"Right eye"];
        [applyLocations addObject:@"Each eye"];
        [applyLocations addObject:@"Left ear"];
        [applyLocations addObject:@"Right ear"];
        [applyLocations addObject:@"Each ear"];
        [applyLocations addObject:@"Scalp"];
        [applyLocations addObject:@"Left nostril"];
        [applyLocations addObject:@"Right nostril"];
        [applyLocations addObject:@"Each nostril"];
        NSMutableString* medApplyLocationFile = [NSMutableString stringWithString:@""];
        [medApplyLocationFile appendString:@"locationDesc\tmedFormType\n"];
        for (NSString* key in [medFormTypesApplyLocation allObjects])
        {
            for (NSString* loc in [applyLocations allObjects])
            {
                MedApplyLocation *applyLocation=(MedApplyLocation *)[NSEntityDescription insertNewObjectForEntityForName:@"MedApplyLocation" inManagedObjectContext:context];
                applyLocation.medFormType = key;
                applyLocation.locationDesc = loc;
                [medApplyLocationFile appendFormat:@"%@\t%@\n", applyLocation.locationDesc, applyLocation.medFormType];
            }
        }
        [medApplyLocationFile writeToFile:@"MedApplyLocation.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];

        // Output MedicationUpdateDate
        MedicationUpdateDate *lastUpdate=(MedicationUpdateDate *)[NSEntityDescription insertNewObjectForEntityForName:@"MedicationUpdateDate" inManagedObjectContext:context];
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        lastUpdate.lastUpdateDatetime = [dateFormatter stringFromDate:[NSDate date]];
        NSMutableString* medicationUpdateDateFile = [NSMutableString stringWithString:@""];
        [medicationUpdateDateFile appendString:@"lastUpdateDatetime\n"];
        [medicationUpdateDateFile appendFormat:@"%lld\n", (long long)[[NSDate date] timeIntervalSince1970]];
        [medicationUpdateDateFile writeToFile:@"MedicationUpdateDate.txt" atomically:YES encoding:NSASCIIStringEncoding error:nil];
        
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Error while saving %@", ([error localizedDescription] != nil) ? [error localizedDescription] : @"Unknown Error");
            exit(1);
        }
    }
    
    fprintf(stdout, "Completed successfully\n");

    return 0;
}

