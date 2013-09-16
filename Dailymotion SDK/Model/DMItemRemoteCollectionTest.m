//
//  DMItemRemoteCollectionTest.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import "DMItemRemoteCollectionTest.h"
#import "DMTestUtils.h"
#import "DMItemRemoteCollection.h"
#import "DailymotionTestConfig.h"

@interface DMItemRemoteCollection (Private)

- (DMItem *)itemWithId:(NSString *)itemId atIndex:(NSUInteger)index;

@end

@implementation DMItemRemoteCollectionTest

- (DMAPI *)api
{
    DMAPI *api = [[DMAPI alloc] init];
#ifdef kDMAPIEndpointURL
    api.APIBaseURL = kDMAPIEndpointURL;
#endif
#ifdef kDMOAuthAuthorizeEndpointURL
    api.oAuthAuthorizationEndpointURL = kDMOAuthAuthorizeEndpointURL;
#endif
#ifdef kDMOAuthTokenEndpointURL
    api.oAuthTokenEndpointURL = kDMOAuthTokenEndpointURL;
#endif
    return api;
}

- (void)testCachedCollection
{
    DMAPI *api = self.api;
    DMItemRemoteCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test"} fromAPI:api];

    INIT(1)

    [videoSearch itemsWithFields:@[@"id", @"title"] forPage:1 withPageSize:10 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        DONE
    }];

    WAIT

    REINIT(1)

    [videoSearch itemsWithFields:@[@"id", @"title"] forPage:1 withPageSize:10 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        DONE
    }];

    WAIT
}

- (void)testItemFromCollectionAtIndex
{
    DMAPI *api = self.api;
    DMItemRemoteCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test"} fromAPI:api];

    INIT(1)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:2 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    WAIT
}

- (void)testItemFromCollectionAtOutOfBoundIndex
{
    DMAPI *api = self.api;
    DMItemRemoteCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test"} fromAPI:api];

    INIT(1)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:videoSearch.pageSize * 100 - 1 do:^(NSDictionary *data, BOOL stalled, NSError *error)
     {
         if (error) NSLog(@"ERROR: %@", error);
         STAssertNil(error, @"No error");
         STAssertNil(data, @"No item");
         DONE
     }];

    WAIT
}

- (void)testItemsFromCollectionAtIndexWithinSamePageAreAggregated
{
    DMAPI *api = self.api;
    DMItemCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test2"} fromAPI:api];

    INIT(2)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:2 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    // Prevents from request aggregation, we want to test DMItemCollection aggregation
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:9 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 1U, @"Two items from collection within same page generates a single request");
}

- (void)testItemsFromCollectionAtIndexWithinDiffPagesAreNotAggregated
{
    DMAPI *api = self.api;
    DMItemCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test1"} fromAPI:api];

    INIT(2)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:40 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    // Prevents from request aggregation, we want to test DMItemCollection aggregation
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:9 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 2U, @"Two items from collection NOT within same pages generates two requests");
}

- (void)testItemsFromCollectionAtIndexWithinSameCachedPageButUncachedItemAreAccumulated
{
    DMAPI *api = self.api;
    DMItemRemoteCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test3"} fromAPI:api];

    INIT(1)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertNotNil(data[@"id"], @"Got an id field");

        // Force this item invalid so next collection request with have to refresh to data
        [videoSearch itemWithId:data[@"id"] atIndex:0].cacheInfo.valid = NO;
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 1U, @"One request for the first uncached page");

    REINIT(2)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    // Prevents from request aggregation, we want to test DMItemCollection aggregation
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:1 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 1U, @"Refreshes of items contained in the same page of an already cached id list is accumulated");

    REINIT(1)

    [videoSearch withItemFields:@[@"id", @"title"] atIndex:2 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertNotNil(data[@"id"], @"Got an id field");
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 0U, @"Other objects on the same page are already cached");
}

#warning skipped this test due to a bug that make this test crash under seantest
- (void)skiptestItemCollectionArchiving
{
    DMAPI *api = self.api;
    DMItemRemoteCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test archiving"} fromAPI:api];

    INIT(1)

    [videoSearch itemsWithFields:@[@"id", @"title"] forPage:1 withPageSize:10 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        DONE
    }];

    WAIT

    NSString *archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"videoCollectionTest.archive"];
    [[NSFileManager defaultManager] removeItemAtPath:archivePath error:NULL];
    [videoSearch saveToFile:archivePath];

    STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive file have been created");

    DMAPI *api2 = self.api;
    DMItemRemoteCollection *videoSearchUnarchived = [DMItemCollection itemCollectionFromFile:archivePath withAPI:api2];

    STAssertTrue(videoSearch != videoSearchUnarchived, @"Got different instance");
    STAssertEqualObjects(videoSearch.cacheInfo.etag, videoSearchUnarchived.cacheInfo.etag, @"Etags are equal");
    STAssertEquals(videoSearch.currentEstimatedTotalItemsCount, videoSearchUnarchived.currentEstimatedTotalItemsCount, @"Current estimated total item are equal");
    STAssertTrue(videoSearch.api != videoSearchUnarchived.api, @"Unarchived collection doesn't get the same API instance as original");
    STAssertEquals(videoSearchUnarchived.api, api2, @"Unarchived collection got the new API object instance");

    REINIT(1)

    [videoSearchUnarchived itemsWithFields:@[@"id", @"title"] forPage:1 withPageSize:10 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        DONE
    }];

    WAIT

    STAssertEquals(networkRequestCount, 0U, @"First page of the unarchived collection is already cached");

    [[NSFileManager defaultManager] removeItemAtPath:archivePath error:NULL];
}

@end
