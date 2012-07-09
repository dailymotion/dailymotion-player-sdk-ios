//
//  HistoryVideoCollection.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "HistoryVideoCollection.h"

static DMItemLocalCollection *historyCollection;

@implementation HistoryVideoCollection

+ (void)historyCollectionWithAPI:(DMAPI *)api callback:(void (^)(DMItemLocalCollection *historyVideoCollection)) callback
{
    if (historyCollection)
    {
        callback(historyCollection);
    }
    else
    {
        NSString *historyCollectionPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"historyVideoCollection.archive"];

        dispatch_async(dispatch_get_current_queue(), ^
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:historyCollectionPath])
            {
                historyCollection = [DMItemCollection itemCollectionFromFile:historyCollectionPath withAPI:api];
            }
            else
            {
                historyCollection = [DMItemCollection itemLocalConnectionWithType:@"video" countLimit:100 fromAPI:api];
            }

            callback(historyCollection);
        });

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note)
        {
            [historyCollection saveToFile:historyCollectionPath];
        }];
    }
}

@end
