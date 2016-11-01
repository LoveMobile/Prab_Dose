//
//  UIDeviceHardware.h
//
//  Used to determine EXACT version of device software is running on.

#import <Foundation/Foundation.h>

@interface UIDeviceHardware : NSObject 

+ (NSString *) platform;
+ (void) platformDetails:(NSString**)model
           generationNum:(int*)generationNum
              versionNum:(int*)versionNum;

@end