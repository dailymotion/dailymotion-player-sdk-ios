//
//  DMNetRequestOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMNetRequestOperation.h"

@interface DMNetRequestOperation ()

@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, assign) BOOL executing;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, strong) NSTimer *timeoutTimer;

@end

@implementation DMNetRequestOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (id)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        _request = request;
        _executing = NO;
        _finished = NO;
        _responseData = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)start {
    if (self.isCancelled) {
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self willChangeValueForKey:@"isExecuting"];
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self.connection start];
        self.executing = YES;
        //self._timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self._request.timeoutInterval target:self selector:@selector(timeout) userInfo:nil repeats:NO];
        [self didChangeValueForKey:@"isExecuting"];
    });
}

- (void)cancel {
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    if (self.isFinished) return;
    [super cancel];

    if (self.connection) {
        [self.connection cancel];

        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (!self.isFinished) {
            [self willChangeValueForKey:@"isFinished"];
            self.finished = YES;
            [self didChangeValueForKey:@"isFinished"];
        }
        if (self.isExecuting) {
            [self willChangeValueForKey:@"isExecuting"];
            self.executing = NO;
            [self didChangeValueForKey:@"isExecuting"];
        }
    }

    self.request = nil;
    self.response = nil;
    self.responseData = nil;
    self.connection = nil;
    self.error = nil;
}

- (void)timeout {
    if (self.isCancelled || self.isFinished) return;
    self.error = [NSError errorWithDomain:NSURLErrorDomain code:-1001 userInfo:@
    {
            NSLocalizedDescriptionKey : @"timed out",
            NSURLErrorFailingURLStringErrorKey : self.request.URL.absoluteString,
            NSURLErrorFailingURLErrorKey : self.request.URL
    }];
    [self done];
}

- (void)done {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self.executing = NO;
    if (self.completionHandler && !self.isCancelled) {
        self.completionHandler(self.response, self.responseData, self.error);
        self.completionHandler = nil;
    }
    self.progressHandler = nil;
    self.finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

    self.request = nil;
    self.response = nil;
    self.responseData = nil;
    self.connection = nil;
    self.error = nil;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return self.executing;
}

- (BOOL)isFinished {
    return self.finished;
}

#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (self.progressHandler) {
        self.progressHandler(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = response;
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self done];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)connectionError {
    self.error = connectionError;
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    [self done];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSLog(@"connection auth %@", challenge);
    
    if ([challenge previousFailureCount] == 0 && self.credential) {
        
        [[challenge sender] useCredential:_credential
               forAuthenticationChallenge:challenge];
    } else {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        // inform the user that the client id & secret are incorrect ?
        NSLog(@"INVALID API AUTH");
        [self done];
    }
}

@end
