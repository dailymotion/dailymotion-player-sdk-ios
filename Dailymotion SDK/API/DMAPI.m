//
//  DMAPI.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMAPI.h"
#import "DMRangeInputStream.h"

#ifdef __OBJC_GC__
#error Dailymotion SDK does not support Objective-C Garbage Collection
#endif

#if !__has_feature(objc_arc)
#error Dailymotion SDK is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#error Dailymotion doesn't support Deployement Target version < 5.0
#endif

#define isdict(dict) [dict isKindOfClass :[NSDictionary class]]

#define kDMHardMaxCallsPerRequest 10

static NSString *const kDMVersion = @"2.0.2";

@interface DMAPITransfer (Private)

@property (nonatomic, copy) void (^completionHandler)(id result, NSError *error);
@property (nonatomic, copy) void (^cancelBlock)();
@property (nonatomic, readwrite) NSURL *localURL;
@property (nonatomic, readwrite) NSURL *remoteURL;

@end


@interface DMAPI ()

@property (nonatomic, readwrite, assign) DMNetworkStatus currentReachabilityStatus;
@property (nonatomic, strong) DMReachability *reach;
@property (nonatomic, strong) DMNetworking *uploadNetworkQueue;
@property (nonatomic, strong) DMAPICallQueue *callQueue;
@property (nonatomic, assign) BOOL autoConcurrency;
@property (nonatomic, assign) BOOL autoChunkSize;
@property (nonatomic, strong) NSMutableDictionary *globalParameters;

@end


@implementation DMAPI {
    NSUInteger _maxConcurrency;
    NSUInteger _maxAggregatedCallCount;
    NSURL *_APIBaseURL;
}

+ (DMAPI *)sharedAPI {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = self.new;
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:DMReachabilityChangedNotification
                                                   object:nil];

        _APIBaseURL = [NSURL URLWithString:@"https://api.dailymotion.com"];
        _autoChunkSize = YES;
        _uploadChunkSize = 100000;
        _autoConcurrency = YES;
        _maxConcurrency = 2;
        self.reach = [DMReachability reachabilityWithHostname:_APIBaseURL.host];
        _currentReachabilityStatus = self.reach.currentReachabilityStatus;
        [self.reach startNotifier];
        _uploadNetworkQueue = [[DMNetworking alloc] init];
        _uploadNetworkQueue.maxConcurrency = 1;
        _uploadNetworkQueue.userAgent = self.userAgent;
        _callQueue = [[DMAPICallQueue alloc] init];
        [_callQueue addObserver:self forKeyPath:@"count" options:0 context:NULL];
        _oauth = [[DMOAuthClient alloc] init];
        _oauth.networkQueue.userAgent = self.userAgent;
        _maxAggregatedCallCount = kDMHardMaxCallsPerRequest;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    return DMAPI.sharedAPI;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    NSParameterAssert(self == DMAPI.sharedAPI);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
    [self.uploadNetworkQueue cancelAllConnections];
    [_callQueue removeObserver:self forKeyPath:@"count"];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    DMReachability *reach = notification.object;
    if (self.reach != reach) {
        return;
    }

    switch (self.reach.currentReachabilityStatus) {
        case DMReachableViaWiFi:
#ifdef DEBUG
            NSLog(@"Dailymotion API is reachable via Wifi");
#endif
            if (self.autoConcurrency) _maxConcurrency = 6;
            if (self.autoChunkSize) _uploadChunkSize = 1000000;
            break;

        case DMReachableViaWWAN:
#ifdef DEBUG
            NSLog(@"Dailymotion API is reachable via cellular network");
#endif
            if (self.autoConcurrency) _maxConcurrency = 2;
            if (self.autoChunkSize) _uploadChunkSize = 100000;
            break;

        case DMNotReachable:
#ifdef DEBUG
            NSLog(@"Dailymotion API is not reachable");
#endif
            break;
    }

    self.currentReachabilityStatus = self.reach.currentReachabilityStatus;
}

#pragma mark - API

- (void)dequeueCalls {
    @synchronized (self) {
        while ([[self.callQueue handlersOfKind:[DMOAuthRequestOperation class]] count] < self.maxConcurrency && [self.callQueue hasUnhandledCalls]) {
            NSMutableArray *calls = [[NSMutableArray alloc] init];
            // Process calls in FIFO order
            uint_fast8_t total = 0;
            for (DMAPICall *call in[self.callQueue callsWithNoHandler]) {
                NSAssert(call != nil, @"Call id from request pool is present in call queue");
                if (![call isCancelled]) {
                    [calls addObject:call];
                    if (++total == self.maxAggregatedCallCount) break;
                }
            }

            if ([calls count] > 0) {
                [self performCalls:calls];
            }
            else {
                break;
            }
        }
    }
}

