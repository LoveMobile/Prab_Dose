//
//  UIDeviceHardware.m
//
//  Used to determine EXACT version of device software is running on.

#import "UIDeviceHardware.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation UIDeviceHardware

+ (NSString *) platform{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

+ (void) platformDetails:(NSString**)model
           generationNum:(int*)generationNum
              versionNum:(int*)versionNum
{
    NSString* platformString = [UIDeviceHardware platform];
    *model = nil;
    *generationNum = -1;
    *versionNum = -1;
    NSRange range = [platformString rangeOfString:@","];
    if (range.location == NSNotFound)
    {
        *model = @"Simulator";
        return;
    }
    *model = [platformString substringToIndex:range.location-1];
    *generationNum = [[platformString substringWithRange:NSMakeRange(range.location-1, 1)] intValue];
    *versionNum = [[platformString substringFromIndex:range.location+1] intValue];
}

@end