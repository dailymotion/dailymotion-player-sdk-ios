//
//  Dailymotion.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "Dailymotion.h"
#import "DMNetworking.h"
#import "DMBoundableInputStream.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

#define kDMOAuthRedirectURI @"none://fake-callback"
#define kDMMaxCallsPerRequest 10

static NSString *const kDMVersion = @"1.4";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";


NSString * const DailymotionTransportErrorDomain = @"DailymotionTransportErrorDomain";
NSString * const DailymotionAuthErrorDomain = @"DailymotionAuthErrorDomain";
NSString * const DailymotionApiErrorDomain = @"DailymotionApiErrorDomain";

@interface Dailymotion ()

@property (nonatomic, readwrite) DailymotionGrantType grantType;

@end

@implementation Dailymotion
{
    DMNetworking *apiNetworkQueue, *uploadNetworkQueue;
    NSOperationQueue *oauthWaitingQueue;
    NSError *lastOAuthError;
    NSDictionary *grantInfo;
    NSMutableDictionary *callQueue;
    NSMutableArray *queuedCalls;
    BOOL sessionLoaded;
    DMOAuthSession *_session;
    NSUInteger callNextId;
}

@synthesize APIBaseURL = _APIBaseURL;
@synthesize oAuthAuthorizationEndpointURL = _oAuthAuthorizationEndpointURL;
@synthesize oAuthTokenEndpointURL = _oAuthTokenEndpointURL;
@synthesize grantType = _grantType;
@synthesize autoSaveSession = _autoSaveSession;
@synthesize delegate = _delegate;
@dynamic session;
@dynamic version;
@dynamic timeout;

- (id)init
{
    if ((self = [super init]))
    {
        self.APIBaseURL = [NSURL URLWithString:@"https://api.dailymotion.com"];
        self.oAuthAuthorizationEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/authorize"];
        self.oAuthTokenEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/token"];
        callNextId = 0;
        apiNetworkQueue = [[DMNetworking alloc] init];
        apiNetworkQueue.maxConcurrency = 2;
        uploadNetworkQueue = [[DMNetworking alloc] init];
        uploadNetworkQueue.maxConcurrency = 1;
        self.timeout = 15;
        callQueue = [[NSMutableDictionary alloc] init];
        queuedCalls = [[NSMutableArray alloc] init];
        sessionLoaded = NO;
        self.autoSaveSession = YES;
    }
    return self;
}

- (void)dealloc
{
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
    [apiNetworkQueue cancelAllConnections];
    [uploadNetworkQueue cancelAllConnections];
}

#pragma mark -
#pragma mark API

- (void)dequeueCalls
{
    @synchronized(self)
    {
        while ([queuedCalls count] > 0)
        {
            NSMutableArray *callIds = [[NSMutableArray alloc] init];
            // Process calls in FIFO order
            int_fast8_t total = 0;
            for (NSString *callId in queuedCalls)
            {
                [callIds addObject:callId];
                if (++total == kDMMaxCallsPerRequest) break;
            }
            [queuedCalls removeObjectsInRange:NSMakeRange(0, total)];
            [self performCalls:callIds];
        }
    }
}

- (void)performCalls:(NSArray *)callIds
{
    NSMutableArray *callsRequest = [[NSMutableArray alloc] init];

    for (NSString *callId in callIds)
    {
        NSDictionary *callInfo = [callQueue objectForKey:callId];
        NSDictionary *call = [NSMutableDictionary dictionary];
        [call setValue:[callInfo valueForKey:@"id"] forKey:@"id"];
        [call setValue:[NSString stringWithFormat:@"%@ %@", [callInfo valueForKey:@"method"], [callInfo valueForKey:@"path"]] forKey:@"call"];
        if ([callInfo valueForKey:@"args"])
        {
            [call setValue:[callInfo valueForKey:@"args"] forKey:@"args"];
        }
        [callsRequest addObject:call];
    }

    NSMutableDictionary *headers = [NSDictionary dictionaryWithObject:@"application/json" forKey:@"Content-Type"];
    [self performOAuthRequestWithURL:self.APIBaseURL
                             payload:[NSJSONSerialization dataWithJSONObject:callsRequest options:0 error:NULL]
                             headers:headers
                   completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError)
    {
        [self handleAPIResponse:response data:responseData error:connectionError calls:callIds];
    }];
}

