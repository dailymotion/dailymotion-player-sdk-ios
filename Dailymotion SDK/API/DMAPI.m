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

#ifdef __OBJC_GC__
#error Dailymotion SDK does not support Objective-C Garbage Collection
#endif
	
#if !__has_feature(objc_arc)
#error Dailymotion SDK is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define kDMHardMaxCallsPerRequest 10

static NSString *const kDMVersion = @"2.0";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";

@implementation DMAPI
{
    DMNetworking *uploadNetworkQueue;
    DMAPICallQueue *callQueue;
    NSMutableDictionary *callRequest;
    BOOL autoConcurrency;
    NSUInteger _maxConcurrency;
    NSUInteger _maxAggregatedCallCount;
    NSUInteger runningRequestCount;
}

- (id)init
{
    if ((self = [super init]))
    {
        self.APIBaseURL = [NSURL URLWithString:@"https://api.dailymotion.com"];
        uploadNetworkQueue = [[DMNetworking alloc] init];
        uploadNetworkQueue.maxConcurrency = 1;
        uploadNetworkQueue.userAgent = self.userAgent;
        callQueue = [[DMAPICallQueue alloc] init];
        callQueue.delegate = self;
        callRequest = [[NSMutableDictionary alloc] init];
        self.oauth = [[DMOAuthClient alloc] init];
        self.oauth.networkQueue.userAgent = self.userAgent;
        self.timeout = 15;
        autoConcurrency = NO;
        _maxConcurrency = 2; // TODO handle auto setup / network type
        _maxAggregatedCallCount = kDMHardMaxCallsPerRequest;
        runningRequestCount = 0;
    }
    return self;
}

- (void)dealloc
{
    callQueue.delegate = nil;
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
    [uploadNetworkQueue cancelAllConnections];
}

#pragma mark -
#pragma mark API

