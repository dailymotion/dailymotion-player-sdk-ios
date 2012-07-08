//
//  VideoTableViewController.h
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/SDK.h>

@class DetailViewController;

@interface VideoTableViewController : UITableViewController

@property (strong, nonatomic) DetailViewController *detailViewController;
@property (nonatomic, strong) DMItemTableViewDataSource *tableDataSource;

@end
