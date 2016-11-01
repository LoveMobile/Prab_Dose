//
//  GlobalSettingsDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/20/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol GlobalSettingsDelegate

@required

// Returns whether any group the user belongs to gives the premium edition
- (BOOL)doesAnyGroupGivePremium;

// Returns whether any group the user belongs to gives the subscription edition
- (BOOL)doesAnyGroupGiveSubscription;

- (NSString*) deviceToken;
- (NSString*) clientVersion;

@end
