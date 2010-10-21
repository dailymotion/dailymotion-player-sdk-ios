//
//  Dailymotion.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "Dailymotion.h"
#import "DMBoundableInputStream.h"
#import "SBJsonParser.h"
#import "SBJsonWriter.h"

#define kDMAPIEndpointURL [NSURL URLWithString:@"https://api.dailymotion.com/json"]
#define kDMOAuthAuthorizeEndpointURL [NSURL URLWithString:@"https://api.dailymotion.com/oauth/authorize"]
#define kDMOAuthTokenEndpointURL [NSURL URLWithString:@"https://api.dailymotion.com/oauth/token"]

#define kDMRedirectURL [NSURL URLWithString:@"dailymotion://success"]
static NSString *const kDMVersion = @"1.0";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";


NSString * const DailymotionTransportErrorDomain = @"DailymotionTransportErrorDomain";
NSString * const DailymotionAuthErrorDomain = @"DailymotionAuthErrorDomain";
NSString * const DailymotionApiErrorDomain = @"DailymotionApiErrorDomain";

@implementation NSString (numericCompare)
- (NSComparisonResult)numericCompare:(NSString *)aString
{
    return [self compare:aString options:NSNumericSearch];
}
@end

@implementation Dailymotion
@synthesize timeout;
@dynamic version;

#pragma mark Dailymotion (private)

- (NSString *)userAgent
{
    static NSString *userAgent = nil;
    if (!userAgent)
    {
#if TARGET_OS_IPHONE
        UIDevice *device = [UIDevice currentDevice];
        userAgent = [NSString stringWithFormat:@"Dailymotion-ObjC/%@ (%@ %@; %@)",
                     kDMVersion, device.systemName, device.systemVersion, device.model];
#else
        SInt32 versionMajor, versionMinor, versionBugFix;
        if (Gestalt(gestaltSystemVersionMajor, &versionMajor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionMinor, &versionMinor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionBugFix, &versionBugFix) != noErr) versionBugFix = 0;
        userAgent = [NSString stringWithFormat:@"Dailymotion-ObjC/%@ (Mac OS X %u.%u.%u; Machintosh)",
                     kDMVersion, versionMajor, versionMinor, versionBugFix];
#endif
    }
    return userAgent;
}

