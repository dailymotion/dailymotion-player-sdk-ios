//
//  ChannelCell.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 25/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "ChannelCell.h"

@interface ChannelCell ()

@property (nonatomic, readwrite) NSString *channelId;
@property (nonatomic, readwrite) NSString *channelName;

@end

@implementation ChannelCell

- (NSArray *)fieldsNeeded
{
    return @[@"id", @"name"];
}

- (void)prepareForLoading
{
    self.textLabel.text = @"…";
}

- (void)setFieldsData:(NSDictionary *)data
{
    self.textLabel.text = [data objectForKey:@"name"];
    self.channelId = [data objectForKey:@"id"];
    self.channelName = [data objectForKey:@"name"];
    [self setNeedsLayout];
}

@end
