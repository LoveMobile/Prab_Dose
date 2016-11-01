//
//  LocalNotificationManagerDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/13/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//

#import <Foundation/Foundation.h> 

@protocol LocalNotificationManagerDelegate

@optional

- (void)getStateLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)createPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)editPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)refillPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)deletePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)undoPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)takePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)skipPillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)postponePillLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)subscribeLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)upgradeLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)startFreeTrialLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)setBedtimeLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)setPreferencesLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;
- (void)moveScheduledRemindersLocalNotificationManagerResponse:(BOOL)result errorMessage:(NSString*)errorMessage;

@end
