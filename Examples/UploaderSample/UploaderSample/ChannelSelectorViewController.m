//
//  ChannelSelectorViewController.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 25/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "ChannelSelectorViewController.h"
#import "VideoInfo.h"
#import "ChannelCell.h"
#import <DailymotionSDK/DMAlert.h>

@interface ChannelSelectorViewController ()

@property (strong, nonatomic) NSIndexPath *selectedIndexPath;

@end

@implementation ChannelSelectorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.itemDataSource.cellIdentifier = @"Cell";
    self.itemDataSource.itemCollection = [DMItemCollection itemCollectionWithType:@"channel" forParams:nil fromAPI:[DMAPI sharedAPI]];
}

- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didLoadCellContentAtIndexPath:(NSIndexPath *)indexPath withData:(NSDictionary *)data
{
    if ([[data objectForKey:@"id"] isEqualToString:self.videoInfo.channel])
    {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.selectedIndexPath = indexPath;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView cellForRowAtIndexPath:self.selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    ChannelCell *cell = (ChannelCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    self.videoInfo.channel = cell.channelId;
    self.videoInfo.channelName = cell.channelName;
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selectedIndexPath = indexPath;
}

@end