- (void)performCalls:(NSArray *)calls {
    NSMutableArray *callRequestBodies = [[NSMutableArray alloc] init];

    for (DMAPICall *call in calls) {
        NSMutableDictionary *callRequestBody = [NSMutableDictionary dictionary];
        callRequestBody[@"id"] = call.callId;
        callRequestBody[@"call"] = [NSString stringWithFormat:@"%@ %@", call.method, call.path];
        if (call.args) {
            callRequestBody[@"args"] = call.args;
        }
        if (call.cacheInfo && call.cacheInfo.etag) {
            callRequestBody[@"etag"] = call.cacheInfo.etag;
        }
        [callRequestBodies addObject:callRequestBody];
    }

    DMOAuthRequestOperation *request;
    request = [self.oauth performRequestWithURL:self.APIBaseURL
                                         method:@"POST"
                                        payload:[NSJSONSerialization dataWithJSONObject:callRequestBodies options:0 error:NULL]
                                        headers:@{@"Content-Type" : @"application/json"}
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                              completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError) {
                                  [self handleAPIResponse:response data:responseData error:connectionError calls:calls];
                              }];

    for (DMAPICall *call in calls) {
        NSAssert([self.callQueue handleCall:call withHandler:request], @"Call handled by request not already handled");
    }
}

