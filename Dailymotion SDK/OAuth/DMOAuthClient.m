//
//  DMOAuthClient.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthClient.h"
#import "DMAPIError.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

#define DMOAuthPerformMandatoryDelegate(selector, object)\
if ([self.delegate respondsToSelector:selector])\
{\
    [self.delegate performSelector:selector withObject:self withObject:object];\
}\
else\
{\
    NSString *currentGrantType = nil;\
    switch (self.grantType)\
    {\
        case DailymotionGrantTypePassword: currentGrantType = @"DailymotionGrantTypePassword"; break;\
        case DailymotionGrantTypeAuthorization: currentGrantType = @"DailymotionGrantTypeAuthorization"; break;\
        case DailymotionGrantTypeClientCredentials: currentGrantType = @"DailymotionGrantTypeClientCredentials"; break;\
        case DailymotionNoGrant: currentGrantType = @"DailymotionNoGrant"; break;\
    }\
    if (self.delegate)\
    {\
        NSLog(@"*** Dailymotion: Your delegate doesn't implement mandatory %@ method for %@.", NSStringFromSelector(selector), currentGrantType);\
    }\
    else\
    {\
        NSLog(@"*** Dailymotion: You must set a delegate for %@.", currentGrantType);\
    }\
}


@interface DMOAuthClient ()

@property (nonatomic, strong) NSOperationQueue *requestQueue;
@property (nonatomic, readwrite) DailymotionGrantType grantType;
@property (nonatomic, assign) BOOL sessionLoaded;
@property (nonatomic, strong) NSDictionary *grantInfo;
// this credential is used when the server return a 401 asking for an
/// HTTP Digest, so it refers to the API CLIENT id & secret
@property (nonatomic, strong) NSURLCredential *defaultCredential;

@end


@implementation DMOAuthClient {
    DMOAuthSession *_session;
}

static char callbackKey;

- (id)init {
    self = [super init];
    if (self) {
        _oAuthAuthorizationEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/authorize"];
        _oAuthTokenEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/token"];
        _networkQueue = [[DMNetworking alloc] init];
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.name = @"DMOauth Request Queue";
        _sessionLoaded = NO;
        _autoSaveSession = YES;
    }
    return self;
}

- (void)dealloc {
    [_requestQueue cancelAllOperations];
    [_networkQueue cancelAllConnections];
}

- (DMOAuthRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    DMOAuthRequestOperation *request = [[DMOAuthRequestOperation alloc] initWithURL:URL
                                                                             method:method
                                                                            headers:headers
                                                                            payload:payload
                                                                       networkQueue:self.networkQueue completionHandler:handler];

    @synchronized (self) {
        NSString *accessToken = self.session.accessToken;
        if (self.grantType == DailymotionNoGrant) {
            // No authentication requested, just forward
            self.requestQueue.suspended = NO;
            [self.requestQueue addOperation:request];
        }
        else if (accessToken) {
            // Authentication requeseted and own a valid access token, perform the request by adding the token in the Authorization header
            request.accessToken = accessToken;
            self.requestQueue.suspended = NO;
            [self.requestQueue addOperation:request];
        }
        else if (!self.requestQueue.isSuspended) {
            // OAuth authentication is require but no valid access token is found, request a new one and postpone calls.
            // NOTE: if several requests are performed before the access token is returned, they are postponed and called
            // all at once once the token server answered
            self.requestQueue.suspended = YES;
            // Register a watchdog so we don't block all API calls waiting for an ever ending auth request
            [self performSelector:@selector(oAuthWaitTimeout) withObject:nil afterDelay:5];

            __weak DMOAuthClient *wself = self;
            [self requestAccessTokenWithCompletionHandler:^(NSString *newAccessToken, NSError *error) {
                if (!wself) return;
                __strong DMOAuthClient *sself = wself;

                @synchronized (sself) {
                    // Add the initiating operation on top of the queue
                    request.queuePriority = NSOperationQueuePriorityHigh;
                    request.accessToken = newAccessToken;
                    [self.requestQueue addOperation:request];

                    if (error) {
                        [sself.requestQueue.operations makeObjectsPerformSelector:@selector(cancelWithError:) withObject:error];
                    }
                    else {
                        [sself.requestQueue.operations makeObjectsPerformSelector:@selector(setAccessToken:) withObject:newAccessToken];
                    }

                    [NSObject cancelPreviousPerformRequestsWithTarget:sself selector:@selector(oAuthWaitTimeout) object:nil];
                    sself.requestQueue.suspended = NO;
                }
            }];
        }
        else if (self.requestQueue.isSuspended) {
            [self.requestQueue addOperation:request];
        }
    }

    return request;
}

