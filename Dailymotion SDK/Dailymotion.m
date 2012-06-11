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

#define kDMMaxCallsPerRequest 10

static NSString *const kDMVersion = @"1.4";
static NSString *const kDMBoundary = @"eWExXwkiXfqlge7DizyGHc8iIxThEz4c1p8YB33Pr08hjRQlEyfsoNzvOwAsgV0C";

@implementation Dailymotion
{
    DMNetworking *uploadNetworkQueue;
    NSMutableDictionary *callQueue;
    NSMutableArray *queuedCalls;
    NSUInteger callNextId;
}

@synthesize APIBaseURL = _APIBaseURL;
@synthesize oauth = _oauth;
@dynamic version;
@dynamic timeout;

- (id)init
{
    if ((self = [super init]))
    {
        self.APIBaseURL = [NSURL URLWithString:@"https://api.dailymotion.com"];
        callNextId = 0;
        uploadNetworkQueue = [[DMNetworking alloc] init];
        uploadNetworkQueue.maxConcurrency = 1;
        callQueue = [[NSMutableDictionary alloc] init];
        queuedCalls = [[NSMutableArray alloc] init];
        self.oauth = [[DMOAuthRequest alloc] init];
        self.oauth.networkQueue.maxConcurrency = 2; // TODO handle network type
        self.timeout = 15;
    }
    return self;
}

- (void)dealloc
{
    [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
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
    [self.oauth performRequestWithURL:self.APIBaseURL
                               method:@"POST"
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
        NSError *error = [DMAPIError errorWithMessage:connectionError.localizedDescription
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
                self.oauth.session.accessToken = nil;
                [self performCalls:callIds]; // TODO: infinit loop prevention
                return;
            }
        }
        else
        {
            NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionAuthErrorDomain type:type response:response data:responseData];
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
            NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response." domain:DailymotionApiErrorDomain type:nil response:response data:responseData];
            [self raiseErrorToCalls:callIds error:error];
            return;
        }
        else if (httpResponse.statusCode != 200)
        {
            NSError *error = [DMAPIError errorWithMessage:[NSString stringWithFormat:@"Unknown error: %d.", httpResponse.statusCode]
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
                NSError *error = [DMAPIError errorWithMessage:@"Invalid server response: missing `id' key."
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

                NSError *error = [DMAPIError errorWithMessage:message domain:DailymotionApiErrorDomain type:code response:response data:responseData];
                callback(nil, error);
            }
            else if (![result objectForKey:@"result"])
            {
                NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response: no `result' key found."
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
                NSError *error = [DMAPIError errorWithMessage:@"Invalid API server response: no result."
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
                NSError *uploadError = [DMAPIError errorWithMessage:@"Invalid upload server response."
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

@end
