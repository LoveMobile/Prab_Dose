//
//  ReachabilityManager.h
//  Dosecast
//
//  Created by Jonathan Levene on 3/12/10.
//  Copyright 2010 Montuno Software. All rights reserved.

@class Reachability;

// This class handles reachability notifications received while the app is running
@interface ReachabilityManager : NSObject
{
@private
	Reachability* internetReach;
}

// Singleton methods
+ (ReachabilityManager*) getInstance;

// Returns whether we can reach the internet
-(BOOL)canReachInternet;

// Returns whether we can reach 3G
-(BOOL)canReach3G;

@end