- (NSURLConnection *)performRequestWithURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers
{
    NSString *userAgent = [self userAgent];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setTimeoutInterval:timeout];

    if ([payload isKindOfClass:[NSDictionary class]])
    {
        NSMutableData *postData = [NSMutableData data];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSEnumerator *enumerator = [payload keyEnumerator];
        NSString *key;
        int i = 0;
        int count = (int)[payload count] - 1;
        while ((key = [enumerator nextObject]))
        {
            NSString *escapedValue = [(NSString *)CFURLCreateStringByAddingPercentEscapes
            (
                NULL,
                (CFStringRef)[payload objectForKey:key],
                NULL,
                CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
                kCFStringEncodingUTF8
            ) autorelease];
            if (!escapedValue)
            {
                escapedValue = @"";
            }
            NSString *data = [NSString stringWithFormat:@"%@=%@%@", key, escapedValue, (i++ < count ?  @"&" : @"")];
            [postData appendData:[data dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [request setHTTPBody:postData];
    }
    else if ([payload isKindOfClass:[NSString class]])
    {
        [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else if ([payload isKindOfClass:[NSInputStream class]])
    {
        [request setHTTPBodyStream:payload];
    }

    return [[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
}

- (void)resetAPIConnection
{
    currentState = DailymotionStateNone;
    [apiConnection release], apiConnection = nil;
    [apiResponseData release], apiResponseData = nil;
    [apiResponse release], apiResponse = nil;
}

- (void)resetUploadConnection
{
    [uploadConnection release], uploadConnection = nil;
    [uploadResponseData release], uploadResponseData = nil;
    [uploadResponse release], uploadResponse = nil;
}

- (NSString *)accessToken
{
    if (session)
    {
        NSString *accessToken = [session valueForKey:@"access_token"];
        NSDate *expires = [session valueForKey:@"expires"];
        if (accessToken)
        {
            if (!expires || [expires timeIntervalSinceNow] > 0)
            {
                return accessToken;
            }
            // else: Token expired
        }
    }
    return nil;
}

- (void)requestAccessToken
{
    if (apiConnection)
    {
        [[NSException exceptionWithName:@"InvalidStateException"
                                 reason:@"Requested an access token with a running connection" userInfo:nil] raise];
    }

    if (session)
    {
        NSString *refreshToken = [session valueForKey:@"refresh_token"];
        if (refreshToken)
        {
            currentState = DailymotionStateOAuthRequest;
            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            [payload setObject:@"refresh_token" forKey:@"grant_type"];
            [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
            [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
            [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
            [payload setObject:refreshToken forKey:@"refresh_token"];
            apiConnection = [[self performRequestWithURL:kDMOAuthTokenEndpointURL payload:payload headers:nil] retain];
        }
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
    [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
    [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];

    switch (grantType)
    {
        case DailymotionNoGrant:
            // Should never happen
            [[NSException exceptionWithName:@"InvalidStateException"
                                     reason:@"Requested an access token with no grant" userInfo:nil] raise];
            break;

        case DailymotionGrantTypeNone:
            currentState = DailymotionStateOAuthRequest;
            [payload setObject:@"none" forKey:@"grant_type"];
            apiConnection = [[self performRequestWithURL:kDMOAuthTokenEndpointURL payload:payload headers:nil] retain];
            break;

        case DailymotionGrantTypePassword:
            currentState = DailymotionStateOAuthRequest;
            [payload setObject:@"password" forKey:@"grant_type"];
            [payload setObject:[grantInfo valueForKey:@"username"] forKey:@"username"];
            [payload setObject:[grantInfo valueForKey:@"password"] forKey:@"password"];
            apiConnection = [[self performRequestWithURL:kDMOAuthTokenEndpointURL payload:payload headers:nil] retain];
            break;

        case DailymotionGrantTypeToken:
            // TODO: call a delegate with an auth required message
            break;
    }
}

- (void)performCalls
{
    @synchronized(self)
    {
        if (apiConnection)
        {
            // Another request is currently in progress, wait for its completion before to start a new one.
            // NOTE: the handleAPIResponse will reschedule a new performCalls once completed if there is some waiting calls
            return;
        }

        NSString *accessToken = [self accessToken];
        if (grantType != DailymotionNoGrant && !accessToken)
        {
            // OAuth authentication is require but no valid access token is found, request a new one and postpone calls.
            // NOTE: the handleOAuthResponse will reschedule a new performCalls upon auth success
            [self requestAccessToken];
            return;
        }

        NSMutableArray *callsRequest = [[NSMutableArray alloc] init];
        // Process calls in FIFO order
        NSEnumerator *enumerator = [[[callQueue allKeys] sortedArrayUsingSelector:@selector(numericCompare:)] objectEnumerator];
        NSString *callId;
        int_fast8_t slots = 10; // A maximum of 10 calls per request is allowed
        while ((callId = [enumerator nextObject]) && slots-- > 0)
        {
            NSDictionary *callInfo = [callQueue objectForKey:callId];
            NSDictionary *call = [NSMutableDictionary dictionary];
            [call setValue:[callInfo valueForKey:@"id"] forKey:@"id"];
            [call setValue:[callInfo valueForKey:@"method"] forKey:@"call"];
            if ([callInfo valueForKey:@"args"])
            {
                [call setValue:[callInfo valueForKey:@"args"] forKey:@"args"];
            }
            [callsRequest addObject:call];
        }

        NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithObject:@"application/json" forKey:@"Content-Type"];
        if (accessToken)
        {
            [headers setValue:[NSString stringWithFormat:@"OAuth %@", accessToken] forKey:@"Authorization"];
        }

        currentState = DailymotionStateAPIRequest;
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        apiConnection = [[self performRequestWithURL:kDMAPIEndpointURL
                                             payload:[jsonWriter stringWithObject:callsRequest]
                                             headers:headers] retain];

        [callsRequest release];
    }
}

- (void)performUploads
{
    if (uploadConnection || [uploadFileQueue count] == 0)
    {
        return;
    }

    NSDictionary *uploadInfo = [uploadFileQueue objectAtIndex:0];
    NSString *filePath = [uploadInfo valueForKey:@"file_path"];
    NSUInteger fileSize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] objectForKey:NSFileSize] unsignedIntegerValue];
    NSInputStream *fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];

    DMBoundableInputStream *payload = [[[DMBoundableInputStream alloc] init] autorelease];
    payload.middleStream = fileStream;
    payload.headData = [[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n", kDMBoundary, [filePath lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding];
    payload.tailData = [[NSString stringWithFormat:@"\r\n--%@--\r\n", kDMBoundary] dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [headers setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", kDMBoundary] forKey:@"Content-Type"];
    [headers setValue:[NSString stringWithFormat:@"%d", (fileSize + payload.headData.length + payload.tailData.length)] forKey:@"Content-Length"];

    uploadConnection = [[self performRequestWithURL:[uploadInfo objectForKey:@"upload_url"] payload:(NSInputStream *)payload headers:headers] retain];
}

- (void)raiseGlobalError:(NSError *)error
{
    @synchronized(self)
    {
        NSEnumerator *enumerator = [[[callQueue allKeys] sortedArrayUsingSelector:@selector(numericCompare:)] objectEnumerator];
        NSString *callId;
        while ((callId = [enumerator nextObject]))
        {
            NSDictionary *call = [callQueue objectForKey:callId];
            id<DailymotionDelegate> delegate = [call objectForKey:@"delegate"];
            if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
            {
                [delegate dailymotion:self didReturnError:error userInfo:[call valueForKey:@"userInfo"]];
            }
            [callQueue removeObjectForKey:callId];
        }
        [self resetAPIConnection];
    }
}

- (void)handleAPIResponse
{
    if ([apiResponse statusCode] == 400 || [apiResponse statusCode] == 401 || [apiResponse statusCode] == 403)
    {
        NSString *error = nil;
        NSString *message = nil;
        NSString *authenticateHeader = [[apiResponse allHeaderFields] valueForKey:@"Www-Authenticate"];

        if (authenticateHeader)
        {
            NSScanner *scanner = [NSScanner scannerWithString:authenticateHeader];
            [scanner scanString:@"error=\"" intoString:nil];
            [scanner scanString:@"\"" intoString:&error];
            if ([scanner scanString:@" error_description=\"" intoString:nil])
            {
                [scanner scanString:@"\"" intoString:&message];
            }
        }

        if ([error isEqualToString:@"expired_token"])
        {
            @synchronized(self) // connection should not be seen nil by other threads before the access_token request
            {
                [self resetAPIConnection];
                // Try to refresh the access token
                [self requestAccessToken];
                return;
            }
        }
        else
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:error forKey:@"error"];
            if (message)
            {
                [userInfo setObject:message forKey:NSLocalizedDescriptionKey];
            }
            [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain code:0 userInfo:userInfo]];
            return;
        }
    }

    @synchronized(self)
    {
        SBJsonParser *jsonParser = [[[SBJsonParser alloc] init] autorelease];
        NSArray *results = [jsonParser objectWithString:[[[NSString alloc] initWithData:apiResponseData encoding:NSUTF8StringEncoding] autorelease]];
        if (!results)
        {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid API server response."
                                                                 forKey:NSLocalizedDescriptionKey];
            [self raiseGlobalError:[NSError errorWithDomain:DailymotionApiErrorDomain
                                                       code:0
                                                   userInfo:userInfo]];
            return;
        }
        else if ([apiResponse statusCode] != 200)
        {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unknown error: %d.", [apiResponse statusCode]]
                                                                 forKey:NSLocalizedDescriptionKey];
            [self raiseGlobalError:[NSError errorWithDomain:DailymotionApiErrorDomain
                                                       code:[apiResponse statusCode]
                                                   userInfo:userInfo]];
            return;
        }

        NSDictionary *result;
        for (result in results)
        {
            NSString *callId = [result objectForKey:@"id"];

            if (!callId)
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid server response: missing `id' key."
                                                                     forKey:NSLocalizedDescriptionKey];
                [self raiseGlobalError:[NSError errorWithDomain:DailymotionApiErrorDomain code:0 userInfo:userInfo]];
                return; // Stops there, we sent error to all delegates, this kind error should never happen but who knows...
            }

            NSDictionary *call = [callQueue objectForKey:callId];
            id delegate = [call objectForKey:@"delegate"];
            NSDictionary *userInfo = [call valueForKey:@"userInfo"];
            [callQueue removeObjectForKey:callId];

            if ([result objectForKey:@"error"])
            {
                NSInteger code = [[[result objectForKey:@"error"] objectForKey:@"code"] intValue];
                NSString *message = [[result objectForKey:@"error"] objectForKey:@"message"];

                if (code == 403)
                {
                    if ([delegate respondsToSelector:@selector(dailymotion:didRequestAuthWithMessage:userInfo:)])
                    {
                        [delegate dailymotion:self didRequestAuthWithMessage:message userInfo:userInfo];
                    }
                    continue;
                }
                else
                {
                    NSDictionary *info = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
                    NSError *error = [NSError errorWithDomain:DailymotionApiErrorDomain code:code userInfo:info];
                    if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
                    {
                        [delegate dailymotion:self didReturnError:error userInfo:userInfo];
                    }
                }
            }
            else if (![result objectForKey:@"result"])
            {
                NSDictionary *info = [NSDictionary dictionaryWithObject:@"Invalid API server response: no `result' key found."
                                                                     forKey:NSLocalizedDescriptionKey];
                NSError *error = [NSError errorWithDomain:DailymotionApiErrorDomain code:0 userInfo:info];
                if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
                {
                    [delegate dailymotion:self didReturnError:error userInfo:userInfo];
                }
            }
            else
            {
                if ([delegate respondsToSelector:@selector(dailymotion:didReturnResult:userInfo:)])
                {
                    [delegate dailymotion:self didReturnResult:[result objectForKey:@"result"] userInfo:userInfo];
                }
            }
        }

        [self resetAPIConnection];
        if ([callQueue count] > 0)
        {
            // Some new calls are waiting to be performed
            [self performCalls];
        }
    }
}

- (void)handleOAuthResponse
{
    SBJsonParser *jsonParser = [[[SBJsonParser alloc] init] autorelease];
    NSDictionary *result = [jsonParser objectWithString:[[[NSString alloc] initWithData:apiResponseData encoding:NSUTF8StringEncoding] autorelease]];

    if (!result)
    {
        [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain
                                                   code:0
                                               userInfo:[NSDictionary dictionaryWithObject:@"Invalid OAuth token server response."
                                                                                    forKey:NSLocalizedDescriptionKey]]];
    }
    else if ([result valueForKey:@"error"])
    {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[result valueForKey:@"error"] forKey:@"error"];
        if ([result valueForKey:@"error_description"])
        {
            [userInfo setObject:[result valueForKey:@"error_description"] forKey:NSLocalizedDescriptionKey];
        }
        [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain code:0 userInfo:userInfo]];
    }
    else if ([result valueForKey:@"access_token"])
    {
        NSMutableDictionary *tmpSession = [NSMutableDictionary dictionaryWithObjectsAndKeys:[result valueForKey:@"access_token"], @"access_token", nil];
        if ([result valueForKey:@"expires_in"])
        {
            [tmpSession setObject:[NSDate dateWithTimeIntervalSinceNow:[[result valueForKey:@"expires_in"] doubleValue]] forKey:@"expires"];
        }
        if ([result valueForKey:@"refresh_token"])
        {
            [tmpSession setObject:[result valueForKey:@"refresh_token"] forKey:@"refresh_token"];
        }
        if ([result valueForKey:@"scope"])
        {
            [tmpSession setObject:[result valueForKey:@"scope"] forKey:@"scope"];
        }
        [session release];
        session = [tmpSession retain];
    }
    else
    {
        [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain code:0
                                               userInfo:[NSDictionary dictionaryWithObject:@"No access token found in the token server response."
                                                                                    forKey:NSLocalizedDescriptionKey]]];
    }

    @synchronized(self)
    {
        [self resetAPIConnection];
        if ([callQueue count] > 0)
        {
            // Some new calls are waiting to be performed
            [self performCalls];
        }
    }
}