- (void)handleAPIResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)connectionError calls:(NSArray *)callIds
{
    if (connectionError)
    {
        NSError *error = [self buildErrorWithMessage:connectionError.localizedDescription
                                              domain:DailymotionTransportErrorDomain
                                                type:nil
                                            response:response
                                                data:responseData];
        [self raiseErrorToCalls:callIds error:error];

    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 400 || httpResponse.statusCode == 401 || httpResponse.statusCode == 403)
    {
        NSString *type = nil;
        NSString *message = nil;
        NSString *authenticateHeader = [httpResponse.allHeaderFields valueForKey:@"Www-Authenticate"];

        if (authenticateHeader)
        {
            NSScanner *scanner = [NSScanner scannerWithString:authenticateHeader];
            if ([scanner scanUpToString:@"error=\"" intoString:nil])
            {
                [scanner scanString:@"error=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&type];
            }
            [scanner setScanLocation:0];
            if ([scanner scanUpToString:@"error_description=\"" intoString:nil])
            {
                [scanner scanString:@"error_description=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&message];
            }
        }

        if ([type isEqualToString:@"invalid_token"])
        {
            @synchronized(self) // connection should not be seen nil by other threads before the access_token request
            {
                // Try to refresh the access token
                self.session.accessToken = nil;
                [self performCalls:callIds]; // TODO: infinit loop prevention
                return;
            }
        }
        else
        {
            NSError *error = [self buildErrorWithMessage:message domain:DailymotionAuthErrorDomain type:type response:response data:responseData];
            [self raiseErrorToCalls:callIds error:error];
            return;
        }
    }

    @synchronized(self)
    {
        NSArray *results = nil;
        if (responseData)
        {
            results = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
        }
        if (!results)
        {
            NSError *error = [self buildErrorWithMessage:@"Invalid API server response." domain:DailymotionApiErrorDomain type:nil response:response data:responseData];
            [self raiseErrorToCalls:callIds error:error];
            return;
        }
        else if (httpResponse.statusCode != 200)
        {
            NSError *error = [self buildErrorWithMessage:[NSString stringWithFormat:@"Unknown error: %d.", httpResponse.statusCode]
                                                  domain:DailymotionApiErrorDomain
                                                    type:nil
                                                response:response
                                                    data:responseData];
            [self raiseErrorToCalls:callIds error:error];
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
                NSError *error = [self buildErrorWithMessage:@"Invalid server response: missing `id' key."
                                                      domain:DailymotionApiErrorDomain
                                                        type:nil
                                                    response:response
                                                        data:responseData];
                [self raiseErrorToCalls:callIds error:error];
                return;
            }

            NSDictionary *call = [callQueue objectForKey:callId];
            void (^callback)(id, NSError *) = [call objectForKey:@"callback"];
            [callQueue removeObjectForKey:callId];

            if ([result objectForKey:@"error"])
            {
                NSString *code = [[result objectForKey:@"error"] objectForKey:@"code"];
                NSString *message = [[result objectForKey:@"error"] objectForKey:@"message"];

                NSError *error = [self buildErrorWithMessage:message domain:DailymotionApiErrorDomain type:code response:response data:responseData];
                callback(nil, error);
            }
            else if (![result objectForKey:@"result"])
            {
                NSError *error = [self buildErrorWithMessage:@"Invalid API server response: no `result' key found."
                                                      domain:DailymotionApiErrorDomain
                                                        type:nil
                                                    response:response
                                                        data:responseData];
                callback(nil, error);
            }
            else
            {
                callback([result objectForKey:@"result"], nil);
            }
        }

        // Search for pending calls that wouldn't have been answered by this response and inform delegate(s) about the error
        for (NSString *callId in callIds)
        {
            NSDictionary *call = [callQueue objectForKey:callId];
            if (call)
            {
                void (^callback)(id, NSError *) = [call objectForKey:@"callback"];
                NSError *error = [self buildErrorWithMessage:@"Invalid API server response: no result."
                                                      domain:DailymotionApiErrorDomain
                                                        type:nil
                                                    response:response
                                                        data:responseData];
                callback(nil, error);
                [callQueue removeObjectForKey:callId];
            }
        }
    }
}

#pragma mark public

- (void)get:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"GET" args:nil callback:callback];
}
- (void)post:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"POST" args:nil callback:callback];
}
- (void)delete:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"DELETE" args:nil callback:callback];
}

