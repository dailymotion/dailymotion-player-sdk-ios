//
//  DMAPI.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMAPI.h"
#import "DMNetworking.h"
#import "DMBoundableInputStream.h"
#import "DMSubscriptingSupport.h"

#ifdef __OBJC_GC__
#error Dailymotion SDK does not support Objective-C Garbage Collection
#endif

#if !__has_feature(objc_arc)
#error Dailymotion SDK is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#error Dailymotion doesn't support Deployement Target version < 5.0
#endif

#define isdict(dict) [dict isKindOfClass:[NSDictionary class]]

#define kDMHardMaxCallsPerRequest 10

static NSString *const kDMVersion = @"2.0";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";

@interface DMAPI ()

@property (nonatomic, readwrite, assign) DMNetworkStatus currentReachabilityStatus;
@property (nonatomic, strong) DMReachability *_reach;
@property (nonatomic, strong) DMNetworking *_uploadNetworkQueue;
@property (nonatomic, strong) DMAPICallQueue *_callQueue;
@property (nonatomic, assign) BOOL _autoConcurrency;

@end


@implementation DMAPI
{
    NSUInteger _maxConcurrency;
    NSUInteger _maxAggregatedCallCount;
    NSURL *_APIBaseURL;
}

- (id)init
{
    if ((self = [super init]))
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:DMReachabilityChangedNotification
                                                   object:nil];

        _APIBaseURL = [NSURL URLWithString:@"https://api.dailymotion.com"];
        self._reach = [DMReachability reachabilityWithHostname:_APIBaseURL.host];
        [self._reach startNotifier];
        __uploadNetworkQueue = [[DMNetworking alloc] init];
        __uploadNetworkQueue.maxConcurrency = 1;
        __uploadNetworkQueue.userAgent = self.userAgent;
        __callQueue = [[DMAPICallQueue alloc] init];
        [__callQueue addObserver:self forKeyPath:@"count" options:0 context:NULL];
        _oauth = [[DMOAuthClient alloc] init];
        _oauth.networkQueue.userAgent = self.userAgent;
        self.timeout = 15;
        __autoConcurrency = NO;
        _maxConcurrency = 2; // TODO handle auto setup / network type
        _maxAggregatedCallCount = kDMHardMaxCallsPerRequest;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
    [self._uploadNetworkQueue cancelAllConnections];
    [__callQueue removeObserver:self forKeyPath:@"count"];
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    DMReachability *reach = notification.object;
    if (self._reach != reach)
    {
        return;
    }

    if (self._autoConcurrency)
    {
        switch (self._reach.currentReachabilityStatus)
        {
            case DMReachableViaWiFi:
#ifdef DEBUG
                NSLog(@"Dailymotion API is reachable via Wifi");
#endif
                _maxConcurrency = 6;
                break;

            case DMReachableViaWWAN:
#ifdef DEBUG
                NSLog(@"Dailymotion API is reachable via cellular network");
#endif
                _maxConcurrency = 2;
                break;

            case DMNotReachable:
#ifdef DEBUG
                NSLog(@"Dailymotion API is not reachable");
#endif
                break;
        }
    }

    self.currentReachabilityStatus = self._reach.currentReachabilityStatus;
}

#pragma mark - API

- (void)dequeueCalls
{
    @synchronized(self)
    {
        while ([[self._callQueue handlersOfKind:[DMOAuthRequestOperation class]] count] < self.maxConcurrency && [self._callQueue hasUnhandledCalls])
        {
            NSMutableArray *calls = [[NSMutableArray alloc] init];
            // Process calls in FIFO order
            uint_fast8_t total = 0;
            for (DMAPICall *call in [self._callQueue callsWithNoHandler])
            {
                NSAssert(call != nil, @"Call id from request pool is present in call queue");
                if (![call isCancelled])
                {
                    [calls addObject:call];
                    if (++total == self.maxAggregatedCallCount) break;
                }
            }

            if ([calls count] > 0)
            {
                [self performCalls:calls];
            }
            else
            {
                break;
            }
        }
    }
}

- (void)performCalls:(NSArray *)calls
{
    NSMutableArray *callRequestBodies = [[NSMutableArray alloc] init];

    for (DMAPICall *call in calls)
    {
        NSMutableDictionary *callRequestBody = [NSMutableDictionary dictionary];
        callRequestBody[@"id"] = call.callId;
        callRequestBody[@"call"] = [NSString stringWithFormat:@"%@ %@", call.method, call.path];
        if (call.args)
        {
            callRequestBody[@"args"] = call.args;
        }
        if (call.cacheInfo && call.cacheInfo.etag)
        {
            callRequestBody[@"etag"] = call.cacheInfo.etag;
        }
        [callRequestBodies addObject:callRequestBody];
    }

    DMOAuthRequestOperation *request;
    request = [self.oauth performRequestWithURL:self.APIBaseURL
                                         method:@"POST"
                                        payload:[NSJSONSerialization dataWithJSONObject:callRequestBodies options:0 error:NULL]
                                        headers:@{@"Content-Type": @"application/json"}
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                              completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError)
    {
        [self handleAPIResponse:response data:responseData error:connectionError calls:calls];
    }];

    for (DMAPICall *call in calls)
    {
        NSAssert([self._callQueue handleCall:call withHandler:request], @"Call handled by request not already handled");
    }
}