- (void)handleAPIResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)connectionError calls:(NSArray *)calls {
    if (connectionError) {
        NSError *error = [DMAPIError errorWithMessage:connectionError.localizedDescription
                                               domain:DailymotionTransportErrorDomain
                                                 type:[NSNumber numberWithInt:connectionError.code]
                                             response:response
                                                 data:responseData];
        [self raiseErrorToCalls:calls error:error];
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 400 || httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
        NSString *type = nil;
        NSString *message = nil;
        NSString *authenticateHeader = httpResponse.allHeaderFields[@"Www-Authenticate"];

        if (authenticateHeader) {
            NSScanner *scanner = [NSScanner scannerWithString:authenticateHeader];
            if ([scanner scanUpToString:@"error=\"" intoString:nil]) {
                [scanner scanString:@"error=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&type];
            }
            [scanner setScanLocation:0];
            if ([scanner scanUpToString:@"error_description=\"" intoString:nil]) {
                [scanner scanString:@"error_description=\"" intoString:nil];
                [scanner scanUpToString:@"\"" intoString:&message];
            }
        }

        if ([type isEqualToString:@"invalid_token"]) {
            @synchronized (self)     // connection should not be seen nil by other threads before the access_token request
            {
                // Try to refresh the access token
                self.oauth.session.accessToken = nil;
                // Reschedule calls
                for (DMAPICall *call in calls) {
                    [self.callQueue unhandleCall:call];
                }
                [self scheduleDequeuing];
                return;
            }
        }
        else {
            NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionAuthErrorDomain type:type response:response data:responseData];
            [self raiseErrorToCalls:calls error:error];
            return;
        }
    }

    @synchronized (self) {
        NSArray *results = nil;
        if (responseData) {
            NSError *error;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            results = error ? error : [self parseResult:jsonObject];
        }
        if (!results || [results isKindOfClass:NSError.class]) {
            NSDictionary *userInfo;
            if ([results isKindOfClass:NSError.class]) {
                userInfo = @{NSUnderlyingErrorKey : results};
            }
            NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response." domain:DailymotionApiErrorDomain type:nil response:response data:responseData userInfo:userInfo];
            [self raiseErrorToCalls:calls error:error];
            return;
        }
        else if (httpResponse.statusCode != 200) {
            NSError *error = [DMAPIError errorWithMessage:[NSString stringWithFormat:@"Unknown error: %d.", httpResponse.statusCode]
                                                   domain:DailymotionApiErrorDomain
                                                     type:nil
                                                 response:response
                                                     data:responseData];
            [self raiseErrorToCalls:calls error:error];
            return;
        }

        NSDictionary *result;
        for (result in results) {
            NSString *callId = nil;

            if ([result isKindOfClass:[NSDictionary class]]) {
                callId = result[@"id"];
            }

            if (!callId) {
                NSError *error = [DMAPIError errorWithMessage:@"Invalid server response: missing `id' key."
                                                       domain:DailymotionApiErrorDomain
                                                         type:nil
                                                     response:response
                                                         data:responseData];
                [self raiseErrorToCalls:calls error:error];
                return;
            }

            DMAPICall *call = [self.callQueue removeCallWithId:callId];
            if (!call) {
                NSLog(@"DMAPI BUG: API returned a result for an unknown call id: %@", callId);
                continue;
            }

            if (![calls containsObject:call]) {
                NSLog(@"DMAPI BUG: API returned a result for a existing call id not supposted to be part of this batch request: %@", callId);
            }

            NSDictionary *resultData = result[@"result"];
            NSDictionary *resultError = result[@"error"];
            NSDictionary *resultCacheInfo = result[@"cache"];

            if ([call isCancelled]) {
                // Just ignore the result
            }
            else if (isdict(resultError)) {
                NSString *code = result[@"error"][@"code"];
                NSString *message = result[@"error"][@"message"];

                NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionApiErrorDomain type:code response:response data:responseData];
                call.callback(nil, nil, error);
            }
            else if (!isdict(resultData) && !isdict(resultCacheInfo)) {
                NSString *msg;
                if (resultData) {
                    msg = @"Invalid API server response: invalid `result' key.";
                }
                else {
                    msg = @"Invalid API server response: no `result' key found.";
                }
                NSError *error = [DMAPIError errorWithMessage:msg domain:DailymotionApiErrorDomain type:nil response:response data:responseData];
                call.callback(nil, nil, error);
            }
            else {
                DMAPICacheInfo *cacheInfo = nil;
                if (isdict(resultCacheInfo)) {
                    cacheInfo = [[DMAPICacheInfo alloc] initWithCacheInfo:resultCacheInfo fromAPI:self];
                }
                call.callback(isdict(resultData) ? resultData : nil, cacheInfo, nil);
            }
        }

        // Search for pending calls that wouldn't have been answered by this response and inform delegate(s) about the error
        for (DMAPICall *call in calls) {
            if ([self.callQueue removeCall:call]) {
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

- (id)parseResult:(id)result {
    return [self parseResult:result forKey:nil root:YES];
}

- (id)parseResult:(id)result forKey:(NSString *)parentKey root:(BOOL)root {
    if ([result isKindOfClass:NSArray.class]) {
        NSMutableArray *list = [NSMutableArray arrayWithCapacity:[(NSArray *)result count]];
        for (id obj in result) {
            id parsedObj = [self parseResult:obj forKey:parentKey root:NO];
            if ([parsedObj isKindOfClass:NSError.class]) return parsedObj; // bubble errors up
            [list addObject:parsedObj];
        }
        return [NSArray arrayWithArray:list];
    }
    else if ([result isKindOfClass:NSDictionary.class]) {
        __block NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)result count]];
        [(NSDictionary *)result enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            id parsedObj = [self parseResult:obj forKey:key root:NO];
            if ([parsedObj isKindOfClass:NSError.class]) {
                // bubble errors up
                dict = parsedObj;
                *stop = YES;
                return;
            }
            dict[key] = parsedObj;
        }];
        return dict;
    }
    else if (!root) {
        if ([result isKindOfClass:NSString.class]) {
            if ([parentKey hasSuffix:@"_url"] || [parentKey isEqualToString:@"url"]) {
                return [NSURL URLWithString:result];
            }
            else {
                return result;
            }
        }
        else {
            return result;
        }
    }
    else {
        return [NSError errorWithDomain:@"APIParseError" code:0
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Invalid type for root node: %@", [result class]]}]; // Error on root
    }
}

- (void)raiseErrorToCalls:(NSArray *)calls error:(NSError *)error {
    @synchronized (self) {
        for (DMAPICall *call in calls) {
            if ([self.callQueue removeCall:call]) {
                call.callback(nil, nil, error);
            }
        }
    }
}

#pragma mark - Accessors

- (void)setAPIBaseURL:(NSURL *)APIBaseURL {
    if (_APIBaseURL != APIBaseURL) {
        [self.reach stopNotifier];
        self.reach = [DMReachability reachabilityWithHostname:APIBaseURL.host];
        [self.reach startNotifier];

        self.oauth.oAuthAuthorizationEndpointURL = [NSURL URLWithString:[APIBaseURL.absoluteString stringByAppendingString:@"/oauth/authorize"]];
        self.oauth.oAuthTokenEndpointURL = [NSURL URLWithString:[APIBaseURL.absoluteString stringByAppendingString:@"/oauth/token"]];
    }
    _APIBaseURL = APIBaseURL;
}

