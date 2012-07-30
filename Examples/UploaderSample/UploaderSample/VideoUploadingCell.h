//
//  VideoUploadingCell.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 27/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoInfo.h"

@interface VideoUploadingCell : UITableViewCell

@property (strong, nonatomic) VideoInfo *videoInfo;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end