- (void)handleUploadResponse
{
    if ([uploadFileQueue count] > 0)
    {
        SBJsonParser *jsonParser = [[[SBJsonParser alloc] init] autorelease];
        NSDictionary *result = [jsonParser objectWithString:[[[NSString alloc] initWithData:uploadResponseData encoding:NSUTF8StringEncoding] autorelease]];
        NSDictionary *uploadInfo = [uploadFileQueue objectAtIndex:0];
        id<DailymotionDelegate> delegate = [uploadInfo objectForKey:@"delegate"];
        if ([result objectForKey:@"url"])
        {
            if ([delegate respondsToSelector:@selector(dailymotion:didUploadFileAtURL:)])
            {
                [delegate dailymotion:self didUploadFileAtURL:[result objectForKey:@"url"]];
            }
        }
        else
        {
            if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
            {
                NSError *error = [NSError errorWithDomain:DailymotionApiErrorDomain code:0
                                                 userInfo:[NSDictionary dictionaryWithObject:@"Invalid upload server response."
                                                                                      forKey:NSLocalizedDescriptionKey]];
                [delegate dailymotion:self didReturnError:error userInfo:nil];
            }
        }
        [uploadFileQueue removeObjectAtIndex:0];
    }

    [self resetUploadConnection];
    if ([uploadFileQueue count] > 0)
    {
        [self performUploads];
    }
}