- (NSURL *)APIBaseURL {
    return _APIBaseURL;
}

- (void)setUploadChunkSize:(NSUInteger)uploadChunkSize {
    _uploadChunkSize = uploadChunkSize;
    self.autoChunkSize = NO;
}

- (void)setMaxConcurrency:(NSUInteger)maxConcurrency {
    _maxConcurrency = maxConcurrency;
    self.autoConcurrency = NO;
}

- (void)setMaxAggregatedCallCount:(NSUInteger)maxAggregatedCallCount {
    _maxAggregatedCallCount = MIN(maxAggregatedCallCount, kDMHardMaxCallsPerRequest);
}

- (NSUInteger)maxAggregatedCallCount {
    return _maxAggregatedCallCount;
}

#pragma mark public

- (void)setValue:(id)value forGlobalParameter:(NSString *)name {
    if (!self.globalParameters) {
        self.globalParameters = NSMutableDictionary.new;
    }

    if (value) {
        self.globalParameters[name] = value;
    }
    else {
        [self removeGlobalParameter:name];
    }
}

- (void)removeGlobalParameter:(NSString *)name {
    if (self.globalParameters) {
        [self.globalParameters removeObjectForKey:name];
        if ([self.globalParameters count] == 0) {
            self.globalParameters = nil;
        }
    }
}

- (id)valueForGlobalParameter:(NSString *)name {
    return self.globalParameters[name];
}

- (DMAPICall *)get:(NSString *)path callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"GET" args:nil cacheInfo:nil callback:callback];
}

- (DMAPICall *)post:(NSString *)path callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"POST" args:nil cacheInfo:nil callback:callback];
}

- (DMAPICall *)delete:(NSString *)path callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"DELETE" args:nil cacheInfo:nil callback:callback];
}

- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"GET" args:args cacheInfo:nil callback:callback];
}

- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"POST" args:args cacheInfo:nil callback:callback];
}

- (DMAPICall *)delete:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback {
    return [self request:path method:@"DELETE" args:args cacheInfo:nil callback:callback];
}

- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback; {
    return [self request:path method:@"GET" args:args cacheInfo:cacheInfo callback:callback];
}

- (DMAPICall *)request:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback {
    if (self.globalParameters) {
        NSMutableDictionary *mergedArgs = [self.globalParameters mutableCopy];
        [mergedArgs addEntriesFromDictionary:args];
        args = mergedArgs;
    }

    DMAPICall *call = [self.callQueue addCallWithPath:path method:method args:args cacheInfo:cacheInfo callback:callback];
    return call;
}

