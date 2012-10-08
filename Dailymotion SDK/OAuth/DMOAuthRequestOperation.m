//
//  DMOAuthRequestOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthRequestOperation.h"
#import "DMNetworking.h"
#import "DMSubscriptingSupport.h"

@interface DMOAuthRequestOperation ()

@property (nonatomic, strong, readwrite) NSURL *URL;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, strong, readwrite) NSDictionary *headers;
@property (nonatomic, strong, readwrite) id payload;
@property (nonatomic, strong) DMNetworking *_networkQueue;
@property (nonatomic, strong) DMNetRequestOperation *_request;
@property (nonatomic, assign) BOOL _executing;
@property (nonatomic, assign) BOOL _finished;

@end


@implementation DMOAuthRequestOperation

- (id)initWithURL:(NSURL *)URL method:(NSString *)method headers:(NSDictionary *)headers payload:(id)payload networkQueue:(DMNetworking *)networkQueue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler
{
    if ((self = [super init]))
    {
        _URL = URL;
        _method = method;
        _headers = headers;
        _payload = payload;
        _completionHandler = handler;
        __networkQueue = networkQueue;
        __executing = NO;
        __finished = NO;
    }
    return self;
}

- (void)setProgressHandler:(void (^)(NSInteger, NSInteger, NSInteger))progressHandler
{
    self._request.progressHandler = progressHandler;
}

- (void (^)(NSInteger, NSInteger, NSInteger))progressHandler
{
    return self._request.progressHandler;
}

- (void)start
{
    if (self.isCancelled)
    {
        [self willChangeValueForKey:@"isFinished"];
        self._finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    NSDictionary *headers = self.headers;
    if (self.accessToken)
    {
        if (headers)
        {
            NSMutableDictionary *mutableHeaders = [headers mutableCopy];
            mutableHeaders[@"Authorization"] = [NSString stringWithFormat:@"OAuth2 %@", self.accessToken];
            headers = mutableHeaders;
        }
        else
        {
            headers = @{@"Authorization": [NSString stringWithFormat:@"OAuth2 %@", self.accessToken]};
        }
    }

    [self willChangeValueForKey:@"isExecuting"];
    __weak DMOAuthRequestOperation *wself = self;
    self._request = [self._networkQueue performRequestWithURL:self.URL
                                                       method:self.method
                                                      payload:self.payload
                                                      headers:headers
                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
    {
        if (!wself) return;
        __strong DMOAuthRequestOperation *sself = wself;
        [sself doneWithResponse:response data:responseData error:error];
        sself._request = nil;
    }];
    if (self.progressHandler)
    {
        self._request.progressHandler = self.progressHandler;
    }
    self._executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)cancelWithError:(NSError *)error
{
    if (self.isFinished) return;
    [self cancel];
    if (self.completionHandler)
    {
        self.completionHandler(nil, nil, error);
        self.completionHandler = nil;
    }
}

- (void)cancel
{
    if (self.isFinished) return;
    [super cancel];

    if (self._request)
    {
        [self._request cancel];
        self._request = nil;

        // As we cancelled the request, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (!self.isFinished)
        {
            [self willChangeValueForKey:@"isFinished"];
            self._finished = YES;
            [self didChangeValueForKey:@"isFinished"];
        }
        if (self.isExecuting)
        {
            [self willChangeValueForKey:@"isExecuting"];
            self._executing = NO;
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)doneWithResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)error
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self._executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(response, responseData, error);
        self.completionHandler = nil;
    }
    self._finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return self._executing;
}

- (BOOL)isFinished
{
    return self._finished;
}

@end
