//
//  VideoUploadOperation.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 27/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "VideoUploadOperation.h"
#import <DailymotionSDK/DailymotionSDK.h>

@interface VideoUploadOperation ()

@property (readwrite, nonatomic) VideoInfo *videoInfo;
@property (assign, readwrite, nonatomic) BOOL _executing;
@property (assign, readwrite, nonatomic) BOOL _finished;

@end

@implementation VideoUploadOperation

- (id)initWithVideoInfo:(VideoInfo *)videoInfo
{
    if ((self = [super init]))
    {
        _videoInfo = videoInfo;
        __executing = NO;
        __finished = NO;
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

    [self willChangeValueForKey:@"isExecuting"];
    self._executing = YES;
    if  (self.videoInfo.transferOperation)
    {
        [[DMAPI sharedAPI] resumeFileUploadOperation:self.videoInfo.transferOperation withCompletionHandler:^(id result, NSError *error)
        {
            [self doneWithResult:result error:error];
        }];
    }
    else
    {
        self.videoInfo.transferOperation = [[DMAPI sharedAPI] uploadFileURL:self.videoInfo.fileURL withCompletionHandler:^(id result, NSError *error)
        {
            [self doneWithResult:result error:error];
        }];
    }
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)cancel
{
    if (self.isFinished) return;
    [super cancel];
    [self.videoInfo.transferOperation cancel];
    self.videoInfo.transferOperation = nil;
    self._executing = NO;
    self._finished = YES;
}

- (void)doneWithResult:(NSString *)urlString error:(NSError *)error
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    self._executing = NO;
    NSURL *url = [NSURL URLWithString:urlString];
    if ([self.delegate respondsToSelector:@selector(videoUploadOperation:didFinishUploadWithURL:)])
    {
        [self.delegate videoUploadOperation:self didFinishUploadWithURL:url];
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
