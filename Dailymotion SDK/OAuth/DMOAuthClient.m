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

@end


@implementation DMOAuthClient
{
    BOOL sessionLoaded;
    NSDictionary *grantInfo;
    DMOAuthSession *_session;
}

@synthesize networkQueue = _networkQueue;
@synthesize oAuthAuthorizationEndpointURL = _oAuthAuthorizationEndpointURL;
@synthesize oAuthTokenEndpointURL = _oAuthTokenEndpointURL;
@synthesize requestQueue = _requestQueue;
@synthesize grantType = _grantType;
@synthesize autoSaveSession = _autoSaveSession;
@synthesize delegate = _delegate;
@dynamic session;

static char callbackKey;

- (id)init
{
    if ((self = [super init]))
    {
        self.oAuthAuthorizationEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/authorize"];
        self.oAuthTokenEndpointURL = [NSURL URLWithString:@"https://api.dailymotion.com/oauth/token"];
        self.networkQueue = [[DMNetworking alloc] init];
        self.requestQueue = [[NSOperationQueue alloc] init];
        sessionLoaded = NO;
        self.autoSaveSession = YES;
    }
    return self;
}

- (void)dealloc
{
    [_requestQueue cancelAllOperations];
    [_networkQueue cancelAllConnections];
}

- (DMOAuthRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    DMOAuthRequestOperation *request = [[DMOAuthRequestOperation alloc] initWithURL:URL
                                                                             method:method
                                                                            payload:payload
                                                                       networkQueue:self.networkQueue completionHandler:handler];

    NSString *accessToken = self.session.accessToken;
    if (self.grantType == DailymotionNoGrant)
    {
        // No authentication requested, just forward
    }
    else if (accessToken)
    {
        // Authentication requeseted and own a valid access token, perform the request by adding the token in the Authorization header
        request.accessToken = accessToken;
    }
    else
    {
        // OAuth authentication is require but no valid access token is found, request a new one and postpone calls.
        // NOTE: if several requests are performed before the access token is returned, they are postponed and called
        // all at once once the token server answered
        self.requestQueue.suspended = YES;

        __unsafe_unretained DMOAuthClient *bself = self;
        [self requestAccessTokenWithCompletionHandler:^(NSString *newAccessToken, NSError *error)
        {
            if (error)
            {
                [bself.requestQueue.operations makeObjectsPerformSelector:@selector(cancelWithError:) withObject:error];
            }
            else
            {
                [bself.requestQueue.operations makeObjectsPerformSelector:@selector(setAccessToken:) withObject:newAccessToken];
            }

            bself.requestQueue.suspended = NO;
        }];
    }

    [self.requestQueue addOperation:request];

    return request;
}

- (void)requestAccessTokenWithCompletionHandler:(void (^)(NSString *, NSError *))handler
{
    if (self.grantType == DailymotionNoGrant)
    {
        // Should never happen but who knows?
        handler(nil, [DMAPIError errorWithMessage:@"Requested an access token with no grant." domain:DailymotionAuthErrorDomain type:nil response:nil data:nil]);
    }

    if (self.session.refreshToken)
    {
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"refresh_token" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
        [payload setObject:self.session.refreshToken forKey:@"refresh_token"];
        [self.networkQueue postURL:self.oAuthTokenEndpointURL payload:payload headers:nil completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
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
    else if (self.grantType == DailymotionGrantTypePassword)
    {
        // Inform delegate to request end-user credentials
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequest:didRequestUserCredentialsWithHandler:), ^(NSString *username, NSString *password)
        {
            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            [payload setObject:@"password" forKey:@"grant_type"];
            [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
            [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
            [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
            [payload setObject:(username ? username : @"") forKey:@"username"];
            [payload setObject:(password ? password : @"") forKey:@"password"];
            [self.networkQueue postURL:self.oAuthTokenEndpointURL
                               payload:payload
                               headers:nil
                     completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
            {
                [self handleOAuthResponse:response data:responseData completionHandler:handler];
            }];
        });
    }
    else
    {
        // Perform token server request
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setObject:@"client_credentials" forKey:@"grant_type"];
        [payload setObject:[grantInfo valueForKey:@"key"] forKey:@"client_id"];
        [payload setObject:[grantInfo valueForKey:@"secret"] forKey:@"client_secret"];
        [payload setObject:[grantInfo valueForKey:@"scope"] forKey:@"scope"];
        [self.networkQueue postURL:self.oAuthTokenEndpointURL payload:payload headers:nil completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
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
        handler(nil, [DMAPIError errorWithMessage:@"Invalid OAuth token server response."
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
            handler(nil, [DMAPIError errorWithMessage:[result valueForKey:@"error_description"]
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
            handler(nil, [DMAPIError errorWithMessage:@"No access token found in the token server response."
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
        handler(nil, [DMAPIError errorWithMessage:@"Invalid session returned by token server."
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
        [self.networkQueue postURL:self.oAuthTokenEndpointURL
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
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequestCloseModalDialog:), nil);
        return NO;
    }
    else if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        DMOAuthPerformMandatoryDelegate(@selector(dailymotionOAuthRequestCloseModalDialog:), nil);
        if ([self.delegate respondsToSelector:@selector(dailymotionOAuthRequest:shouldOpenURLInExternalBrowser:)])
        {
            if ([self.delegate dailymotionOAuthRequest:self shouldOpenURLInExternalBrowser:request.URL])
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
