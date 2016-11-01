//
//  HTTPWrapperDelegate.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/6/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import <Foundation/Foundation.h> 

@class HTTPWrapper;

@protocol HTTPWrapperDelegate

@optional
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didRetrieveData:(NSData *)data;
- (void)HTTPWrapperHasBadCredentials:(HTTPWrapper *)httpWrapper;
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didCreateResourceAtURL:(NSString *)url;
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didFailWithError:(NSError *)error;
- (void)HTTPWrapper:(HTTPWrapper *)HTTPWrapper didReceiveStatusCode:(int)statusCode;

@end
