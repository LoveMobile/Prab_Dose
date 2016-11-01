//
//  ReachabilityManager.m
//  Dosecast
//
//  Created by Jonathan Levene on 4/1/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import "ReachabilityManager.h"
#import "Reachability.h"
#import "DosecastUtil.h"
#import "PillNotificationManager.h"
#import "DataModel.h"

static ReachabilityManager *gInstance = nil;

@implementation ReachabilityManager

- (id)init
{
    if ((self = [super init]))
    {		        
		internetReach = [Reachability reachabilityForInternetConnection];
		[internetReach startNotifier];
	}
	
    return self;	
}

- (void)dealloc
{
	[internetReach stopNotifier];
}

// Singleton methods

+ (ReachabilityManager*) getInstance
{
    @synchronized(self)
    {
        if (!gInstance)
            gInstance = [[self alloc] init];
    }
    
    return(gInstance);
}

// Returns whether we can reach the server
-(BOOL)canReachInternet
{	
	return ([internetReach currentReachabilityStatus] != NotReachable);
}

// Returns whether we can reach 3G
-(BOOL)canReach3G
{
	return [internetReach currentWWANReachabilityStatus];
}

@end
