//
//  DMNetRequestOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMNetRequestOperation.h"

@interface DMNetRequestOperation ()

@property (nonatomic, copy) NSURLRequest *_request;
@property (nonatomic, strong) NSMutableData *_responseData;
@property (nonatomic, strong) NSURLResponse *_response;
@property (nonatomic, strong) NSError *_error;
@property (nonatomic, strong) NSURLConnection *_connection;
@property (nonatomic, assign) BOOL _executing;
@property (nonatomic, assign) BOOL _finished;
@property (nonatomic, strong) NSTimer *_timeoutTimer;

@end

@implementation DMNetRequestOperation

- (id)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init]))
    {
        __request = request;
        __executing = NO;
        __finished = NO;
        __responseData = [[NSMutableData alloc] init];
    }
    return self;
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

    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self willChangeValueForKey:@"isExecuting"];
        self._connection = [[NSURLConnection alloc] initWithRequest:self._request delegate:self startImmediately:NO];
        [self._connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self._connection start];
        self._executing = YES;
        self._timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self._request.timeoutInterval target:self selector:@selector(cancel) userInfo:nil repeats:NO];
        [self didChangeValueForKey:@"isExecuting"];
    });
}

- (void)cancel
{
    [self._timeoutTimer invalidate];
    self._timeoutTimer = nil;
    if (self.isFinished) return;
    [super cancel];
    [self._connection cancel];
    self._executing = NO;
    self._finished = YES;

    self._request = nil;
    self._response = nil;
    self._responseData = nil;
    self._connection = nil;
    self._error = nil;
}

- (void)done
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self._executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(self._response, self._responseData, self._error);
        self.completionHandler = nil;
    }
    self.progressHandler = nil;
    self._finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

    self._request = nil;
    self._response = nil;
    self._responseData = nil;
    self._connection = nil;
    self._error = nil;
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

#pragma mark NSURLConnection delegate

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self._responseData appendData:data];
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
    self._response = response;
    [self._timeoutTimer invalidate];
    self._timeoutTimer = nil;
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self done];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError *)connectionError
{
    self._error = connectionError;
    [self done];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

@end
