//
//  HTTPWrapper.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/6/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import <Foundation/Foundation.h> 
#import "HTTPWrapperDelegate.h"

@interface HTTPWrapper : NSObject
{
@private
    NSMutableData *receivedData;
	int responseStatusCode;
	NSURL* requestURL;
    NSString *mimeType;
    NSURLConnection *conn;
    BOOL asynchronous;
    NSObject<HTTPWrapperDelegate> *__weak delegate;
    NSString *username;
    NSString *password;
	NSMutableArray* trustedHosts;
}

@property (nonatomic, readonly) NSData *receivedData;
@property (nonatomic, readonly) NSURL *requestURL;
@property (nonatomic) BOOL asynchronous;
@property (nonatomic, readonly) int responseStatusCode;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, weak) NSObject<HTTPWrapperDelegate> *delegate; // Do not retain delegates!

- (void)sendGETRequestTo:(NSURL *)url withParameters:(NSDictionary *)parameters;
- (void)sendPOSTRequestTo:(NSURL *)url withBody:(NSString*)body withContentType:(NSString*)contentType;
- (void)sendPOSTRequestTo:(NSURL *)url withDataBody:(NSData*)body withContentType:(NSString*)contentType;
- (void)cancelConnection;
- (void)addTrustedHost:(NSString*)host;
- (void) handleResponse:(NSURLResponse *)response;
- (NSDictionary *)responseAsPropertyList;
- (NSString *)responseAsText;
- (void)startConnection:(NSURLRequest *)request;

@end

