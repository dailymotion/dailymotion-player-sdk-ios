//
//  MasterViewController.h
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController;

@interface MasterViewController : UITableViewController <UISearchBarDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;

@end
