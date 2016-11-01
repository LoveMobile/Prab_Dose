//
//  Dosecast-API.m
//  Dosecast-API
//
//  Created by Shawn Grimes on 10/1/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import "DrugImage.h"
#import "HistoryManager.h"


@implementation DrugImage

@dynamic imagePath;
@dynamic imageGUID;
@dynamic needsUpload;
@dynamic needsDelete;
@dynamic needsDownload;

//Called before a managed object is saved to the database
-(void)willSave{
    //If we are deleting the managed object
    if([self isDeleted]){
        [self showAlertWithString:[NSString stringWithFormat:@"Deleting image"]];
        //Delete the image file before deleting the managed object
        //Verify file exists
        NSString* fullPath = [self fullPathToImageFile];
        if (fullPath)
        {
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
            if(!fileExists){
                [self showAlertWithString:[NSString stringWithFormat:@"File does not exist: %@", fullPath]];
                return;
            }else{
                //Delete the file
                NSError *deleteError=nil;
                if ([[NSFileManager defaultManager] removeItemAtPath:fullPath error:&deleteError] != YES)
                {
                    [self showAlertWithString:[NSString stringWithFormat:@"Unable to delete file: %@", [deleteError localizedDescription]]];
                }else{
                    [self showAlertWithString:[NSString stringWithFormat:@"Image Deleted: %@", fullPath]];
                }
            }
        }
    }
    [super willSave];
}

- (NSString*) fullPathToImageFile
{
    if (self.imagePath)
    {
        return [NSString stringWithFormat:@"%@/%@", [DrugImage directoryPath], self.imagePath];
    }
    else
        return nil;
}

+ (NSString *)filePathForImageGUID:(NSString *)imageGUID
{
    if (imageGUID)
        return [NSString stringWithFormat:@"%@.jpg",imageGUID];
    else
        return nil;
}

+ (NSString*) directoryPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (NSString *)fullFilePathForImageGUID:(NSString *)imageGUID
{
    NSString* filePath = [DrugImage filePathForImageGUID:imageGUID];
    if (filePath)
        return [NSString stringWithFormat:@"%@/%@", [DrugImage directoryPath], filePath];
    else
        return nil;
}

- (void) updateImagePath
{
    NSString* newImagePath = [DrugImage filePathForImageGUID:self.imageGUID];
    if (newImagePath)
        self.imagePath = newImagePath;
}

-(void) showAlertWithString:(NSString *)stringToShow{
    DebugLog(@"DrugImage: %@", stringToShow);
    
    BOOL _isDebugOn=NO;
    if(_isDebugOn){
        NSLog(@"DrugImage: %@", stringToShow);
    }
}


@end
