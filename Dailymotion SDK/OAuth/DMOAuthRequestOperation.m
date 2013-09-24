//
//  DMOAuthRequestOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthRequestOperation.h"
#import "DMNetworking.h"

@interface DMOAuthRequestOperation ()

@property (nonatomic, strong, readwrite) NSURL *URL;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, strong, readwrite) NSDictionary *headers;
@property (nonatomic, strong, readwrite) id payload;
@property (nonatomic, strong) DMNetworking *networkQueue;
@property (nonatomic, strong) DMNetRequestOperation *request;
@property (nonatomic, assign) BOOL executing;
@property (nonatomic, assign) BOOL finished;

@end


@implementation DMOAuthRequestOperation

- (id)initWithURL:(NSURL *)URL method:(NSString *)method headers:(NSDictionary *)headers payload:(id)payload networkQueue:(DMNetworking *)networkQueue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler
{
    self = [super init];
    if (self)
    {
        _URL = URL;
        _method = method;
        _headers = headers;
        _payload = payload;
        _completionHandler = handler;
        _networkQueue = networkQueue;
        _executing = NO;
        _finished = NO;
    }
    return self;
}

- (void)setProgressHandler:(void (^)(NSInteger, NSInteger, NSInteger))progressHandler
{
    self.request.progressHandler = progressHandler;
}

- (void (^)(NSInteger, NSInteger, NSInteger))progressHandler
{
    return self.request.progressHandler;
}

- (void)start
{
    if (self.isCancelled)
    {
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
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
    self.request = [self.networkQueue performRequestWithURL:self.URL
                                                       method:self.method
                                                      payload:self.payload
                                                      headers:headers
                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
    {
        if (!wself) return;
        __strong DMOAuthRequestOperation *sself = wself;
        [sself doneWithResponse:response data:responseData error:error];
        sself.request = nil;
    }];
    if (self.progressHandler)
    {
        self.request.progressHandler = self.progressHandler;
    }
    self.executing = YES;
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

    if (self.request)
    {
        [self.request cancel];
        self.request = nil;

        // As we cancelled the request, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (!self.isFinished)
        {
            [self willChangeValueForKey:@"isFinished"];
            self.finished = YES;
            [self didChangeValueForKey:@"isFinished"];
        }
        if (self.isExecuting)
        {
            [self willChangeValueForKey:@"isExecuting"];
            self.executing = NO;
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)doneWithResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)error
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self.executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(response, responseData, error);
        self.completionHandler = nil;
    }
    self.finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return self.executing;
}

- (BOOL)isFinished
{
    return self.finished;
}

@end