- (void)handleAPIResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)connectionError calls:(NSArray *)calls
{
    if (connectionError)
    {
        NSError *error = [DMAPIError errorWithMessage:connectionError.localizedDescription
                                               domain:DailymotionTransportErrorDomain
                                                 type:[NSNumber numberWithInt:connectionError.code]
                                             response:response
                                                 data:responseData];
        [self raiseErrorToCalls:calls error:error];

    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 400 || httpResponse.statusCode == 401 || httpResponse.statusCode == 403)
    {
        NSString *type = nil;
        NSString *message = nil;
        NSString *authenticateHeader = httpResponse.allHeaderFields[@"Www-Authenticate"];

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
                self.oauth.session.accessToken = nil;
                // Reschedule calls
                for (DMAPICall *call in calls)
                {
                    [self._callQueue unhandleCall:call];
                }
                [self scheduleDequeuing];
                return;
            }
        }
        else
        {
            NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionAuthErrorDomain type:type response:response data:responseData];
            [self raiseErrorToCalls:calls error:error];
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
            NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response." domain:DailymotionApiErrorDomain type:nil response:response data:responseData];
            [self raiseErrorToCalls:calls error:error];
            return;
        }
        else if (httpResponse.statusCode != 200)
        {
            NSError *error = [DMAPIError errorWithMessage:[NSString stringWithFormat:@"Unknown error: %d.", httpResponse.statusCode]
                                                   domain:DailymotionApiErrorDomain
                                                     type:nil
                                                 response:response
                                                     data:responseData];
            [self raiseErrorToCalls:calls error:error];
            return;
        }

        NSDictionary *result;
        for (result in results)
        {
            NSString *callId = nil;

            if ([result isKindOfClass:[NSDictionary class]])
            {
                callId = result[@"id"];
            }

            if (!callId)
            {
                NSError *error = [DMAPIError errorWithMessage:@"Invalid server response: missing `id' key."
                                                       domain:DailymotionApiErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData];
                [self raiseErrorToCalls:calls error:error];
                return;
            }

            DMAPICall *call = [self._callQueue removeCallWithId:callId];
            if (!call)
            {
                NSLog(@"DMAPI BUG: API returned a result for an unknown call id: %@", callId);
                continue;
            }

            if (![calls containsObject:call])
            {
                NSLog(@"DMAPI BUG: API returned a result for a existing call id not supposted to be part of this batch request: %@", callId);
            }

            NSDictionary *resultData = result[@"result"];
            NSDictionary *resultError = result[@"error"];
            NSDictionary *resultCacheInfo = result[@"cache"];

            if ([call isCancelled])
            {
                // Just ignore the result
            }
            else if (isdict(resultError))
            {
                NSString *code = result[@"error"][@"code"];
                NSString *message = result[@"error"][@"message"];

                NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionApiErrorDomain type:code response:response data:responseData];
                call.callback(nil, nil, error);
            }
            else if (!isdict(resultData) && !isdict(resultCacheInfo))
            {

                NSString *msg;
                if (resultData)
                {
                    msg = @"Invalid API server response: invalid `result' key.";
                }
                else
                {
                    msg = @"Invalid API server response: no `result' key found.";
                }
                NSError *error = [DMAPIError errorWithMessage:msg domain:DailymotionApiErrorDomain type:nil response:response data:responseData];
                call.callback(nil, nil, error);
            }
            else
            {
                DMAPICacheInfo *cacheInfo = nil;
                if (isdict(resultCacheInfo))
                {
                    cacheInfo = [[DMAPICacheInfo alloc] initWithCacheInfo:resultCacheInfo fromAPI:self];
                }
                call.callback(isdict(resultData) ? resultData : nil, cacheInfo, nil);
            }
        }

        // Search for pending calls that wouldn't have been answered by this response and inform delegate(s) about the error
        for (DMAPICall *call in calls)
        {
            if ([self._callQueue removeCall:call])
            {
                NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response: no result."
                                                       domain:DailymotionApiErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData];
                call.callback(nil, nil, error);
            }
        }
    }
}

- (void)raiseErrorToCalls:(NSArray *)calls error:(NSError *)error
{
    @synchronized(self)
    {
        for (DMAPICall *call in calls)
        {
            if ([self._callQueue removeCall:call])
            {
                call.callback(nil, nil, error);
            }
        }
    }
}

#pragma mark - Accessors

- (void)setAPIBaseURL:(NSURL *)APIBaseURL
{
    if (_APIBaseURL != APIBaseURL)
    {
        [self._reach stopNotifier];
        self._reach = [DMReachability reachabilityWithHostname:APIBaseURL.host];
        [self._reach startNotifier];
    }
    _APIBaseURL = APIBaseURL;
}

- (NSURL *)APIBaseURL
{
    return _APIBaseURL;
}

