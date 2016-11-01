//
//  DosecastAPIImp.h
//  Dosecast
//
//  Created by Jonathan Levene on 9/26/10.
//  Copyright 2010 Montuno Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DosecastAPI.h"
#import "TextEntryViewControllerDelegate.h"
#import "PillNotificationManagerDelegate.h"
#import "ServerProxyDelegate.h"
#import "DataModelDelegate.h"
#import "DosecastDBDataFile.h"

@class DosecastDBDataFile;
@protocol DosecastAPIDelegate;

// This class is the API to the Dosecast functionality. An instance of this class
// should be created by the App Delegate, and most App Delegate methods should be
// passed through.

@interface DosecastAPIImp : DosecastAPI<PillNotificationManagerDelegate,
                                     ServerProxyDelegate,
                                     DataModelDelegate,
                                     DosecastDBDataFileDelegate>
{
@private
	BOOL isActive;
	BOOL userRegistered;
	NSObject<DosecastAPIDelegate>* __weak delegate;
    DosecastDBDataFile* dbDataFile;
    BOOL registeredForRemoteNotifications;
    void (^backgroundFetchCompletionHandler)(UIBackgroundFetchResult result);
}

// Initializer with delegate and launch options. After initializing, the client must wait until the delegate's
// handleDosecastUIInitializationComplete method is called before displaying any of this object's view controllers.
         -(id)initWithDelegate:(NSObject<DosecastAPIDelegate>*)del
	             launchOptions:(NSDictionary*)launchOptions                     // The launchOptions passed to the ApplicationDelegate's didFinishLaunchingWithOptions method
				      userData:(NSString*)userData                              // Optional custom data to be stored about the current user (such as an account ID) 
                      apiFlags:(NSArray*)apiFlags                               // An array of Dosecast API flags to enable (if a flag is not included, it is considered disabled)
               persistentFlags:(NSArray*)persistentFlags                        // An array of strings corresponding to persistent flags to write to & read from the Dosecast data file
                productVersion:(NSString*)productVersion;                       // The version of the product that the API is running in

@end