- (void)oAuthWaitTimeout {
    @synchronized (self) {
        self.requestQueue.suspended = NO;
    }
}

- (void)requestAccessTokenWithCompletionHandler:(void (^)(NSString *, NSError *))handler {
    if (self.grantType == DailymotionNoGrant) {
        // Should never happen but who knows?
        handler(nil, [DMAPIError errorWithMessage:@"Requested an access token with no grant." domain:DailymotionAuthErrorDomain type:nil response:nil data:nil]);
    }

    if (self.session.refreshToken) {
        NSDictionary *payload =
                @{
                        @"grant_type" : @"refresh_token",
                        @"client_id" : self.grantInfo[@"key"],
                        @"scope" : self.grantInfo[@"scope"],
                        @"refresh_token" : self.session.refreshToken
                };
        DMNetRequestOperation *op = [self.networkQueue postURL:self.oAuthTokenEndpointURL
                payload:payload
                headers:@{@"Authorization":@"Digest"}
                completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {

            [self handleOAuthResponse:response data:responseData completionHandler:handler];
        }];
        op.credential = self.defaultCredential;
        
        return;
    }

    if (self.grantType == DailymotionGrantTypeAuthorization) {
        // Perform authorization server request
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?response_type=code&client_id=%@&scope=%@&redirect_uri=%@",
                                                                     [self.oAuthAuthorizationEndpointURL absoluteString], self.grantInfo[@"key"],
                                                                     [self.grantInfo[@"scope"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                                                     [kDMOAuthRedirectURI stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
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

        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequest:createModalDialogWithView:), webview);
        // TODO
    }
    else if (self.grantType == DailymotionGrantTypePassword) {
        // Inform delegate to request end-user credentials
        void (^callback)(NSString *, NSString *) = ^(NSString *username, NSString *password) {
            NSDictionary *payload =
                    @{
                            @"grant_type" : @"password",
                            @"client_id" : self.grantInfo[@"key"],
                            @"scope" : self.grantInfo[@"scope"],
                            @"username" : username ? username : @"",
                            @"password" : password ? password : @""
                    };
            DMNetRequestOperation *op = [self.networkQueue postURL:self.oAuthTokenEndpointURL
                               payload:payload
                               headers:@{@"Authorization" : @"Digest"}
                     completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
                         [self handleOAuthResponse:response data:responseData completionHandler:handler];
                     }];
            op.credential = self.defaultCredential;
        };
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequest:didRequestUserCredentialsWithHandler:), callback);
    }
    else {
        // Perform token server request
        NSDictionary *payload =
                @{
                        @"grant_type" : @"client_credentials",
                        @"client_id" : self.grantInfo[@"key"],
                };
        DMNetRequestOperation *op = [self.networkQueue postURL:self.oAuthTokenEndpointURL
                                                       payload:payload
                                                       headers:@{@"Authorization" : @"Digest"}
                                             completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
                                                 [self handleOAuthResponse:response data:responseData completionHandler:handler];
                                             }];

        op.credential = self.defaultCredential;
    }
}