- (void)scheduleDequeuing {
    // Schedule the dequeuing of the calls for the end of the loop if a request is not currently in progress
    NSRunLoop *mainRunloop = [NSRunLoop mainRunLoop];
    [mainRunloop cancelPerformSelector:@selector(dequeueCalls) target:self argument:nil];
    [mainRunloop performSelector:@selector(dequeueCalls) target:self argument:nil order:NSUIntegerMax modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)logout {
    [self get:@"/logout" callback:nil];
    [self.oauth clearSession];
}

#pragma mark - Upload

- (DMAPITransfer *)uploadFileURL:(NSURL *)fileURL withCompletionHandler:(void (^)(id result, NSError *error))completionHandler {
    NSParameterAssert([fileURL.scheme isEqualToString:@"file"]);

    DMAPITransfer *uploadOperation = [[DMAPITransfer alloc] init];
    uploadOperation.localURL = fileURL;
    uploadOperation.completionHandler = completionHandler;

    if (![NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        if (uploadOperation.completionHandler) {
            uploadOperation.completionHandler(nil, [DMAPIError errorWithMessage:@"File does not exists." domain:DailymotionApiErrorDomain type:@404 response:nil data:nil]);
        }
        return uploadOperation;
    }

    DMAPICall *apiCall = [self get:@"/file/upload" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        if (!error) {
            NSUInteger fileSize = [[[NSFileManager.defaultManager attributesOfItemAtPath:fileURL.path error:&error] objectForKey:NSFileSize] unsignedIntegerValue];
            if (!error && fileSize <= 0) {
                error = [DMAPIError errorWithMessage:@"Can not get file size" domain:DailymotionApiErrorDomain type:@500 response:nil data:nil];
            }
            if (!error) {
                uploadOperation.totalBytesExpectedToTransfer = fileSize;
                uploadOperation.remoteURL = [NSURL URLWithString:[((NSURL *)result[@"upload_url"]).absoluteString stringByReplacingOccurrencesOfString:@"/upload?" withString:@"/rupload?"]];
                uploadOperation.completionHandler = nil;
                [self resumeFileUploadOperation:uploadOperation withCompletionHandler:completionHandler];
            }
        }
        if (error) {
            completionHandler(nil, error);
            uploadOperation.finished = YES;
            uploadOperation.cancelBlock = nil;
            uploadOperation.completionHandler = nil;
        }
    }];

    uploadOperation.cancelBlock = ^{
        [apiCall cancel];
    };

    return uploadOperation;
}

- (void)resumeFileUploadOperation:(DMAPITransfer *)uploadOperation withCompletionHandler:(void (^)(id result, NSError *error))completionHandler {
    uploadOperation.completionHandler = completionHandler;

    // If resumed
    uploadOperation.cancelled = NO;
    uploadOperation.finished = NO;

    NSRange range = NSMakeRange(uploadOperation.totalBytesTransfered, MIN((int)self.uploadChunkSize, uploadOperation.totalBytesExpectedToTransfer - uploadOperation.totalBytesTransfered));
    DMRangeInputStream *filePartStream = [DMRangeInputStream inputStreamWithFileAtPath:uploadOperation.localURL.path withRange:range];

    NSDictionary *headers = @
    {
            @"Content-Type" : @"application/octet-stream",
            @"Content-Length" : [NSString stringWithFormat:@"%d", range.length],
            @"X-Content-Range" : [NSString stringWithFormat:@"bytes %d-%d/%d", range.location, range.location + range.length - 1, uploadOperation.totalBytesExpectedToTransfer],
            @"Session-Id" : uploadOperation.sessionId,
            @"Content-Disposition" : [NSString stringWithFormat:@"attachment; filename=\"%@\"", uploadOperation.localURL.path.lastPathComponent]
    };
    DMNetRequestOperation *networkOperation;
    networkOperation = [self.uploadNetworkQueue postURL:uploadOperation.remoteURL
                                                payload:(NSInputStream *)filePartStream
                                                headers:headers
                                      completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *connectionError) {
                                          if (uploadOperation.isCancelled) {
                                              return;
                                          }

                                          NSUInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
                                          if (connectionError) {
                                              if (uploadOperation.completionHandler) {
                                                  NSError *error = [DMAPIError errorWithMessage:connectionError.localizedDescription
                                                                                         domain:DailymotionTransportErrorDomain
                                                                                           type:[NSNumber numberWithInt:connectionError.code]
                                                                                       response:response
                                                                                           data:responseData];

                                                  uploadOperation.completionHandler(nil, error);
                                              }
                                          }
                                          else if (statusCode == 201) {
                                              NSString *rangeHeader = ((NSHTTPURLResponse *)response).allHeaderFields[@"Range"];
                                              NSScanner *rangeScanner = [NSScanner scannerWithString:rangeHeader];
                                              NSInteger start = -1, end = -1, total = -1;
                                              if (!([rangeScanner scanInt:&start] &&
                                                      [rangeScanner scanString:@"-" intoString:NULL] && [rangeScanner scanInt:&end] &&
                                                      [rangeScanner scanString:@"/" intoString:NULL] && [rangeScanner scanInt:&total])) {
                                                  if (uploadOperation.completionHandler) {
                                                      NSError *error = [DMAPIError errorWithMessage:[NSString stringWithFormat:@"Upload Server Error: cannot parse Range header (%@)", rangeHeader]
                                                                                             domain:DailymotionTransportErrorDomain
                                                                                               type:@400
                                                                                           response:response
                                                                                               data:responseData];

                                                      uploadOperation.completionHandler(nil, error);
                                                  }
                                              }
                                              else {
                                                  if (start == 0) {
                                                      if (uploadOperation.totalBytesExpectedToTransfer != total) {
                                                          NSLog(@"WARN: Upload server changed the expected bytes to transfer");
                                                      }
                                                      if (uploadOperation.totalBytesTransfered + range.length != (NSUInteger)end + 1) {
                                                          NSLog(@"WARN: Upload server returned an unexpected range %d + %d != %d + 1", uploadOperation.totalBytesTransfered, range.length, end);
                                                      }
                                                      uploadOperation.totalBytesTransfered = end + 1;
                                                  }
                                                  else {
                                                      // We don't support discontinious uploads
                                                      NSLog(@"WARN: Upload server returned non-zero start byte, restart upload");
                                                      uploadOperation.totalBytesTransfered = 0;
                                                  }
                                                  [self resumeFileUploadOperation:uploadOperation withCompletionHandler:completionHandler];
                                                  return;
                                              }
                                          }
                                          else if (statusCode == 200) {
                                              if (uploadOperation.completionHandler) {
                                                  NSDictionary *uploadInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
                                                  NSURL *url = uploadInfo[@"url"] && uploadInfo[@"url"] != NSNull.null ? [NSURL URLWithString:uploadInfo[@"url"]] : nil;
                                                  uploadOperation.completionHandler(url, nil);
                                              }
                                          }
                                          else {
                                              if (uploadOperation.completionHandler) {
                                                  NSError *error = [DMAPIError errorWithMessage:@"Upload Server Error."
                                                                                         domain:DailymotionTransportErrorDomain
                                                                                           type:@(statusCode)
                                                                                       response:response
                                                                                           data:responseData];

                                                  uploadOperation.completionHandler(nil, error);
                                              }
                                          }

                                          uploadOperation.finished = YES;
                                          uploadOperation.cancelBlock = nil;
                                          uploadOperation.completionHandler = nil;
                                          networkOperation.progressHandler = nil;
                                      }];

    uploadOperation.cancelBlock = ^{
        [networkOperation cancel];
    };

    networkOperation.progressHandler = ^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
        if (uploadOperation.progressHandler) {
            uploadOperation.progressHandler(bytesWritten, uploadOperation.totalBytesTransfered + totalBytesWritten, uploadOperation.totalBytesExpectedToTransfer);
        }
    };
}

