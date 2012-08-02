//
//  VideoTableViewController.h
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/DailymotionSDK.h>

@class DetailViewController;

@interface VideoTableViewController : DMItemTableViewController

@property (strong, nonatomic) DetailViewController *detailViewController;

@end
