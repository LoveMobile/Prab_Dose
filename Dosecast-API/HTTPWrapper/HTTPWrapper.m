//
//  HTTPWrapper.m
//  Dosecast
//
//  Created by Jonathan Levene on 2/6/10.
//  Copyright Montuno Software, LLC 2010. All rights reserved.
//

#import "HTTPWrapper.h"
#import "DosecastUtil.h"

static const NSTimeInterval DEFAULT_HTTP_REQUEST_TIMEOUT = 60.0;

@implementation HTTPWrapper

@synthesize receivedData;
@synthesize requestURL;
@synthesize asynchronous;
@synthesize responseStatusCode;
@synthesize mimeType;
@synthesize username;
@synthesize password;
@synthesize delegate;

#pragma mark -
#pragma mark Constructor and destructor

- (id)init
{
    if ((self = [super init]))
    {
        receivedData = [[NSMutableData alloc] init];
		requestURL = [[NSURL alloc] init];
        conn = nil;
		responseStatusCode = 0;
        asynchronous = YES;
        mimeType = @"text/html";
        delegate = nil;
        username = @"";
        password = @"";
		trustedHosts = [[NSMutableArray alloc] init];
    }

    return self;
}


#pragma mark -
#pragma mark Public methods

- (void)sendGETRequestTo:(NSURL *)url withParameters:(NSDictionary *)parameters
{
    NSURL *finalURL = url;
    if (parameters != nil)
    {
		NSMutableString *params = [[NSMutableString alloc] init];
        for (id key in parameters)
        {
            NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            CFStringRef value = (CFStringRef)CFBridgingRetain([[parameters objectForKey:key] copy]);
            // Escape even the "reserved" characters for URLs 
            // as defined in http://www.ietf.org/rfc/rfc2396.txt
            CFStringRef encodedValue = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                               value,
                                                                               NULL, 
                                                                               (CFStringRef)@";/?:@&=+$,", 
                                                                               kCFStringEncodingUTF8);
            [params appendFormat:@"%@=%@&", encodedKey, encodedValue];
            CFRelease(value);
            CFRelease(encodedValue);
        }
        [params deleteCharactersInRange:NSMakeRange([params length] - 1, 1)];
    
		NSString *urlWithParams = [[url absoluteString] stringByAppendingFormat:@"?%@", params];
		finalURL = [NSURL URLWithString:urlWithParams];
	}

	requestURL = [finalURL copy];
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
    [headers setValue:@"text/html; charset=utf-8" forKey:@"Content-Type"];
    [headers setValue:mimeType forKey:@"Accept"];
    [headers setValue:@"no-cache" forKey:@"Cache-Control"];
    [headers setValue:@"no-cache" forKey:@"Pragma"];
    [headers setValue:@"close" forKey:@"Connection"]; // Avoid HTTP 1.1 "keep alive" for the connection

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:finalURL
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:DEFAULT_HTTP_REQUEST_TIMEOUT];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:headers];
	
    [self startConnection:request];
}

- (void)sendPOSTRequestTo:(NSURL *)url withBody:(NSString*)body withContentType:(NSString*)contentType
{
	NSMutableString *finalContentType = [[NSMutableString alloc] initWithString:@"application/x-www-form-urlencoded; charset=utf-8"];
	if (contentType != nil || [contentType length] > 0)
	{
		[finalContentType setString:contentType];
	}
	
	requestURL = [url copy];
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
    [headers setValue:finalContentType forKey:@"Content-Type"];
    [headers setValue:mimeType forKey:@"Accept"];
    [headers setValue:@"no-cache" forKey:@"Cache-Control"];
    [headers setValue:@"no-cache" forKey:@"Pragma"];
    [headers setValue:@"close" forKey:@"Connection"]; // Avoid HTTP 1.1 "keep alive" for the connection
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:DEFAULT_HTTP_REQUEST_TIMEOUT];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
	if (body != nil)
	{
		NSData* bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
		[request setHTTPBody:bodyData];
	}
	
    [self startConnection:request];
}

- (void)sendPOSTRequestTo:(NSURL *)url withDataBody:(NSData*)body withContentType:(NSString*)contentType{
    NSMutableString *finalContentType = [[NSMutableString alloc] initWithString:@"application/x-www-form-urlencoded; charset=utf-8"];
	if (contentType != nil || [contentType length] > 0)
	{
		[finalContentType setString:contentType];
	}
	
	requestURL = [url copy];
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
    [headers setValue:finalContentType forKey:@"Content-Type"];
    [headers setValue:mimeType forKey:@"Accept"];
    [headers setValue:@"no-cache" forKey:@"Cache-Control"];
    [headers setValue:@"no-cache" forKey:@"Pragma"];
    [headers setValue:@"close" forKey:@"Connection"]; // Avoid HTTP 1.1 "keep alive" for the connection
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:DEFAULT_HTTP_REQUEST_TIMEOUT];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
	if (body != nil)
	{
		[request setHTTPBody:body];
	}
	
    [self startConnection:request];
}