- (void)handleOAuthResponse:(NSURLResponse *)response data:(NSData *)responseData completionHandler:(void (^)(NSString *, NSError *))handler {
    if (!handler) {
        // no-op if handler is not set
        handler = ^(NSString *result, NSError *error) {
        };
    }
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
    if (!result) {
        handler(nil, [DMAPIError errorWithMessage:@"Invalid OAuth token server response."
                                           domain:DailymotionAuthErrorDomain
                                             type:nil
                                         response:response
                                             data:responseData]);

    }
    else if (result[@"error"]) {
        @synchronized (self) {
            if (self.session && [result[@"error"] isEqualToString:@"invalid_grant"]) {
                // If we already have a session and get an invalid_grant, it's certainly because the refresh_token as expired or have been revoked
                // In such case, we restart the authentication by reseting the session
                [self clearSession];
                if ([self.delegate respondsToSelector:@selector(dailymotionOAuthRequestSessionDidExpire:)]) {
                    [self.delegate dailymotionOAuthRequestSessionDidExpire:self];
                }
                [self requestAccessTokenWithCompletionHandler:handler];
            }
            else {
                handler(nil, [DMAPIError errorWithMessage:result[@"error_description"]
                                                   domain:DailymotionAuthErrorDomain
                                                     type:result[@"error"]
                                                 response:response
                                                     data:responseData]);
                self.session = nil;
            }
        }
    }
    else {
        @synchronized (self) {
            if ((self.session = [DMOAuthSession sessionWithSessionInfo:result])) {
                if (!self.session.accessToken) {
                    self.session = nil;
                    handler(nil, [DMAPIError errorWithMessage:@"No access token found in the token server response."
                                                       domain:DailymotionAuthErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData]);
                    return;
                }
                if (self.autoSaveSession) {
                    [self storeSession];
                }
                handler(self.session.accessToken, nil);
            }
            else {
                handler(nil, [DMAPIError errorWithMessage:@"Invalid session returned by token server."
                                                   domain:DailymotionAuthErrorDomain
                                                     type:nil
                                                 response:response
                                                     data:responseData]);
            }
        }
    }
}


- (void)handleOAuthAuthorizationResponseWithURL:(NSURL *)url completionHandler:(void (^)(NSString *, NSError *))handler {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSEnumerator *enumerator = [[url.query componentsSeparatedByString:@"&"] objectEnumerator];
    NSArray *pair;
    while ((pair = [[enumerator nextObject] componentsSeparatedByString:@"="])) {
        if ([pair count] > 1) {
            result[pair[0]] = [pair[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }

    if (result[@"error"]) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:result[@"error"] forKey:@"error"];
        if (result[@"error_description"]) {
            userInfo[NSLocalizedDescriptionKey] = result[@"error_description"];
        }
        handler(nil, [NSError errorWithDomain:DailymotionAuthErrorDomain code:0 userInfo:userInfo]);
    }
    else if (result[@"code"]) {
        NSDictionary *payload =
                @{
                        @"grant_type" : @"authorization_code",
                        @"client_id" : self.grantInfo[@"key"],
                        @"code" : result[@"code"],
                        @"redirect_uri" : kDMOAuthRedirectURI
                };
        DMNetRequestOperation *op = [self.networkQueue postURL:self.oAuthTokenEndpointURL
                           payload:payload
                           headers:@{@"Authorization":@"Digest"}
                 completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
                     [self handleOAuthResponse:response data:responseData completionHandler:handler];
                 }];
        op.credential = self.defaultCredential;
        
    }
    else {
        handler(nil, [NSError errorWithDomain:DailymotionAuthErrorDomain code:0
                                     userInfo:@{NSLocalizedDescriptionKey : @"No code parameter returned by authorization server."}]);
    }
}

#pragma mark public

