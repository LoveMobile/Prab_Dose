//
//  ServerProxyDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/13/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

typedef enum {
	ServerProxySuccess						 = 0,
	ServerProxyCommunicationsError			 = 1,
	ServerProxyServerError					 = 2,
	ServerProxyInputError					 = 3,
    ServerProxyDeviceDetached                = 4
} ServerProxyStatus;

@class Group;

@protocol ServerProxyDelegate

@optional

- (void)createUserServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage;
- (void)syncServerProxyResponse:(ServerProxyStatus)status errorMessage:(NSString*)errorMessage;
- (void)getBlobServerProxyResponse:(ServerProxyStatus)status data:(NSData*)data errorMessage:(NSString*)errorMessage;
- (void)groupInfoByNameServerProxyResponse:(ServerProxyStatus)status groupFound:(BOOL)groupFound group:(Group*)group errorMessage:(NSString*)errorMessage;
- (void)groupInfoByIDServerProxyResponse:(ServerProxyStatus)status groupFound:(BOOL)groupFound group:(Group*)group errorMessage:(NSString*)errorMessage;
- (void)groupJoinServerProxyResponse:(ServerProxyStatus)status groupJoinResult:(NSString*)groupJoinResult gaveSubscription:(BOOL)gaveSubscription gavePremium:(BOOL)gavePremium errorMessage:(NSString*)errorMessage;
- (void)groupLeaveServerProxyResponse:(ServerProxyStatus)status groupLeaveResult:(NSString*)groupLeaveResult tookAwaySubscription:(BOOL)tookAwaySubscription tookAwayPremium:(BOOL)tookAwayPremium errorMessage:(NSString*)errorMessage;
- (void)getRendezvousCodeServerProxyResponse:(ServerProxyStatus)status rendezvousCode:(NSString*)rendezvousCode expires:(NSDate*)expires errorMessage:(NSString*)errorMessage;
- (void)submitRendezvousCodeServerProxyResponse:(ServerProxyStatus)status rendezvousResult:(NSString*)rendezvousResult errorMessage:(NSString*)errorMessage;
- (void)getAttachedDevicesServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage;
- (void)detachDeviceServerProxyResponse:(ServerProxyStatus)status syncDevices:(NSArray*)syncDevices errorMessage:(NSString*)errorMessage;

@end