- (void)get:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"GET" args:args callback:callback];
}
- (void)post:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"POST" args:args callback:callback];
}
- (void)delete:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    [self request:path method:@"DELETE" args:args callback:callback];
}

- (void)logout
{
    [self get:@"/logout" callback:nil];
}

- (void)request:(NSString *)path method:(NSString *)method args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    @synchronized(self)
    {
        NSString *callId = [NSString stringWithFormat:@"%d", callNextId++];
        NSMutableDictionary *call = [[NSMutableDictionary alloc] init];
        [call setValue:method forKey:@"method"];
        [call setValue:path forKey:@"path"];
        [call setValue:args forKey:@"args"];
        [call setValue:callback forKey:@"callback"];
        [call setValue:callId forKey:@"id"];
        [callQueue setValue:call forKey:callId];
        [queuedCalls addObject:callId];
        // Schedule the dequeuing of the calls for the end of the loop if a request is not currently in progress
        NSRunLoop *mainRunloop = [NSRunLoop mainRunLoop];
        [mainRunloop cancelPerformSelector:@selector(dequeueCalls) target:self argument:nil];
        [mainRunloop performSelector:@selector(dequeueCalls) target:self argument:nil order:NSUIntegerMax modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
}


#pragma mark -
#pragma mark Upload

- (void)uploadFile:(NSString *)filePath callback:(void (^)(NSString *, NSError*))callback
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        callback(nil, [self buildErrorWithMessage:@"File does not exists." domain:DailymotionApiErrorDomain type:@"404" response:nil data:nil]);
    }

    [self get:@"/file/upload" callback:^(NSDictionary *result, NSError *error)
    {
        NSUInteger fileSize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] objectForKey:NSFileSize] unsignedIntegerValue];
        NSInputStream *fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];

        DMBoundableInputStream *payload = [[DMBoundableInputStream alloc] init];
        payload.middleStream = fileStream;
        payload.headData = [[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n", kDMBoundary, [filePath lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding];
        payload.tailData = [[NSString stringWithFormat:@"\r\n--%@--\r\n", kDMBoundary] dataUsingEncoding:NSUTF8StringEncoding];

        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        [headers setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", kDMBoundary] forKey:@"Content-Type"];
        [headers setValue:[NSString stringWithFormat:@"%d", (fileSize + payload.headData.length + payload.tailData.length)] forKey:@"Content-Length"];

        [uploadNetworkQueue postURL:[NSURL URLWithString:[result objectForKey:@"upload_url"]]
                            payload:(NSInputStream *)payload
                            headers:headers
                  completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError)
        {
            NSDictionary *uploadInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
            if ([uploadInfo objectForKey:@"url"])
            {
                callback([uploadInfo objectForKey:@"url"], nil);
            }
            else
            {
                NSError *uploadError = [self buildErrorWithMessage:@"Invalid upload server response."
                                                            domain:DailymotionApiErrorDomain
                                                              type:nil
                                                          response:response
                                                              data:responseData];
                callback(nil, uploadError);
            }

        }];

    }];
}

#pragma mark -
#pragma mark Player

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

#pragma mark -
#pragma mark oAuth

static char callbackKey;

