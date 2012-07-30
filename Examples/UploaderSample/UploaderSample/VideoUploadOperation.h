//
//  VideoUploadOperation.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 27/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoInfo.h"

@class VideoUploadOperation;

@protocol VideoUploadOperationDelegate <NSObject>

- (void)videoUploadOperation:(VideoUploadOperation *)videoUploadOperation didFinishUploadWithURL:(NSURL *)url;

@end

@interface VideoUploadOperation : NSOperation

@property (strong, nonatomic) id<VideoUploadOperationDelegate> delegate;
@property (readonly, nonatomic) VideoInfo *videoInfo;

- (id)initWithVideoInfo:(VideoInfo *)videoInfo;

@end
