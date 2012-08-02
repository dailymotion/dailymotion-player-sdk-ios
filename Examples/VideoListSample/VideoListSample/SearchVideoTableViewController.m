//
//  MasterViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "SearchVideoTableViewController.h"
#import <DailymotionSDK/DailymotionSDK.h>

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
        if ([[NSFileManager defaultManager] fileExistsAtPath:resumeCollectionPath] && !self.itemDataSource.itemCollection)
        {
            DMItemCollection *resumedItemCollection = [DMItemCollection itemCollectionFromFile:resumeCollectionPath withAPI:DMAPI.sharedAPI];
            if (!self.itemDataSource.itemCollection)
            {
                self.itemDataSource.itemCollection = resumedItemCollection;
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
        if (bself.itemDataSource.itemCollection)
        {
            [bself.itemDataSource.itemCollection saveToFile:resumeCollectionPath];
        }
    }];
}

#pragma mark - Search Bar

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Change the table view itemCollection with a new video list query
    // The DMItemTableViewDataSource will handle the change and send notifications to show loading and refresh the table view when necessary
    self.itemDataSource.itemCollection = [DMItemCollection itemCollectionWithType:@"video"
                                                                         forParams:@{@"sort": @"relevance", @"search": searchBar.text}
                                                                           fromAPI:DMAPI.sharedAPI];
    [searchBar resignFirstResponder];
}

@end
