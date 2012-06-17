//
//  DMNetworking.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 08/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMNetworking.h"
#import "DMUDID.h"

NSUInteger totalRequestCount;

@interface DMNetworking ()

@property (nonatomic, strong) NSOperationQueue *_queue;

@end


@implementation DMNetworking

+ (void)initialize
{
    totalRequestCount = 0;
}

+ (NSUInteger)totalRequestCount
{
    return totalRequestCount;
}

- (id)init
{
    if ((self = [super init]))
    {
        self._queue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)setMaxConcurrency:(NSUInteger)maxConcurrency
{
    self._queue.maxConcurrentOperationCount = maxConcurrency;
}

- (NSUInteger)maxConcurrency
{
    return self._queue.maxConcurrentOperationCount;
}

- (void)cancelAllConnections
{
    [self._queue cancelAllOperations];
}

- (DMNetRequestOperation *)getURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"GET" payload:nil headers:nil cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"GET" payload:nil headers:headers cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"POST" payload:payload headers:nil cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"POST" payload:payload headers:headers cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"PUT" payload:payload headers:nil cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"PUT" payload:payload headers:headers cachePolicy:0 completionHandler:handler];
}


- (DMNetRequestOperation *)deleteURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"DELETE" payload:nil headers:nil cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    return [self performRequestWithURL:URL method:@"DELETE" payload:nil headers:headers cachePolicy:0 completionHandler:handler];
}

- (DMNetRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setHTTPMethod:method];
    [request setAllHTTPHeaderFields:headers];
    [request addValue:[DMUDID deviceIdentifier] forHTTPHeaderField:@"X-DeviceId"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setTimeoutInterval:self.timeout];
    [request setCachePolicy:cachePolicy];

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
                (__bridge CFStringRef)payload[key],
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

    totalRequestCount++;
    DMNetRequestOperation *operation = [[DMNetRequestOperation alloc] initWithRequest:request];
    operation.completionHandler = handler;
    [self._queue addOperation:operation];
    return operation;
}

@end
