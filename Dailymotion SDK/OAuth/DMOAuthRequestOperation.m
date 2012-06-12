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

@end

@implementation DMOAuthRequestOperation
{
    BOOL executing;
    BOOL finished;
}

@synthesize accessToken = _accessToken;
@synthesize URL = _URL;
@synthesize method = _method;
@synthesize headers = _headers;
@synthesize payload = _payload;
@synthesize completionHandler = _completionHandler;
@synthesize networkQueue = _networkQueue;
@synthesize request = _request;
@dynamic progressHandler;

- (id)initWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload networkQueue:(DMNetworking *)networkQueue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
    if ((self = [super init]))
    {
        self.URL = URL;
        self.method = method;
        self.payload = payload;
        self.completionHandler = handler;
        self.networkQueue = networkQueue;
        executing = NO;
        finished = NO;
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
        finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    NSDictionary *headers = self.headers;
    if (self.accessToken)
    {
        if (headers)
        {
            NSMutableDictionary *mutableHeaders = [headers mutableCopy];
            [mutableHeaders setValue:[NSString stringWithFormat:@"OAuth2 %@", self.accessToken] forKey:@"Authorization"];
            headers = mutableHeaders;
        }
        else
        {
            headers = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"OAuth2 %@", self.accessToken] forKey:@"Authorization"];
        }
    }

    __unsafe_unretained DMOAuthRequestOperation *bself = self;
    self.request = [self.networkQueue performRequestWithURL:self.URL
                                                     method:self.method
                                                    payload:self.payload
                                                    headers:headers
                                          completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
    {
        [bself doneWithResponse:response data:responseData error:error];
    }];
    if (self.progressHandler)
    {
        self.request.progressHandler = self.progressHandler;
    }
}

- (void)cancelWithError:(NSError *)error
{
    if (self.completionHandler)
    {
        self.completionHandler(nil, nil, error);
        self.completionHandler = nil;
    }
    [self cancel];
}

- (void)cancel
{
    if (self.isFinished) return;
    [super cancel];
    [self.request cancel];
    [self doneWithResponse:nil data:nil error:nil];
}

- (void)doneWithResponse:(NSURLResponse *)response data:(NSData *)responseData error:(NSError *)error
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(response, responseData, error);
        self.completionHandler = nil;
    }
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

@end