- (void)performOAuthRequestWithURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    NSString *accessToken = self.session.accessToken;
    if (self.grantType == DailymotionNoGrant)
    {
        // No authentication requested, just forward
        [apiNetworkQueue postURL:URL payload:payload headers:headers completionHandler:handler];
    }
    else if (accessToken)
    {
        // Authentication requeseted and own a valid access token, perform the request by adding the token in the Authorization header
        NSMutableDictionary *mutableHeaders = [headers mutableCopy];
        [mutableHeaders setValue:[NSString stringWithFormat:@"OAuth2 %@", accessToken] forKey:@"Authorization"];
        [apiNetworkQueue postURL:URL payload:payload headers:mutableHeaders completionHandler:handler];
    }
    else
    {
        if (lastOAuthError)
        {
            handler(nil, nil, lastOAuthError);
            return;
        }

        // OAuth authentication is require but no valid access token is found, request a new one and postpone calls.
        // NOTE: if several requests are performed before the access token is returned, they are postponed and called
        // all at once once the token server answered
        BOOL requestToken = NO;
        if (!oauthWaitingQueue)
        {
            oauthWaitingQueue = [[NSOperationQueue alloc] init];
            oauthWaitingQueue.maxConcurrentOperationCount = 1;
            oauthWaitingQueue.suspended = YES;
            requestToken = YES;
        }

        __unsafe_unretained id bself = self;
        [oauthWaitingQueue addOperationWithBlock:^
        {
            // Queue the same call to be executed once the token retrival is done
            [bself performOAuthRequestWithURL:URL payload:payload headers:headers completionHandler:handler];
        }];

        if (requestToken)
        {
            [self requestAccessTokenWithCompletionHandler:^(NSString *newAccessToken, NSError *error)
            {
                lastOAuthError = error;

                // Release all requests waiting for access token
                oauthWaitingQueue.suspended = NO;
                [oauthWaitingQueue waitUntilAllOperationsAreFinished];
                oauthWaitingQueue = nil;
                lastOAuthError = nil;
            }];
        }
    }
}