- (void)dequeueCalls
{
    @synchronized(self)
    {
        while (runningRequestCount < self.maxConcurrency && [[callRequest allKeysForObject:[NSNull null]] count] > 0)
        {
            NSMutableArray *calls = [[NSMutableArray alloc] init];
            // Process calls in FIFO order
            uint_fast8_t total = 0;
            for (NSString *callId in [callRequest allKeysForObject:[NSNull null]])
            {
                DMAPICall *call = [callQueue callWithId:callId];
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
        NSAssert([[callRequest objectForKey:call.callId] isKindOfClass:[NSNull class]], @"Trying to schedule same call twice");
        NSDictionary *callRequestBody = [NSMutableDictionary dictionary];
        [callRequestBody setValue:call.callId forKey:@"id"];
        [callRequestBody setValue:[NSString stringWithFormat:@"%@ %@", call.method, call.path] forKey:@"call"];
        if (call.args)
        {
            [callRequestBody setValue:call.args forKey:@"args"];
        }
        [callRequestBodies addObject:callRequestBody];
    }

    NSMutableDictionary *headers = [NSDictionary dictionaryWithObject:@"application/json" forKey:@"Content-Type"];
    runningRequestCount++;
    DMOAuthRequestOperation *request; 
    request = [self.oauth performRequestWithURL:self.APIBaseURL
                                         method:@"POST"
                                        payload:[NSJSONSerialization dataWithJSONObject:callRequestBodies options:0 error:NULL]
                                        headers:headers
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                              completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError)
    {
        runningRequestCount--;
        [self handleAPIResponse:response data:responseData error:connectionError calls:calls];
    }];

    for (DMAPICall *call in calls)
    {
        [callRequest setObject:request forKey:call.callId];
    }
}

- (void)handleAPIResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)connectionError calls:(NSArray *)calls
{
    if (connectionError)
    {
        NSError *error = [DMAPIError errorWithMessage:connectionError.localizedDescription
                                               domain:DailymotionTransportErrorDomain
                                                 type:nil
                                             response:response
                                                 data:responseData];
        [self raiseErrorToCalls:calls error:error];

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
                self.oauth.session.accessToken = nil;
                // Reschedule calls
                for (DMAPICall *call in calls)
                {
                    [callRequest setObject:[NSNull null] forKey:call.callId];
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
                callId = [result objectForKey:@"id"];
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

            DMAPICall *call = [callQueue removeCallWithId:callId];
            if (!call)
            {
                NSLog(@"DMAPI BUG: API returned a result for an unknown call id: %@", callId);
                continue;
            }

            [callRequest removeObjectForKey:call.callId];

            if (![calls containsObject:call])
            {
                NSLog(@"DMAPI BUG: API returned a result for a existing call id not supposted to be part of this batch request: %@", callId);
            }

            if ([call isCancelled])
            {
                // Just ignore the result
            }
            else if ([result objectForKey:@"error"])
            {
                NSString *code = [[result objectForKey:@"error"] objectForKey:@"code"];
                NSString *message = [[result objectForKey:@"error"] objectForKey:@"message"];

                NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionApiErrorDomain type:code response:response data:responseData];
                call.callback(nil, error);
            }
            else if (![result objectForKey:@"result"])
            {
                NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response: no `result' key found."
                                                       domain:DailymotionApiErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData];
                call.callback(nil, error);
            }
            else
            {
                call.callback([result objectForKey:@"result"], nil);
            }
        }

        // Search for pending calls that wouldn't have been answered by this response and inform delegate(s) about the error
        for (DMAPICall *call in calls)
        {
            if ([callQueue removeCall:call])
            {
                [callRequest removeObjectForKey:call.callId];
                NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response: no result."
                                                       domain:DailymotionApiErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData];
                call.callback(nil, error);
            }
        }
    }
}

- (void)cancelCall:(DMAPICall *)call
{
    id request = [callRequest objectForKey:call.callId];
    if (request)
    {
        if ([request isKindOfClass:[NSNull class]])
        {
            // The call hasn't been sent the the server yet, just forget it
            [callRequest removeObjectForKey:call.callId];
            [callQueue removeCallWithId:call.callId];
        }
        else if ([request isKindOfClass:[DMOAuthRequestOperation class]])
        {
            // The call has been sent to the server, it may be part of a batch request
            BOOL requestCancellable = YES;
            for (NSString *queuedCallId in [callRequest allKeysForObject:request])
            {
                DMAPICall *queuedCall = [callQueue callWithId:queuedCallId];
                NSAssert(queuedCall != nil, @"Request to cancel is present in the queue");
                if (queuedCall != call && ![queuedCall isCancelled])
                {
                    requestCancellable = NO;
                    break;
                }
            }

            if (requestCancellable)
            {
                // All sibbling calls of the cancelled call request batch are cancelled
                // => we can cancel the whole request
                [(DMOAuthRequestOperation *)request cancel];
            }
            else
            {
                // Some calls sibbling calls in the same batch request are not cancelled
                // => the cancelled call will be ignored on result
                // nothing to do here
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
            if ([callQueue removeCall:call])
            {
                [callRequest removeObjectForKey:call.callId];
                call.callback(nil, error);
            }
        }
    }
}

- (void)setMaxConcurrency:(NSUInteger)maxConcurrency
{
    _maxConcurrency = maxConcurrency;
    autoConcurrency = NO;
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

- (DMAPICall *)get:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"GET" args:nil callback:callback];
}
- (DMAPICall *)post:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"POST" args:nil callback:callback];
}
- (DMAPICall *)delete:(NSString *)path callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"DELETE" args:nil callback:callback];
}

- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"GET" args:args callback:callback];
}
- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"POST" args:args callback:callback];
}
- (DMAPICall *)delete:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    return [self request:path method:@"DELETE" args:args callback:callback];
}

- (DMAPICall *)request:(NSString *)path method:(NSString *)method args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    DMAPICall *call = [callQueue addCallWithPath:path method:method args:args callback:callback];
    [callRequest setObject:[NSNull null] forKey:call.callId];
    [self scheduleDequeuing];
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

#pragma mark -
#pragma mark Upload

- (DMAPICall *)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite))progress callback:(void (^)(NSString *, NSError*))callback
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        callback(nil, [DMAPIError errorWithMessage:@"File does not exists." domain:DailymotionApiErrorDomain type:@"404" response:nil data:nil]);
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

        DMNetRequestOperation *networkOperation = [uploadNetworkQueue postURL:[NSURL URLWithString:[result objectForKey:@"upload_url"]]
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

#pragma mark -
#pragma mark Player

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

#pragma mark -
#pragma mark Utils

- (void)setTimeout:(NSTimeInterval)timeout
{
    self.oauth.networkQueue.timeout = timeout;
    uploadNetworkQueue.timeout = timeout;
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