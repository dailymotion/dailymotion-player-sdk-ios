//
//  Dailymotion.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "Dailymotion.h"
#import "DMBoundableInputStream.h"
#import <CommonCrypto/CommonDigest.h>

#define kDMOAuthRedirectURI @"none://fake-callback"
#define kDMMaxCallsPerRequest 10

static NSString *WebEndpoint, *APIEndpoint, *OAuthAuthorizeEndpoint, *OAuthTokenEndpoint;

static NSString *const kDMVersion = @"1.4";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";


NSString * const DailymotionTransportErrorDomain = @"DailymotionTransportErrorDomain";
NSString * const DailymotionAuthErrorDomain = @"DailymotionAuthErrorDomain";
NSString * const DailymotionApiErrorDomain = @"DailymotionApiErrorDomain";

@interface Dailymotion ()
@property (nonatomic, readwrite) NSString *version;
@property (nonatomic, readwrite) DailymotionGrantType grantType;
@end

@implementation Dailymotion
{
    DailymotionConnectionState apiConnectionState;
    NSDictionary *grantInfo;
    NSURLConnection *apiConnection, *uploadConnection;
    NSHTTPURLResponse *uploadResponse, *apiResponse;
    NSMutableData *uploadResponseData, *apiResponseData;
    NSMutableDictionary *callQueue;
    NSMutableArray *uploadFileQueue, *queuedCalls, *pendingCalls;
    BOOL sessionLoaded;
    NSUInteger callNextId;
    NSDictionary *_session;
}

@synthesize timeout = _timeout;
@synthesize autoSaveSession = _autoSaveSession;
@synthesize UIDelegate = _UIDelegate;
@synthesize grantType = _grantType;
@synthesize version = _version;
@dynamic session;

+ (void)setWebEndpoint:(NSString *)url
{
    if (WebEndpoint != url)
    {
        WebEndpoint = url;
    }
}
+ (NSString *)WebEndpoint
{
    if (!WebEndpoint) self.WebEndpoint = @"http://www.dailymotion.com";
    return WebEndpoint;
}

+ (void)setAPIEndpoint:(NSString *)url
{
    if (APIEndpoint != url)
    {
        APIEndpoint = url;
    }
}
+ (NSString *)APIEndpoint
{
    if (!APIEndpoint) self.APIEndpoint = @"https://api.dailymotion.com";
    return APIEndpoint;
}

+ (void)setOAuthAuthorizeEndpoint:(NSString *)url
{
    if (OAuthAuthorizeEndpoint != url)
    {
        OAuthAuthorizeEndpoint = url;
    }
}
+ (NSString *)OAuthAuthorizeEndpoint
{
    if (!OAuthAuthorizeEndpoint) self.OAuthAuthorizeEndpoint = @"https://api.dailymotion.com/oauth/authorize";
    return OAuthAuthorizeEndpoint;
}

+ (void)setOAuthTokenEndpoint:(NSString *)url
{
    if (OAuthTokenEndpoint != url)
    {
        OAuthTokenEndpoint = url;
    }
}
+ (NSString *)OAuthTokenEndpoint
{
    if (!OAuthTokenEndpoint) self.OAuthTokenEndpoint = @"https://api.dailymotion.com/oauth/token";
    return OAuthTokenEndpoint;
}

#pragma mark Dailymotion (private)