- (void)setMaxConcurrency:(NSUInteger)maxConcurrency
{
    _maxConcurrency = maxConcurrency;
    self._autoConcurrency = NO;
}

- (NSUInteger)maxConcurrency
{
    return _maxConcurrency;
}

- (void)setMaxAggregatedCallCount:(NSUInteger)maxAggregatedCallCount
{
    _maxAggregatedCallCount = MIN(maxAggregatedCallCount, kDMHardMaxCallsPerRequest);
}

- (NSUInteger)maxAggregatedCallCount
{
    return _maxAggregatedCallCount;
}

#pragma mark public

- (DMAPICall *)get:(NSString *)path callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"GET" args:nil cacheInfo:nil callback:callback];
}
- (DMAPICall *)post:(NSString *)path callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"POST" args:nil cacheInfo:nil callback:callback];
}
- (DMAPICall *)delete:(NSString *)path callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"DELETE" args:nil cacheInfo:nil callback:callback];
}

- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"GET" args:args cacheInfo:nil callback:callback];
}
- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"POST" args:args cacheInfo:nil callback:callback];
}
- (DMAPICall *)delete:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback
{
    return [self request:path method:@"DELETE" args:args cacheInfo:nil callback:callback];
}

- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;
{
    return [self request:path method:@"GET" args:args cacheInfo:cacheInfo callback:callback];
}

- (DMAPICall *)request:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback
{
    DMAPICall *call = [self._callQueue addCallWithPath:path method:method args:args cacheInfo:cacheInfo callback:callback];
    return call;
}

- (void)scheduleDequeuing
{
    // Schedule the dequeuing of the calls for the end of the loop if a request is not currently in progress
    NSRunLoop *mainRunloop = [NSRunLoop mainRunLoop];
    [mainRunloop cancelPerformSelector:@selector(dequeueCalls) target:self argument:nil];
    [mainRunloop performSelector:@selector(dequeueCalls) target:self argument:nil order:NSUIntegerMax modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)logout
{
    [self get:@"/logout" callback:nil];
}

#pragma mark - Upload

- (DMAPICall *)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite))progress callback:(void (^)(NSString *, NSError*))callback
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        callback(nil, [DMAPIError errorWithMessage:@"File does not exists." domain:DailymotionApiErrorDomain type:@404 response:nil data:nil]);
    }

    [self get:@"/file/upload" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
    {
        NSUInteger fileSize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] objectForKey:NSFileSize] unsignedIntegerValue];
        NSInputStream *fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];

        DMBoundableInputStream *payload = [[DMBoundableInputStream alloc] init];
        payload.middleStream = fileStream;
        payload.headData = [[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n", kDMBoundary, [filePath lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding];
        payload.tailData = [[NSString stringWithFormat:@"\r\n--%@--\r\n", kDMBoundary] dataUsingEncoding:NSUTF8StringEncoding];

        NSDictionary *headers =
        @{
            @"Content-Type": [NSString stringWithFormat:@"multipart/form-data; boundary=%@", kDMBoundary],
            @"Content-Length": [NSString stringWithFormat:@"%d", (fileSize + payload.headData.length + payload.tailData.length)]
        };
        DMNetRequestOperation *networkOperation;
        networkOperation = [self._uploadNetworkQueue postURL:[NSURL URLWithString:result[@"upload_url"]]
                                                     payload:(NSInputStream *)payload
                                                     headers:headers
                                           completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError)
        {
            NSDictionary *uploadInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
            if (uploadInfo[@"url"])
            {
                callback(uploadInfo[@"url"], nil);
            }
            else
            {
                NSError *uploadError = [DMAPIError errorWithMessage:@"Invalid upload server response."
                                                             domain:DailymotionApiErrorDomain
                                                               type:nil
                                                           response:response
                                                               data:responseData];
                callback(nil, uploadError);
            }

        }];

        if (progress)
        {
            networkOperation.progressHandler = progress;
        }
    }];

#warning TODO upload cancelation
    return nil;
}

#pragma mark - Player

#if TARGET_OS_IPHONE
- (DMPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params
{
    return [[DMPlayerViewController alloc] initWithVideo:video params:params];
}

- (DMPlayerViewController *)player:(NSString *)video
{
    return [[DMPlayerViewController alloc] initWithVideo:video];
}
#endif

#pragma mark - Events

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"count"] && [object isKindOfClass:[DMAPICallQueue class]])
    {
        [self scheduleDequeuing];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Utils

- (void)setTimeout:(NSTimeInterval)timeout
{
    self.oauth.networkQueue.timeout = timeout;
    self._uploadNetworkQueue.timeout = timeout;
}

- (NSTimeInterval)timeout
{
    return self.oauth.networkQueue.timeout;
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

@end


#import "DMItem.h"
#import "DMItemCollection.h"

@implementation DMAPI (Item)

- (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId
{
    return [DMItem itemWithType:type forId:itemId fromAPI:self];
}

- (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params
{
    return [DMItemCollection itemCollectionWithType:type forParams:params fromAPI:self];
}

@end
