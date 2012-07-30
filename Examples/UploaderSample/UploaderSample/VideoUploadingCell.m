//
//  VideoUploadingCell.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 27/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "VideoUploadingCell.h"

@implementation VideoUploadingCell

- (void)setVideoInfo:(VideoInfo *)videoInfo
{
    if (_videoInfo)
    {
        [_videoInfo removeObserver:self forKeyPath:@"transferOperation"];
    }
    _videoInfo = videoInfo;
    self.titleLabel.text = self.videoInfo.title;
    self.progressView.progress = 0;
    if (self.videoInfo.transferOperation)
    {
        [self configureProgressHandler];
    }
    [self.videoInfo addObserver:self forKeyPath:@"transferOperation" options:0 context:NULL];
}

- (void)configureProgressHandler
{
    DMAPITransfer *uploadOperation = self.videoInfo.transferOperation;
    self.progressView.progress = uploadOperation.totalBytesTransfered == 0 ? 0 : uploadOperation.totalBytesExpectedToTransfer / uploadOperation.totalBytesTransfered;

    __weak VideoUploadingCell *bself = self;
    self.videoInfo.transferOperation.progressHandler = ^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite)
    {
        bself.progressView.progress = totalBytesWritten == 0 ? 0 : (float)totalBytesWritten / totalBytesExpectedToWrite;
    };
}

- (void)dealloc
{
    [_videoInfo removeObserver:self forKeyPath:@"transferOperation"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"transferOperation"] && object == self)
    {
        [self configureProgressHandler];
    }
}

@end
