//
//  ChannelCell.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 25/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/DailymotionSDK.h>

@interface ChannelCell : UITableViewCell <DMItemDataSourceItem>

@property (nonatomic, readonly) NSString *channelId;
@property (nonatomic, readonly) NSString *channelName;

@end