- (void)cancelConnection
{
	if (conn != nil)
	{
		[conn cancel];
		conn = nil;
	}
}

- (NSDictionary *)responseAsPropertyList
{
    NSString *errorStr = nil;
    NSPropertyListFormat format;
    NSDictionary *propertyList = [NSPropertyListSerialization propertyListFromData:receivedData
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:&format
                                                                  errorDescription:&errorStr];
    return propertyList;
}

- (NSString *)responseAsText
{
    return [[NSString alloc] initWithData:receivedData 
                                 encoding:NSUTF8StringEncoding];
}

- (void)addTrustedHost:(NSString*)host
{
	[trustedHosts addObject:host];
}

- (void)startConnection:(NSURLRequest *)request
{
	[receivedData setLength:0];
	responseStatusCode = 0;
    if (asynchronous)
    {
        [self cancelConnection];
        conn = [[NSURLConnection alloc] initWithRequest:request
                                               delegate:self
                                       startImmediately:YES];
		
        if (!conn)
        {

            if ([delegate respondsToSelector:@selector(HTTPWrapper:didFailWithError:)])
            {
                NSString* errorKey = NSURLErrorFailingURLStringErrorKey;
                NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObject:[request URL] forKey:errorKey];
                [info setObject:@"could not open connection" forKey:NSLocalizedDescriptionKey];
                NSError* error = [NSError errorWithDomain:@"HTTPWrapper" code:1 userInfo:info];
                [delegate HTTPWrapper:self didFailWithError:error];
            }
        }
    }
    else
    {
        NSURLResponse* response = [[NSURLResponse alloc] init];
        NSError* error = [[NSError alloc] init];
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		[receivedData setData:data];
			
		if (error == nil)
		{
			[self handleResponse:response];		
			
			if ([delegate respondsToSelector:@selector(HTTPWrapper:didRetrieveData:)])
			{
				[delegate HTTPWrapper:self didRetrieveData:receivedData];
			}		
		}
		else {
			if ([delegate respondsToSelector:@selector(HTTPWrapper:didFailWithError:)])
			{
				[delegate HTTPWrapper:self didFailWithError:error];
			}
		}		
    }
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	for (int i = 0; i < [trustedHosts count]; i++)
	{
		NSString *host = [trustedHosts objectAtIndex:i];
		if ([host caseInsensitiveCompare:protectionSpace.host] == NSOrderedSame)
		{
			return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
		}
	}
	return NO;		
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		for (int i = 0; i < [trustedHosts count]; i++)
		{
			NSString *host = [trustedHosts objectAtIndex:i];
			if ([host caseInsensitiveCompare:challenge.protectionSpace.host] == NSOrderedSame)
			{
				[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];				
				[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
				return;
			}
		}
	}
	
	NSInteger count = [challenge previousFailureCount];
    if (count == 0)
    {
        NSURLCredential* credential = [NSURLCredential credentialWithUser:username
                                                                  password:password
                                                               persistence:NSURLCredentialPersistenceNone];
        [[challenge sender] useCredential:credential 
               forAuthenticationChallenge:challenge];
    }
    else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        if ([delegate respondsToSelector:@selector(HTTPWrapperHasBadCredentials:)])
        {
            [delegate HTTPWrapperHasBadCredentials:self];
        }
    }
}

- (void) handleResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	responseStatusCode = (int)[httpResponse statusCode];
    switch (responseStatusCode)
    {			
        case 201:
        {
            NSString* url = [[httpResponse allHeaderFields] objectForKey:@"Location"];
            if ([delegate respondsToSelector:@selector(HTTPWrapper:didCreateResourceAtURL:)])
            {
                [delegate HTTPWrapper:self didCreateResourceAtURL:url];
            }
        }
            
			// Here you could add more status code handling... for example 404 (not found),
			// 204 (after a PUT or a DELETE), 500 (server error), etc... with the
			// corresponding delegate methods called as required.
			
        default:
        {
            if ([delegate respondsToSelector:@selector(HTTPWrapper:didReceiveStatusCode:)])
            {
                [delegate HTTPWrapper:self didReceiveStatusCode:responseStatusCode];
            }
            break;
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self handleResponse:response];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self cancelConnection];
    if ([delegate respondsToSelector:@selector(HTTPWrapper:didFailWithError:)])
    {
        [delegate HTTPWrapper:self didFailWithError:error];
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	// Don't cache responses
	return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self cancelConnection];
    if ([delegate respondsToSelector:@selector(HTTPWrapper:didRetrieveData:)])
    {
        [delegate HTTPWrapper:self didRetrieveData:receivedData];
    }
}

@end