- (NSString *)userAgent
{
    static NSString *userAgent = nil;
    if (!userAgent)
    {
#if TARGET_OS_IPHONE
        UIDevice *device = [UIDevice currentDevice];
        userAgent = [[NSString alloc] initWithFormat:@"Dailymotion-ObjC/%@ (%@ %@; %@)",
                     kDMVersion, device.systemName, device.systemVersion, device.model];
#else
        SInt32 versionMajor, versionMinor, versionBugFix;
        if (Gestalt(gestaltSystemVersionMajor, &versionMajor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionMinor, &versionMinor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionBugFix, &versionBugFix) != noErr) versionBugFix = 0;
        userAgent = [[NSString alloc] stringWithFormat:@"Dailymotion-ObjC/%@ (Mac OS X %u.%u.%u; Machintosh)",
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
    [request setTimeoutInterval:self.timeout];

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
            NSString *escapedValue = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes
            (
                NULL,
                (__bridge CFStringRef)[payload objectForKey:key],
                NULL,
                CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
                kCFStringEncodingUTF8
            );
            if (!escapedValue)
            {
                escapedValue = @"";
            }
            NSString *data = [NSString stringWithFormat:@"%@=%@%@", key, escapedValue, (i++ < count ?  @"&" : @"")];
            [postData appendData:[data dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [request setHTTPBody:postData];
    }
    else if ([payload isKindOfClass:[NSData class]])
    {
        [request setHTTPBody:payload];
    }
    else if ([payload isKindOfClass:[NSString class]])
    {
        [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else if ([payload isKindOfClass:[NSInputStream class]])
    {
        [request setHTTPBodyStream:payload];
    }

    return [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)resetAPIConnection
{
    [pendingCalls removeAllObjects];
    apiConnectionState = DailymotionConnectionStateNone;
    apiConnection = nil;
    apiResponseData = nil;
    apiResponse = nil;
}

- (void)resetUploadConnection
{
    uploadConnection = nil;
    uploadResponseData = nil;
    uploadResponse = nil;
}

- (void)performMandatoryUIDelegateSelector:(SEL)selector withObject:(id)object
{
    if ([self.UIDelegate respondsToSelector:selector])
    {
        [self.UIDelegate performSelector:selector withObject:self withObject:object];
    }
    else
    {
        NSString *currentGrantType = nil;
        switch (self.grantType)
        {
            case DailymotionGrantTypePassword: currentGrantType = @"DailymotionGrantTypePassword"; break;
            case DailymotionGrantTypeAuthorization: currentGrantType = @"DailymotionGrantTypeAuthorization"; break;
            case DailymotionGrantTypeClientCredentials: currentGrantType = @"DailymotionGrantTypeClientCredentials"; break;
            case DailymotionNoGrant: currentGrantType = @"DailymotionNoGrant"; break;
        }
        if (self.UIDelegate)
        {
            NSLog(@"*** Dailymotion: Your UIDelegate doesn't implement mandatory %@ method for %@.", selector, currentGrantType);
        }
        else
        {
            NSLog(@"*** Dailymotion: You must set a UIDelegate for %@.", currentGrantType);
        }
    }
}

- (NSString *)accessToken
{
    if (self.session)
    {
        NSString *accessToken = [self.session valueForKey:@"access_token"];
        NSDate *expires = [self.session valueForKey:@"expires"];
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
    if (self.grantType == DailymotionNoGrant)
    {
        // Should never happen but who knows?
        [[NSException exceptionWithName:@"InvalidStateException"
                                 reason:@"Requested an access token with no grant" userInfo:nil] raise];
    }

    if (apiConnectionState != DailymotionConnectionStateNone)
    {
        [[NSException exceptionWithName:@"InvalidStateException"
                                 reason:@"Requested an access token with a running connection" userInfo:nil] raise];
    }

    if (self.session)
    {
        NSString *refreshToken = [self.session valueForKey:@"refresh_token"];
        if (refreshToken)
        {
            apiConnectionState = DailymotionConnectionStateOAuthRequest;
            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            [payload setObject:@"refresh_token" forKey:@"grant_type"];
            [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
            [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
            [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
            [payload setObject:refreshToken forKey:@"refresh_token"];
            apiConnection = [self performRequestWithURL:[NSURL URLWithString:Dailymotion.OAuthTokenEndpoint] payload:payload headers:nil];
            return;
        }
    }

    if (self.grantType == DailymotionGrantTypeAuthorization)
    {
        // Perform authorization server request
        apiConnectionState = DailymotionConnectionStateOAuthRequest;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?response_type=code&client_id=%@&scope=%@&redirect_uri=%@",
                                           Dailymotion.OAuthAuthorizeEndpoint, [grantInfo valueForKey:@"key"],
                                           [[grantInfo valueForKey:@"scope"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                           [[NSString stringWithString:kDMOAuthRedirectURI] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];

#if TARGET_OS_IPHONE
        UIWebView *webview = [[UIWebView alloc] init];
        webview.delegate = self;
        [webview loadRequest:request];
#else
        WebView *webview = [[[WebView alloc] init] autorelease];
        webview.policyDelegate = self;
        webview.resourceLoadDelegate = self;
        [webview.mainFrame loadRequest:request];
#endif

        [self performMandatoryUIDelegateSelector:@selector(dailymotion:createModalDialogWithView:) withObject:webview];
    }
    else if (self.grantType == DailymotionGrantTypePassword)
    {
        // Inform delegate to request end-user credentials
        apiConnectionState = DailymotionConnectionStateOAuthRequest;
        [self performMandatoryUIDelegateSelector:@selector(dailymotionDidRequestUserCredentials:) withObject:nil];
    }
    else
    {
        // Perform token server request
        apiConnectionState = DailymotionConnectionStateOAuthRequest;
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"client_credentials" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
        apiConnection = [self performRequestWithURL:[NSURL URLWithString:Dailymotion.OAuthTokenEndpoint] payload:payload headers:nil];
    }
}

- (void)performCalls
{
    @synchronized(self)
    {
        if (apiConnectionState != DailymotionConnectionStateNone)
        {
            // Another request is currently in progress, wait for its completion before to start a new one.
            // NOTE: the handleAPIResponse will reschedule a new performCalls once completed if there is some waiting calls
            return;
        }

        NSString *accessToken = [self accessToken];
        if (self.grantType != DailymotionNoGrant && !accessToken)
        {
            // OAuth authentication is require but no valid access token is found, request a new one and postpone calls.
            // NOTE: the handleOAuthResponse will reschedule a new performCalls upon auth success
            [self requestAccessToken];
            return;
        }

        NSMutableArray *callsRequest = [[NSMutableArray alloc] init];
        // Process calls in FIFO order
        int_fast8_t total = 0;
        for (NSString *callId in queuedCalls)
        {
            NSDictionary *callInfo = [callQueue objectForKey:callId];
            NSDictionary *call = [NSMutableDictionary dictionary];
            [call setValue:[callInfo valueForKey:@"id"] forKey:@"id"];
            [call setValue:[callInfo valueForKey:@"path"] forKey:@"call"];
            if ([callInfo valueForKey:@"args"])
            {
                [call setValue:[callInfo valueForKey:@"args"] forKey:@"args"];
            }
            [callsRequest addObject:call];
            [pendingCalls addObject:callId];
            if (++total == kDMMaxCallsPerRequest) break;
        }
        [queuedCalls removeObjectsInRange:NSMakeRange(0, total)];

        NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithObject:@"application/json" forKey:@"Content-Type"];
        if (accessToken)
        {
            [headers setValue:[NSString stringWithFormat:@"OAuth2 %@", accessToken] forKey:@"Authorization"];
        }

        apiConnectionState = DailymotionConnectionStateAPIRequest;
        
        apiConnection = [self performRequestWithURL:[NSURL URLWithString:Dailymotion.APIEndpoint]
                                             payload:[NSJSONSerialization dataWithJSONObject:callsRequest options:0 error:NULL]
                                             headers:headers];

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

    DMBoundableInputStream *payload = [[DMBoundableInputStream alloc] init];
    payload.middleStream = fileStream;
    payload.headData = [[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n", kDMBoundary, [filePath lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding];
    payload.tailData = [[NSString stringWithFormat:@"\r\n--%@--\r\n", kDMBoundary] dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [headers setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", kDMBoundary] forKey:@"Content-Type"];
    [headers setValue:[NSString stringWithFormat:@"%d", (fileSize + payload.headData.length + payload.tailData.length)] forKey:@"Content-Length"];

    uploadConnection = [self performRequestWithURL:[uploadInfo objectForKey:@"upload_url"] payload:(NSInputStream *)payload headers:headers];
}

- (void)raiseGlobalError:(NSError *)error
{
    @synchronized(self)
    {
        for (NSString *callId in callQueue)
        {
            NSDictionary *call = [callQueue objectForKey:callId];
            id<DailymotionDelegate> delegate = [call objectForKey:@"delegate"];
            if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
            {
                [delegate dailymotion:self didReturnError:error userInfo:[call valueForKey:@"userInfo"]];
            }
        }
        [queuedCalls removeAllObjects];
        [callQueue removeAllObjects];
        [self resetAPIConnection];
    }
}

- (void)raiseGlobalHTTPErrorMessage:(NSString *)message domain:(NSString *)domain type:(NSString *)type
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (type)
    {
        [userInfo setObject:type forKey:@"error"];
    }
    if (message)
    {
        [userInfo setObject:message forKey:NSLocalizedDescriptionKey];
    }
    if (apiResponse)
    {
        [userInfo setObject:[NSNumber numberWithInt:apiResponse.statusCode] forKey:@"status-code"];

        if ([apiResponse.allHeaderFields valueForKey:@"Content-Type"])
        {
            [userInfo setObject:[apiResponse.allHeaderFields valueForKey:@"Content-Type"] forKey:@"content-type"];
        }
    }
    if (apiResponseData)
    {
        [userInfo setObject:[apiResponseData copy] forKey:@"content-data"];
    }

    [self raiseGlobalError:[NSError errorWithDomain:domain code:0 userInfo:userInfo]];
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
            if ([scanner scanUpToString:@"error=\"" intoString:nil])
            {
                [scanner scanString:@"error=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&error];
            }
            [scanner setScanLocation:0];
            if ([scanner scanUpToString:@"error_description=\"" intoString:nil])
            {
                [scanner scanString:@"error_description=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&message];
            }
        }

        if ([error isEqualToString:@"invalid_token"])
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
            [self raiseGlobalHTTPErrorMessage:message domain:DailymotionAuthErrorDomain type:nil];
            return;
        }
    }

    @synchronized(self)
    {
        NSArray *results = [NSJSONSerialization JSONObjectWithData:apiResponseData options:0 error:NULL];
        if (!results)
        {
            [self raiseGlobalHTTPErrorMessage:@"Invalid API server response." domain:DailymotionApiErrorDomain type:nil];
            return;
        }
        else if ([apiResponse statusCode] != 200)
        {
            [self raiseGlobalHTTPErrorMessage:[NSString stringWithFormat:@"Unknown error: %d.", [apiResponse statusCode]]
                                       domain:DailymotionApiErrorDomain
                                         type:nil];

            return;
        }

        NSDictionary *result;
        for (result in results)
        {
            NSString *callId = nil;

            if ([result isKindOfClass:[NSDictionary class]])
            {
                callId = [result objectForKey:@"id"];
            }

            if (!callId)
            {
                [self raiseGlobalHTTPErrorMessage:@"Invalid server response: missing `id' key." domain:DailymotionApiErrorDomain type:nil];
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

        // Search for pending calls that wouldn't have been answered by this response and inform delegate(s) about the error
        for (NSString *callId in pendingCalls)
        {
            NSDictionary *call = [callQueue objectForKey:callId];
            if (call)
            {
                id delegate = [call objectForKey:@"delegate"];
                NSDictionary *userInfo = [call valueForKey:@"userInfo"];
                NSDictionary *info = [NSDictionary dictionaryWithObject:@"Invalid API server response: no result."
                                                                 forKey:NSLocalizedDescriptionKey];
                NSError *error = [NSError errorWithDomain:DailymotionApiErrorDomain code:0 userInfo:info];
                if ([delegate respondsToSelector:@selector(dailymotion:didReturnError:userInfo:)])
                {
                    [delegate dailymotion:self didReturnError:error userInfo:userInfo];
                }

                [callQueue removeObjectForKey:callId];
            }
        }

        [self resetAPIConnection];

        if ([queuedCalls count] > 0)
        {
            // Some new calls are waiting to be performed
            [self performCalls];
        }
    }
}

- (void)handleOAuthResponse
{
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:apiResponseData options:0 error:NULL];
    if (!result)
    {
        [self raiseGlobalHTTPErrorMessage:@"Invalid OAuth token server response." domain:DailymotionAuthErrorDomain type:nil];
    }
    else if ([result valueForKey:@"error"])
    {
        if (self.session && [[result valueForKey:@"error"] isEqualToString:@"invalid_grant"])
        {
            // If we already have a session and get an invalid_grant, it's certainly because the refresh_token as expired or have been revoked
            // In such case, we restart the authentication by reseting the session
            self.session = nil;
            [self resetAPIConnection];
            [self requestAccessToken];
            return;
        }
        else
        {
            [self raiseGlobalHTTPErrorMessage:[result valueForKey:@"error_description"]
                                       domain:DailymotionAuthErrorDomain
                                         type:[result valueForKey:@"error"]];
            self.session = nil;
            [self resetAPIConnection];
            return;
        }
    }
    else if ([result valueForKey:@"access_token"] && ![[result valueForKey:@"access_token"] isKindOfClass:[NSNull class]])
    {
        NSMutableDictionary *tmpSession = [NSMutableDictionary dictionaryWithObjectsAndKeys:[result valueForKey:@"access_token"], @"access_token", nil];
        if ([result valueForKey:@"expires_in"] && ![[result valueForKey:@"expires_in"] isKindOfClass:[NSNull class]])
        {
            [tmpSession setObject:[NSDate dateWithTimeIntervalSinceNow:[[result valueForKey:@"expires_in"] doubleValue]] forKey:@"expires"];
        }
        if ([result valueForKey:@"refresh_token"] && ![[result valueForKey:@"refresh_token"] isKindOfClass:[NSNull class]])
        {
            [tmpSession setObject:[result valueForKey:@"refresh_token"] forKey:@"refresh_token"];
        }
        if ([result valueForKey:@"scope"] && ![[result valueForKey:@"scope"] isKindOfClass:[NSNull class]])
        {
            [tmpSession setObject:[result valueForKey:@"scope"] forKey:@"scope"];
        }
        self.session = tmpSession;
        if (self.autoSaveSession)
        {
            [self storeSession];
        }
    }
    else
    {
        [self raiseGlobalHTTPErrorMessage:@"No access token found in the token server response." domain:DailymotionAuthErrorDomain type:nil];
    }

    @synchronized(self)
    {
        [self resetAPIConnection];
        if ([queuedCalls count] > 0)
        {
            // Some new calls are waiting to be performed
            [self performCalls];
        }
    }
}

- (void)handleOAuthAuthorizationResponseWithURL:(NSURL *)url
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSEnumerator *enumerator = [[url.query componentsSeparatedByString:@"&"] objectEnumerator];
    NSArray *pair;
    while ((pair = [[enumerator nextObject] componentsSeparatedByString:@"="]))
    {
        if ([pair count] > 1)
        {
            [result setObject:[[pair objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                       forKey:[pair objectAtIndex:0]];
        }
    }

    if ([result valueForKey:@"error"])
    {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[result valueForKey:@"error"] forKey:@"error"];
        if ([result valueForKey:@"error_description"])
        {
            [userInfo setObject:[result valueForKey:@"error_description"] forKey:NSLocalizedDescriptionKey];
        }
        [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain code:0 userInfo:userInfo]];
    }
    else if ([result valueForKey:@"code"])
    {
        apiConnectionState = DailymotionConnectionStateOAuthRequest;
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"authorization_code" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[result valueForKey:@"code"] forKey:@"code"];
        [payload setObject:kDMOAuthRedirectURI forKey:@"redirect_uri"];
        apiConnection = [self performRequestWithURL:[NSURL URLWithString:Dailymotion.OAuthTokenEndpoint] payload:payload headers:nil];
    }
    else
    {
        [self raiseGlobalError:[NSError errorWithDomain:DailymotionAuthErrorDomain code:0
                                               userInfo:[NSDictionary dictionaryWithObject:@"No code parameter returned by authorization server." forKey:NSLocalizedDescriptionKey]]];
    }
}

- (void)handleUploadResponse
{
    if ([uploadFileQueue count] > 0)
    {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:uploadResponseData options:0 error:NULL];
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
        queuedCalls = [[NSMutableArray alloc] init];
        pendingCalls = [[NSMutableArray alloc] init];
        uploadFileQueue = [[NSMutableArray alloc] init];
        sessionLoaded = NO;
        self.autoSaveSession = YES;
    }
    return self;
}

- (NSString *)version
{
    return kDMVersion;
}

- (void)setGrantType:(DailymotionGrantType)type withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope
{
    NSMutableDictionary *info = nil;

    if (type == DailymotionNoGrant)
    {
        info = nil;
    }
    else
    {
        if (!apiKey || !apiSecret)
        {
            [[NSException exceptionWithName:NSInvalidArgumentException
                                     reason:@"Missing API key/secret."
                                   userInfo:nil] raise];
        }

        info = [[NSMutableDictionary alloc] init];

        [info setValue:apiKey forKey:@"key"];
        [info setValue:apiSecret forKey:@"secret"];
        [info setValue:(scope ? scope : @"") forKey:@"scope"];

        // Compute a uniq hash key for the current grant type setup
        const char *str = [[NSString stringWithFormat:@"type=%d&key=%@&secret=%@", type, apiKey, apiSecret] UTF8String];
        unsigned char r[CC_MD5_DIGEST_LENGTH];
        CC_MD5(str, (CC_LONG)strlen(str), r);
        [info setValue:[NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                        r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]]
                forKey:@"hash"];
    }

    self.grantType = type;
    grantInfo = [info copy];
}

- (void)setUsername:(NSString *)username password:(NSString *)password
{
    if (apiConnectionState != DailymotionConnectionStateOAuthRequest || self.grantType != DailymotionGrantTypePassword)
    {
        NSLog(@"*** Dailymotion: Recieved end-user credentials while not requesting it.");
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@"password" forKey:@"grant_type"];
    [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
    [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
    [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
    [payload setObject:username forKey:@"username"];
    [payload setObject:password forKey:@"password"];
    apiConnection = [self performRequestWithURL:[NSURL URLWithString:Dailymotion.OAuthTokenEndpoint] payload:payload headers:nil];
}

- (void)logout
{
    [self request:@"auth.logout" delegate:self];
}

- (void)request:(NSString *)path delegate:(id<DailymotionDelegate>)delegate
{
    [self request:path withArguments:nil delegate:delegate userInfo:nil];
}
- (void)request:(NSString *)path delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo
{
    [self request:path withArguments:nil delegate:delegate userInfo:userInfo];
}
- (void)request:(NSString *)path withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate
{
    [self request:path withArguments:arguments delegate:delegate userInfo:nil];
}
- (void)request:(NSString *)path withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo
{
    @synchronized(self)
    {
        NSString *callId = [NSString stringWithFormat:@"%d", callNextId++];
        NSMutableDictionary *call = [[NSMutableDictionary alloc] init];
        [call setValue:path forKey:@"path"];
        [call setValue:arguments forKey:@"args"];
        [call setValue:delegate forKey:@"delegate"];
        [call setValue:userInfo forKey:@"userInfo"];
        [call setValue:callId forKey:@"id"];
        [callQueue setValue:call forKey:callId];
        [queuedCalls addObject:callId];
        if (apiConnectionState == DailymotionConnectionStateNone)
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

- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate
{
    [self request:methodName withArguments:arguments delegate:delegate userInfo:nil];
}

- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo
{
    [self request:methodName withArguments:arguments delegate:delegate userInfo:userInfo];
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
    [self request:@"file.upload" delegate:self userInfo:userInfo];
}

#if TARGET_OS_IPHONE
- (DailymotionPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params
{
    return [[DailymotionPlayerViewController alloc] initWithVideo:video params:params];
}

- (DailymotionPlayerViewController *)player:(NSString *)video
{
    return [[DailymotionPlayerViewController alloc] initWithVideo:video];
}
#endif

- (void)clearSession
{
    [self setSession:nil];
    [self storeSession];
}

- (NSDictionary *)session
{
    if (!_session && !sessionLoaded)
    {
        // Read the on-disk session if any
        [self setSession:[self readSession]];
        sessionLoaded = YES; // If read session returns nil, prevent session from trying each time
    }

    return _session;
}

- (void)setSession:(NSDictionary *)newSession
{
    if (newSession != _session)
    {
        _session = newSession;
    }
}

- (NSString *)sessionStoreKey
{
    if (self.grantType == DailymotionNoGrant || ![grantInfo valueForKey:@"hash"])
    {
        return nil;
    }
    return [NSString stringWithFormat:@"DMSession.%@", [grantInfo valueForKey:@"hash"]];
}

- (void)storeSession
{
    NSString *sessionStoreKey = [self sessionStoreKey];
    if (!sessionStoreKey)
    {
        return;
    }

    if (self.session)
    {
        [[NSUserDefaults standardUserDefaults] setObject:self.session forKey:sessionStoreKey];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:sessionStoreKey];
    }

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)readSession
{
    NSString *sessionStoreKey = [self sessionStoreKey];
    if (!sessionStoreKey)
    {
        return nil;
    }

    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:sessionStoreKey];
}

- (void)dealloc
{
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];

    [apiConnection cancel];

    [uploadConnection cancel];

    grantInfo = nil;
    callQueue = nil;
    queuedCalls = nil;
    pendingCalls = nil;
    uploadFileQueue = nil;
    self.session = nil;
}

#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection == apiConnection)
    {
        apiResponse = (NSHTTPURLResponse *)response;
        apiResponseData = [[NSMutableData alloc] init];
    }
    else if (connection == uploadConnection)
    {
        uploadResponse = (NSHTTPURLResponse *)response;
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
        switch (apiConnectionState)
        {
            case DailymotionConnectionStateAPIRequest:
                [self handleAPIResponse];
                break;
            case DailymotionConnectionStateOAuthRequest:
                [self handleOAuthResponse];
                break;
            case DailymotionConnectionStateNone:
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
    if ([userInfo objectForKey:@"file_path"])
    {
        // file.upload response
        NSMutableDictionary *uploadInfo = [userInfo mutableCopy];
        [uploadInfo setValue:[NSURL URLWithString:[result valueForKey:@"upload_url"]] forKey:@"upload_url"];
        [uploadFileQueue addObject:uploadInfo];
        [self performUploads];
    }
    else
    {
        // auto.logou response
        self.session = nil;
    }
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

// Authorization server workflow

#if TARGET_OS_IPHONE

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqualToString:@"dailymotion"])
    {
        [self handleOAuthAuthorizationResponseWithURL:request.URL];
        [self performMandatoryUIDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
        return NO;
    }
    else if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [self performMandatoryUIDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
        if ([self.UIDelegate respondsToSelector:@selector(dailymotion:shouldOpenURLInExternalBrowser:)])
        {
            if ([self.UIDelegate dailymotion:self shouldOpenURLInExternalBrowser:request.URL])
            {
                [[UIApplication sharedApplication] openURL:request.URL];
            }
        }
        return NO;
    }
    else
    {
        return YES;
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([error code] == 102) // Frame load interrupted by previous delegate method isn't an error
    {
        return;
    }

    [self raiseGlobalError:[NSError errorWithDomain:DailymotionTransportErrorDomain
                                               code:[error code]
                                           userInfo:[error userInfo]]];
}

#else

#pragma mark WebView (delegate)

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if ([request.URL.scheme isEqualToString:@"dailymotion"])
    {
        [self handleOAuthAuthorizationResponseWithURL:request.URL];
        [self performMandatoryUIDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
        [listener ignore];
    }
    // TODO: detect clicked links
    else
    {
        [listener use];
    }
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
    if ([error code] == 102) // Frame load interrupted by previous delegate method isn't an error
    {
        return;
    }

    [self raiseGlobalError:[NSError errorWithDomain:DailymotionTransportErrorDomain
                                               code:[error code]
                                           userInfo:[error userInfo]]];
}

#endif

@end
