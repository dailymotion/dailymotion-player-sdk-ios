//
//  DMNetworking.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 08/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMNetworking.h"

@implementation DMNetworking
{
    NSOperationQueue *queue;
}

@synthesize timeout = _timeout;
@synthesize userAgent = _userAgent;
@dynamic maxConcurrency;

- (id)init
{
    if ((self = [super init]))
    {
        queue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)setMaxConcurrency:(NSUInteger)maxConcurrency
{
    queue.maxConcurrentOperationCount = maxConcurrency;
}

- (NSUInteger)maxConcurrency
{
    return queue.maxConcurrentOperationCount;
}

- (void)cancelAllConnections
{
    [queue cancelAllOperations];
}

- (DMNetworkingOperation *)getURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"GET" payload:nil headers:nil dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"GET" payload:nil headers:headers dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"GET" payload:nil headers:headers dependsOn:dependency completionHandler:handler];
}

- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"POST" payload:payload headers:nil dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"POST" payload:payload headers:headers dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"POST" payload:payload headers:headers dependsOn:dependency completionHandler:handler];
}

- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"PUT" payload:payload headers:nil dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"PUT" payload:payload headers:headers dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"PUT" payload:payload headers:headers dependsOn:dependency completionHandler:handler];
}


- (DMNetworkingOperation *)deleteURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"DELETE" payload:nil headers:nil dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"DELETE" payload:nil headers:headers dependsOn:nil completionHandler:handler];
}

- (DMNetworkingOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"DELETE" payload:nil headers:headers dependsOn:dependency completionHandler:handler];
}


- (DMNetworkingOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setHTTPMethod:method];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
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

    DMNetworkingOperation *operation = [[DMNetworkingOperation alloc] initWithRequest:request];
    operation.completionHandler = handler;
    if (dependency)
    {
        [operation addDependency:dependency];
    }
    [queue addOperation:operation];
    return operation;
}

- (DMNetworkingShowstopperOperation *)createShowStopper
{
    DMNetworkingShowstopperOperation *showstopper = [[DMNetworkingShowstopperOperation alloc] init];
    [queue addOperation:showstopper];
    return showstopper;
}

@end


@implementation DMNetworkingOperation
{
    BOOL executing;
    BOOL finished;
    NSMutableData *responseData;
}

@synthesize request = _request;
@synthesize response = _response;
@synthesize error = _error;
@synthesize connection = _connection;
@synthesize completionHandler = _completionHandler;
@synthesize progressHandler = _progressHandler;
@dynamic responseData;

- (id)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init]))
    {
        self.request = request;
        executing = NO;
        finished = NO;
        responseData = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)start
{
    if (self.isCancelled)
    {
        [self willChangeValueForKey:@"isFinished"];
        finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self willChangeValueForKey:@"isExecuting"];
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self.connection start];
        executing = YES;
        [self didChangeValueForKey:@"isExecuting"];
    });
}

- (void)cancel
{
    if (self.isFinished) return;
    [super cancel];
    [self.connection cancel];
    [self done];
}

- (void)done
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(self.response, responseData, self.error);
        self.completionHandler = nil;
    }
    self.progressHandler = nil;
    finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return executing;
}

- (BOOL)isFinished
{
    return finished;
}

- (NSData *)responseData
{
    return responseData;
}

#pragma mark NSURLConnection delegate

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (self.progressHandler)
    {
        self.progressHandler(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.response = response;
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self done];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError *)connectionError
{
    self.error = connectionError;
    [self done];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

@end

@implementation DMNetworkingShowstopperOperation
{
    BOOL finished;
}


- (void)start
{
    // do nothing
}

- (BOOL)isReady
{
    // This operation is not meant to be run but to sit in the queue to let some other
    // operation to depends on it until its there
    return NO;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return NO;
}

- (BOOL)isFinished
{
    return finished;
}

- (void)done
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
