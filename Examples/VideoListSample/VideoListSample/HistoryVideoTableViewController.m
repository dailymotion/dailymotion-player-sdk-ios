//
//  HistoryVideoTableViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "HistoryVideoTableViewController.h"
#import "HistoryVideoCollection.h"

@implementation HistoryVideoTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.itemDataSource.editable = YES;
    self.itemDataSource.reorderable = YES;

    [HistoryVideoCollection historyCollectionWithAPI:DMAPI.sharedAPI callback:^(DMItemCollection *historyVideoCollection)
    {
        self.itemDataSource.itemCollection = historyVideoCollection;
    }];
}

@end
