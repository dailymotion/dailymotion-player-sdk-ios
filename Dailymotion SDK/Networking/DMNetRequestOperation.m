//
//  DMNetRequestOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMNetRequestOperation.h"

@interface DMNetRequestOperation ()

@property (nonatomic, assign) BOOL _executing;
@property (nonatomic, assign) BOOL _finished;

@end

@implementation DMNetRequestOperation
{
    NSMutableData *_responseData;
}

- (id)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init]))
    {
        self.request = request;
        self._executing = NO;
        self._finished = NO;
        _responseData = [[NSMutableData alloc] init];
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
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self.connection start];
        self._executing = YES;
        [self didChangeValueForKey:@"isExecuting"];
    });
}

- (void)cancel
{
    if (self.isFinished) return;
    [super cancel];
    [self.connection cancel];
    self._executing = NO;
    self._finished = YES;
}

- (void)done
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self._executing = NO;
    if (self.completionHandler && !self.isCancelled)
    {
        self.completionHandler(self.response, _responseData, self.error);
        self.completionHandler = nil;
    }
    self.progressHandler = nil;
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

- (NSData *)responseData
{
    return _responseData;
}

#pragma mark NSURLConnection delegate

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
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