#pragma mark Dailymotion (public)

- (id)init
{
    if ((self = [super init]))
    {
        self.timeout = 15;
        callNextId = 0;
        callQueue = [[NSMutableDictionary alloc] init];
        uploadFileQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString *)version
{
    return kDMVersion;
}

- (void)setGrantType:(DailymotionGrantType)type withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope
{
    [self setGrantType:type withAPIKey:apiKey secret:apiSecret scope:scope info:nil];
}

- (void)setGrantType:(DailymotionGrantType)type withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope info:(NSDictionary *)info
{
    switch (type)
    {
        case DailymotionNoGrant:
            grantType = DailymotionNoGrant;
            [grantInfo release], grantInfo = nil;
            return;
        case DailymotionGrantTypeToken:
        case DailymotionGrantTypeNone:
            break;
        case DailymotionGrantTypePassword:
            if (![info valueForKey:@"username"] || ![info valueForKey:@"password"])
            {
                [[NSException exceptionWithName:NSInvalidArgumentException
                                         reason:@"Missing grant info for PASSWORD grant type."
                                       userInfo:nil] raise];
            }
            break;
    }

    if (!apiKey || !apiSecret)
    {
        [[NSException exceptionWithName:NSInvalidArgumentException
                                 reason:@"Missing API key/secret."
                               userInfo:nil] raise];
    }

    info = info ? [info mutableCopy] : [[NSMutableDictionary alloc] init];

    [info setValue:apiKey forKey:@"key"];
    [info setValue:apiSecret forKey:@"secret"];
    [info setValue:(scope ? scope : @"") forKey:@"scope"];

    grantType = type;
    grantInfo = [info retain];
}

- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate
{
    [self callMethod:methodName withArguments:arguments delegate:delegate userInfo:nil];
}

- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo
{
    @synchronized(self)
    {
        NSString *callId = [NSString stringWithFormat:@"%d", callNextId++];
        NSMutableDictionary *call = [[NSMutableDictionary alloc] init];
        [call setValue:methodName forKey:@"method"];
        [call setValue:arguments forKey:@"args"];
        [call setValue:delegate forKey:@"delegate"];
        [call setValue:userInfo forKey:@"userInfo"];
        [call setValue:callId forKey:@"id"];
        [callQueue setValue:call forKey:callId];
        [call release];
        if (!apiConnection)
        {
            // Schedule the dequeuing of the calls for the end of the loop if a request is not currently in progress
            [[NSRunLoop mainRunLoop] performSelector:@selector(performCalls)
                                              target:self
                                            argument:nil
                                               order:1000
                                               modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
        }
    }
}

- (void)uploadFile:(NSString *)filePath delegate:(id<DailymotionDelegate>)delegate
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
        {
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:@"File does not exists.", NSLocalizedDescriptionKey, nil];
            NSError *error = [NSError errorWithDomain:DailymotionApiErrorDomain code:404 userInfo:info];
            [delegate dailymotion:self didReturnError:error userInfo:nil];
        }
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setValue:filePath forKey:@"file_path"];
    [userInfo setValue:delegate forKey:@"delegate"];
    [self callMethod:@"file.upload" withArguments:nil delegate:self userInfo:userInfo];
}