#pragma mark - Player

#if TARGET_OS_IPHONE
- (DMPlayerViewController *)playerWithVideo:(NSString *)video params:(NSDictionary *)params {
    return [[DMPlayerViewController alloc] initWithVideo:video params:params];
}

- (DMPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params __attribute__((deprecated)) {
    return [self playerWithVideo:(NSString *)video params:(NSDictionary *)params];
}

- (DMPlayerViewController *)playerWithVideo:(NSString *)video {
    return [[DMPlayerViewController alloc] initWithVideo:video];
}

- (DMPlayerViewController *)player:(NSString *)video __attribute__((deprecated)) {
    return [self playerWithVideo:(NSString *)video];
}

#endif

#pragma mark - Events

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"count"] && [object isKindOfClass:[DMAPICallQueue class]]) {
        [self scheduleDequeuing];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Utils

- (void)setTimeout:(NSTimeInterval)timeout {
    self.oauth.networkQueue.timeout = timeout;
    self.uploadNetworkQueue.timeout = timeout;
}

- (NSTimeInterval)timeout {
    return self.oauth.networkQueue.timeout;
}

- (NSString *)version {
    return kDMVersion;
}

- (NSString *)userAgent {
    static NSString *userAgent = nil;
    if (!userAgent) {
        NSString *appName = NSBundle.mainBundle.infoDictionary[@"CFBundleName"];
        NSString *appVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];

#if TARGET_OS_IPHONE
        UIDevice *device = [UIDevice currentDevice];
        userAgent = [[NSString alloc] initWithFormat:@"%@/%@ Dailymotion-ObjC/%@ (%@ %@; %@)",
                                                     appName, appVersion, kDMVersion, device.systemName, device.systemVersion, device.model];
#else
        SInt32 versionMajor, versionMinor, versionBugFix;
        if (Gestalt(gestaltSystemVersionMajor, &versionMajor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionMinor, &versionMinor) != noErr) versionMajor = 0;
        if (Gestalt(gestaltSystemVersionBugFix, &versionBugFix) != noErr) versionBugFix = 0;
        userAgent = [[NSString alloc] stringWithFormat:@"%@/%@ Dailymotion-ObjC/%@ (Mac OS X %u.%u.%u; Machintosh)",
                     appName, appVersion, kDMVersion, versionMajor, versionMinor, versionBugFix];
#endif
    }
    return userAgent;
}

@end


#import "DMItem.h"
#import "DMItemCollection.h"

@implementation DMAPI (Item)

- (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId {
    return [DMItem itemWithType:type forId:itemId fromAPI:self];
}

- (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params {
    return [DMItemCollection itemCollectionWithType:type forParams:params fromAPI:self];
}

@end
