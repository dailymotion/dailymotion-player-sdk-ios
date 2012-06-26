//
//  DMItemTest.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMItemTest.h"
#import "DMTestUtils.h"
#import "DMItem.h"
#import "DMItemCollection.h"
#import "DailymotionTestConfig.h"

@implementation DMItemTest

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

- (void)testGetItemFields
{
    DMAPI *api = self.api;
    DMItem *video = [DMItem itemWithType:@"video" forId:@"xmcyw2" fromAPI:api];

    INIT(1)

    [video withFields:@[@"id", @"title"] do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (error) NSLog(@"ERROR: %@", error);
        STAssertNil(error, @"No error");
        STAssertFalse(stalled, @"Newly loaded data is not stall");
        STAssertEqualObjects(@"xmcyw2", data[@"id"], @"Got the requested id");
        STAssertEqualObjects(@"Test Video - Cell Core", data[@"title"], @"Got the video title");
        DONE
    }];

    WAIT
}

- (void)testGetStalledItemFields
{
    DMAPI *api = self.api;
    DMItem *video = [DMItem itemWithType:@"video" forId:@"xmcyw2" fromAPI:api];
    [video flushCache];

    INIT(1)

    [video withFields:@[@"id", @"title"] do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        STAssertTrue(YES, @"First load wram the cache");
        DONE
    }];

    WAIT

    video.cacheInfo.stalled = YES;

    REINIT(2)

    __block BOOL firstLoad = YES;

    [video withFields:@[@"id", @"title", @"description"] do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (firstLoad)
        {
            STAssertTrue(stalled, @"First callback returns salled cached data");
            STAssertNil(error, @"No error");
            STAssertEqualObjects(@"xmcyw2", data[@"id"], @"Got the requested id");
            STAssertNil(data[@"description"], @"Description not loaded yet");
            firstLoad = NO;
        }
        else
        {
            STAssertFalse(stalled, @"Second callback returns fresh data");
            STAssertNil(error, @"No error");
            STAssertEqualObjects(@"xmcyw2", data[@"id"], @"Got the requested id");
            STAssertNotNil(data[@"description"], @"Description now loaded");
        }
        DONE
    }];

    WAIT
}

- (void)testCachedCollection
{
    DMAPI *api = self.api;
    DMItemCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test"} fromAPI:api];

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
    DMItemCollection *videoSearch = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"search": @"test"} fromAPI:api];

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

    // Prevents from request aggregation, we wan't DMItemCollection aggregation
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

    // Prevents from request aggregation, we wan't DMItemCollection aggregation
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

@end
