//
//  VideoInfo.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 25/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DailymotionSDK/SDK.h>

@interface VideoInfo : NSObject

@property (strong, nonatomic) NSURL *fileURL;
@property (strong, nonatomic) NSURL *uploadedFileURL;
@property (strong, nonatomic) NSString *title;
@property (strong, nonatomic) NSString *channel;
@property (strong, nonatomic) NSString *channelName;
@property (strong, nonatomic) NSString *tags;
@property (strong, nonatomic) NSString *description;
@property (strong, nonatomic) DMAPITransfer *transferOperation;

@end
