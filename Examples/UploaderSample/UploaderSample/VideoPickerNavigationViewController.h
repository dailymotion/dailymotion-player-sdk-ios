//
//  VideoPickerNavigationViewController.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 24/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoEditViewController.h"

@class VideoPickerNavigationViewController;
@class VideoInfo;

@protocol VideoPickerNavigationViewControllerDelegate <NSObject>

- (void)videoPickerController:(VideoPickerNavigationViewController *)videoPickerController didFinishPickingVideoWithInfo:(VideoInfo *)videoInfo;
- (void)videoPickerControllerDidCancel:(VideoPickerNavigationViewController *)videoPickerController;

@end

@interface VideoPickerNavigationViewController : UIImagePickerController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, VideoEditViewControllerDelegate>

@property (strong, nonatomic) VideoInfo *videoInfo;
@property (weak, nonatomic) id<VideoPickerNavigationViewControllerDelegate> videoDelegate;

@end
