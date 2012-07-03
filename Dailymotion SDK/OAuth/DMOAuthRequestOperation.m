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
@property (nonatomic, strong) DMNetworking *_networkQueue;
@property (nonatomic, strong) DMNetRequestOperation *_request;
@property (nonatomic, assign) BOOL _executing;
@property (nonatomic, assign) BOOL _finished;

@end


@implementation DMOAuthRequestOperation

- (id)initWithURL:(NSURL *)URL method:(NSString *)method headers:headers payload:(id)payload networkQueue:(DMNetworking *)networkQueue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
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
    __weak DMOAuthRequestOperation *bself = self;
    self._request = [self._networkQueue performRequestWithURL:self.URL
                                                       method:self.method
                                                      payload:self.payload
                                                      headers:headers
                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
    {
        [bself doneWithResponse:response data:responseData error:error];
        bself._request = nil;
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
    [self._request cancel];
    self._executing = NO;
    self._finished = YES;
    self._request = nil;
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