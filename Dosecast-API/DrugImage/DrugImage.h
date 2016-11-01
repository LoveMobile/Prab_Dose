//
//  Dosecast-API.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 10/1/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface DrugImage : NSManagedObject
{

}

@property (nonatomic, strong) NSString * imagePath;
@property (nonatomic, strong) NSString * imageGUID;
@property (nonatomic, strong) NSNumber * needsUpload;
@property (nonatomic, strong) NSNumber * needsDelete;
@property (nonatomic, strong) NSNumber * needsDownload;

- (NSString*) fullPathToImageFile;
- (void) updateImagePath;

+ (NSString *)fullFilePathForImageGUID:(NSString *)imageGUID;

@end