- (void)requestAccessTokenWithCompletionHandler:(void (^)(NSString *, NSError *))handler
{
    if (self.grantType == DailymotionNoGrant)
    {
        // Should never happen but who knows?
        handler(nil, [self buildErrorWithMessage:@"Requested an access token with no grant." domain:DailymotionAuthErrorDomain type:nil response:nil data:nil]);
    }

    if (self.session.refreshToken)
    {
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"refresh_token" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
        [payload setObject:self.session.refreshToken forKey:@"refresh_token"];
        [apiNetworkQueue postURL:self.oAuthTokenEndpointURL payload:payload headers:nil completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
         {
             [self handleOAuthResponse:response data:responseData completionHandler:handler];
         }];
        return;
    }

    if (self.grantType == DailymotionGrantTypeAuthorization)
    {
        // Perform authorization server request
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?response_type=code&client_id=%@&scope=%@&redirect_uri=%@",
                                           [self.oAuthAuthorizationEndpointURL absoluteString], [grantInfo valueForKey:@"key"],
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
        objc_setAssociatedObject(self, &callbackKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [self performMandatoryDelegateSelector:@selector(dailymotion:createModalDialogWithView:) withObject:webview];
        // TODO
    }
    else if (self.grantType == DailymotionGrantTypePassword)
    {
        // Inform delegate to request end-user credentials
        [self performMandatoryDelegateSelector:@selector(dailymotionDidRequestUserCredentials:handler:) withObject:^(NSString *username, NSString *password)
        {
            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            [payload setObject:@"password" forKey:@"grant_type"];
            [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
            [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
            [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
            [payload setObject:(username ? username : @"") forKey:@"username"];
            [payload setObject:(password ? password : @"") forKey:@"password"];
            [apiNetworkQueue postURL:self.oAuthTokenEndpointURL
                             payload:payload
                             headers:nil
                   completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
            {
                [self handleOAuthResponse:response data:responseData completionHandler:handler];
            }];
        }];
    }
    else
    {
        // Perform token server request
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"client_credentials" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
        [apiNetworkQueue postURL:self.oAuthTokenEndpointURL payload:payload headers:nil completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
        {
            [self handleOAuthResponse:response data:responseData completionHandler:handler];
        }];
    }
}

- (void)handleOAuthResponse:(NSURLResponse *)response data:(NSData *)responseData completionHandler:(void (^)(NSString *, NSError *))handler
{
    if (!handler)
    {
        // no-op if handler is not set
        handler = ^(NSString *result, NSError *error) {};
    }
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
    if (!result)
    {
        handler(nil, [self buildErrorWithMessage:@"Invalid OAuth token server response."
                                          domain:DailymotionAuthErrorDomain
                                            type:nil
                                        response:response
                                            data:responseData]);

    }
    else if ([result valueForKey:@"error"])
    {
        if (self.session && [[result valueForKey:@"error"] isEqualToString:@"invalid_grant"])
        {
            // If we already have a session and get an invalid_grant, it's certainly because the refresh_token as expired or have been revoked
            // In such case, we restart the authentication by reseting the session
            self.session = nil;
            [self requestAccessTokenWithCompletionHandler:handler];
        }
        else
        {
            handler(nil, [self buildErrorWithMessage:[result valueForKey:@"error_description"]
                                              domain:DailymotionAuthErrorDomain
                                                type:[result valueForKey:@"error"]
                                            response:response
                                                data:responseData]);
            self.session = nil;
        }
    }
    else if ((self.session = [DMOAuthSession sessionWithSessionInfo:result]))
    {
        if (!self.session.accessToken)
        {
            self.session = nil;
            handler(nil, [self buildErrorWithMessage:@"No access token found in the token server response."
                                              domain:DailymotionAuthErrorDomain
                                                type:nil
                                            response:response
                                                data:responseData]);
            return;
        }
        if (self.autoSaveSession)
        {
            [self storeSession];
        }
        handler(self.session.accessToken, nil);
    }
    else
    {
        handler(nil, [self buildErrorWithMessage:@"Invalid session returned by token server."
                                          domain:DailymotionAuthErrorDomain
                                            type:nil
                                        response:response
                                            data:responseData]);
    }
}


- (void)handleOAuthAuthorizationResponseWithURL:(NSURL *)url completionHandler:(void (^)(NSString *, NSError *))handler
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
        handler(nil, [NSError errorWithDomain:DailymotionAuthErrorDomain code:0 userInfo:userInfo]);
    }
    else if ([result valueForKey:@"code"])
    {
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"authorization_code" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[result valueForKey:@"code"] forKey:@"code"];
        [payload setObject:kDMOAuthRedirectURI forKey:@"redirect_uri"];
        [apiNetworkQueue postURL:self.oAuthTokenEndpointURL
                         payload:payload
                         headers:nil
               completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
        {
            [self handleOAuthResponse:response data:responseData completionHandler:handler];
        }];
    }
    else
    {
        handler(nil, [NSError errorWithDomain:DailymotionAuthErrorDomain code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"No code parameter returned by authorization server." forKey:NSLocalizedDescriptionKey]]);
    }
}

- (void)performMandatoryDelegateSelector:(SEL)selector withObject:(id)object
{
    if ([self.delegate respondsToSelector:selector])
    {
        [self.delegate performSelector:selector withObject:self withObject:object];
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
        if (self.delegate)
        {
            NSLog(@"*** Dailymotion: Your delegate doesn't implement mandatory %@ method for %@.", selector, currentGrantType);
        }
        else
        {
            NSLog(@"*** Dailymotion: You must set a delegate for %@.", currentGrantType);
        }
    }
}

#pragma mark public

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

- (void)clearSession
{
    if (self.session)
    {
        NSString *sessionStoreKey = [self sessionStoreKey];
        if (sessionStoreKey)
        {
            [self.session clearFromKeychainWithIdentifier:sessionStoreKey];
        }

        self.session = nil;
    }
}

- (DMOAuthSession *)session
{
    if (!_session && !sessionLoaded)
    {
        [self setSession: [self readSession]];
        sessionLoaded = YES; // If read session returns nil, prevent session from trying each time
    }

    return _session;
}