- (void)dealloc
{
    [apiConnection cancel];
    [apiConnection release];
    [apiResponseData release];
    [apiResponse release];

    [uploadConnection cancel];
    [uploadConnection release];
    [uploadResponseData release];
    [uploadResponse release];

    [grantInfo release];
    [callQueue release];
    [uploadFileQueue release];
    [session release];
    [super dealloc];
}

#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection == apiConnection)
    {
        apiResponse = [response retain];
        apiResponseData = [[NSMutableData alloc] init];
    }
    else if (connection == uploadConnection)
    {
        uploadResponse = [response retain];
        uploadResponseData = [[NSMutableData alloc] init];
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection == apiConnection)
    {
        [apiResponseData appendData:data];
    }
    else if (connection == uploadConnection)
    {
        [uploadResponseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == uploadConnection && [uploadFileQueue count] > 0)
    {
        id<DailymotionDelegate> delegate = [[uploadFileQueue objectAtIndex:0] objectForKey:@"delegate"];
        if ([delegate respondsToSelector:@selector(dailymotion:didSendFileData:totalBytesWritten:totalBytesExpectedToWrite:)])
        {
            [delegate dailymotion:self didSendFileData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
        }
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == apiConnection)
    {
        switch (currentState)
        {
            case DailymotionStateAPIRequest:
                [self handleAPIResponse];
                break;
            case DailymotionStateOAuthRequest:
                [self handleOAuthResponse];
                break;
            case DailymotionStateNone:
                [self resetAPIConnection];
                [[NSException exceptionWithName:@"InvalidStateException"
                                         reason:@"Received response with state=none" userInfo:nil] raise];
        }
    }
    else if (connection == uploadConnection)
    {
        [self handleUploadResponse];
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)connectionError
{
    NSError *error = [NSError errorWithDomain:DailymotionTransportErrorDomain
                                         code:[connectionError code]
                                     userInfo:[connectionError userInfo]];

    if (connection == apiConnection)
    {
        [self raiseGlobalError:error];
    }
    else if (connection == uploadConnection)
    {
        if ([uploadFileQueue count] > 0)
        {
            id<DailymotionDelegate> delegate = [[uploadFileQueue objectAtIndex:0] objectForKey:@"delegate"];
            if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
            {
                [delegate dailymotion:self didReturnError:error userInfo:nil];
            }
            [uploadFileQueue removeObjectAtIndex:0];
        }

        [self resetUploadConnection];
        if ([uploadFileQueue count] > 0)
        {
            [self performUploads];
        }

    }
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

#pragma mark DailymotionDelegate
// Delegate for uploadFile workflow

- (void)dailymotion:(Dailymotion *)dailymotion didReturnResult:(id)result userInfo:(NSDictionary *)userInfo
{
    NSMutableDictionary *uploadInfo = [userInfo mutableCopy];
    [uploadInfo setValue:[NSURL URLWithString:[result valueForKey:@"upload_url"]] forKey:@"upload_url"];
    [uploadFileQueue addObject:uploadInfo];
    [uploadInfo release];
    [self performUploads];
}

- (void)dailymotion:(Dailymotion *)dailymotion didReturnError:(NSError *)error userInfo:(NSDictionary *)userInfo
{
    id<DailymotionDelegate> delegate = [userInfo objectForKey:@"delegate"];
    if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
    {
        [delegate dailymotion:dailymotion didReturnError:error userInfo:nil];
    }
}

- (void)dailymotion:(Dailymotion *)dailymotion didRequestAuthWithMessage:(NSString *)message userInfo:(NSDictionary *)userInfo
{
    id<DailymotionDelegate> delegate = [userInfo objectForKey:@"delegate"];
    if ([delegate respondsToSelector:@selector(dailymotion:didRequestAuthWithMessage:userInfo:)])
    {
        [delegate dailymotion:dailymotion didRequestAuthWithMessage:message userInfo:nil];
    }
}

@end
