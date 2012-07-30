//
//  ChannelSelectorViewController.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 25/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/SDK.h>

@class VideoInfo;

@interface ChannelSelectorViewController : DMItemTableViewController

@property (strong, nonatomic) VideoInfo *videoInfo;

@end