- (void)setSession:(DMOAuthSession *)newSession
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
    return [NSString stringWithFormat:@"com.dailymotion.api.%@", [grantInfo valueForKey:@"hash"]];
}

- (void)storeSession
{
    if (self.session)
    {
        NSString *sessionStoreKey = [self sessionStoreKey];
        if (sessionStoreKey)
        {
            [self.session storeInKeychainWithIdentifier:self.sessionStoreKey];
        }
    }
}

- (DMOAuthSession *)readSession
{
    NSString *sessionStoreKey = [self sessionStoreKey];
    if (!sessionStoreKey)
    {
        return nil;
    }

    return [DMOAuthSession sessionFromKeychainIdentifier:sessionStoreKey];
}

// Authorization server workflow

#if TARGET_OS_IPHONE

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqualToString:@"dailymotion"])
    {
        [self handleOAuthAuthorizationResponseWithURL:request.URL completionHandler:objc_getAssociatedObject(self, &callbackKey)];
        [self performMandatoryDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
        return NO;
    }
    else if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [self performMandatoryDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
        if ([self.delegate respondsToSelector:@selector(dailymotion:shouldOpenURLInExternalBrowser:)])
        {
            if ([self.delegate dailymotion:self shouldOpenURLInExternalBrowser:request.URL])
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

    void (^handler)(NSString*, NSError*) = objc_getAssociatedObject(self, &callbackKey);
    handler(nil, [NSError errorWithDomain:DailymotionTransportErrorDomain code:[error code] userInfo:[error userInfo]]);
}

#else

#pragma mark WebView (delegate)

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if ([request.URL.scheme isEqualToString:@"dailymotion"])
    {
        [self handleOAuthAuthorizationResponseWithURL:request.URL completionHandler:objc_getAssociatedObject(self, &callbackKey)];
        [self performMandatoryDelegateSelector:@selector(dailymotionCloseModalDialog:) withObject:nil];
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

    void (^handler)(NSString*, NSError*) = objc_getAssociatedObject(self, &callbackKey);
    handler(nil, [NSError errorWithDomain:DailymotionTransportErrorDomain code:[error code] userInfo:[error userInfo]]);
}

#endif

#pragma mark -
#pragma mark Utils

- (void)setTimeout:(NSTimeInterval)timeout
{
    apiNetworkQueue.timeout = timeout;
    uploadNetworkQueue.timeout = timeout;
}

- (NSTimeInterval)timeout
{
    return apiNetworkQueue.timeout;
}

- (NSString *)version
{
    return kDMVersion;
}

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

- (void)raiseErrorToCalls:callIds error:(NSError *)error
{
    @synchronized(self)
    {
        for (NSString *callId in callIds)
        {
            NSDictionary *call = [callQueue objectForKey:callId];
            if (call)
            {
                void (^callback)(id, NSError *) = [call objectForKey:@"callback"];
                callback(nil, error);
                [callQueue removeObjectForKey:callId];
            }
        }
    }
}

- (NSError *)buildErrorWithMessage:(NSString *)message domain:(NSString *)domain type:(NSString *)type response:(NSURLResponse *)response data:(NSData *)data
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (type)
    {
        [userInfo setObject:type forKey:@"error"];
    }
    if (message)
    {
        [userInfo setObject:message forKey:NSLocalizedDescriptionKey];
    }
    if (response)
    {
        [userInfo setObject:[NSNumber numberWithInt:httpResponse.statusCode] forKey:@"status-code"];

        if ([httpResponse.allHeaderFields valueForKey:@"Content-Type"])
        {
            [userInfo setObject:[httpResponse.allHeaderFields valueForKey:@"Content-Type"] forKey:@"content-type"];
        }
    }
    if (data)
    {
        [userInfo setObject:[data copy] forKey:@"content-data"];
    }

    NSInteger code = 0;
    if ([type isKindOfClass:[NSNumber class]])
    {
        code = type.intValue;
    }

    return [NSError errorWithDomain:domain code:code userInfo:userInfo];
}

@end