- (void)setGrantType:(DailymotionGrantType)type withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope {
    NSDictionary *info = nil;

    @synchronized (self) {
        if (type == DailymotionNoGrant) {
            info = nil;
        }
        else {
            if (!apiKey || !apiSecret) {
                [[NSException exceptionWithName:NSInvalidArgumentException
                                         reason:@"Missing API key/secret."
                                       userInfo:nil] raise];
            }

            // Compute a uniq hash key for the current grant type setup
            const char *str = [[NSString stringWithFormat:@"type=%ld&key=%@&secret=%@&scope=%@", type, apiKey, apiSecret, scope] UTF8String];
            unsigned char r[CC_MD5_DIGEST_LENGTH];
            CC_MD5(str, (CC_LONG)strlen(str), r);

            info =
                    @{
                            @"key" : apiKey,
                            @"secret" : apiSecret,
                            @"scope" : (scope ? scope : @""),
                            @"hash" : [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                                                                 r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]]
                    };
        }

        self.grantType = type;
        self.grantInfo = info;
        self.defaultCredential = [NSURLCredential credentialWithUser:info[@"key"]
                                                     password:info[@"secret"]
                                                  persistence:NSURLCredentialPersistenceNone];
        self.session = nil;
        self.requestQueue.suspended = NO;
    }
}

- (void)clearSession {
    if (self.session) {
        NSString *sessionStoreKey = [self sessionStoreKey];
        if (sessionStoreKey) {
            [self.session clearFromKeychainWithIdentifier:sessionStoreKey];
        }

        self.session = nil;
    }
}

- (DMOAuthSession *)session {
    if (!_session && !self.sessionLoaded) {
        [self setSession:[self readSession]];
        self.sessionLoaded = YES; // If read session returns nil, prevent session from trying each time
    }

    return _session;
}

- (void)setSession:(DMOAuthSession *)newSession {
    if (newSession != _session) {
        _session = newSession;
    }
}

- (NSString *)sessionStoreKey {
    if (self.grantType == DailymotionNoGrant || !self.grantInfo[@"hash"]) {
        return nil;
    }
    return [NSString stringWithFormat:@"com.dailymotion.api.%@", self.grantInfo[@"hash"]];
}

- (void)storeSession {
    if (self.session) {
        NSString *sessionStoreKey = [self sessionStoreKey];
        if (sessionStoreKey) {
            [self.session storeInKeychainWithIdentifier:self.sessionStoreKey];
        }
    }
}

- (DMOAuthSession *)readSession {
    NSString *sessionStoreKey = [self sessionStoreKey];
    if (!sessionStoreKey) {
        return nil;
    }

    return [DMOAuthSession sessionFromKeychainIdentifier:sessionStoreKey];
}

// Authorization server workflow

#if TARGET_OS_IPHONE

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.scheme isEqualToString:@"none"]) {
        [self handleOAuthAuthorizationResponseWithURL:request.URL completionHandler:objc_getAssociatedObject(self, &callbackKey)];
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequestCloseModalDialog:), nil);
        return NO;
    }
    else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequestCloseModalDialog:), nil);
        if ([self.delegate respondsToSelector:@selector(dailymotionOAuthRequest:shouldOpenURLInExternalBrowser:)]) {
            if ([self.delegate dailymotionOAuthRequest:self shouldOpenURLInExternalBrowser:request.URL]) {
                [[UIApplication sharedApplication] openURL:request.URL];
            }
        }
        return NO;
    }
    else {
        return YES;
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if ([error code] == 102) // Frame load interrupted by previous delegate method isn't an error
    {
        return;
    }

    void (^handler)(NSString *, NSError *) = objc_getAssociatedObject(self, &callbackKey);
    handler(nil, [NSError errorWithDomain:DailymotionTransportErrorDomain code:[error code] userInfo:[error userInfo]]);
}

#else

#pragma mark WebView (delegate)

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if ([request.URL.scheme isEqualToString:@"none"])
    {
        [self handleOAuthAuthorizationResponseWithURL:request.URL completionHandler:objc_getAssociatedObject(self, &callbackKey)];
        [self performMandatoryDelegateSelector:@selector(dailymotionOAuthRequestCloseModalDialog:) withObject:nil];
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


@end
