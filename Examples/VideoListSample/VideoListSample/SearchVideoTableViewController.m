//
//  MasterViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "SearchVideoTableViewController.h"
#import <DailymotionSDK/SDK.h>

@interface SearchVideoTableViewController ()

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end

@implementation SearchVideoTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    __weak SearchVideoTableViewController *bself = self;

    // Handle auto resuming
    NSString *resumeCollectionPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"resumeSearchVideoCollection.archive"];

    dispatch_async(dispatch_get_current_queue(), ^
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:resumeCollectionPath] && !self.tableDataSource.itemCollection)
        {
            DMItemCollection *resumedItemCollection = [DMItemCollection itemCollectionFromFile:resumeCollectionPath withAPI:DMAPI.sharedAPI];
            if (!self.tableDataSource.itemCollection)
            {
                self.tableDataSource.itemCollection = resumedItemCollection;
                self.searchBar.text = ((DMItemRemoteCollection *)resumedItemCollection).params[@"search"];
            }
            //[[NSFileManager defaultManager] removeItemAtPath:resumeCollectionPath error:NULL];
        }
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
    {
        if (bself.tableDataSource.itemCollection)
        {
            [bself.tableDataSource.itemCollection saveToFile:resumeCollectionPath];
        }
    }];
}

#pragma mark - Search Bar

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Change the table view itemCollection with a new video list query
    // The DMItemTableViewDataSource will handle the change and send notifications to show loading and refresh the table view when necessary
    self.tableDataSource.itemCollection = [DMItemCollection itemCollectionWithType:@"video"
                                                                         forParams:@{@"sort": @"relevance", @"search": searchBar.text}
                                                                           fromAPI:DMAPI.sharedAPI];
    [searchBar resignFirstResponder];
}

@end
