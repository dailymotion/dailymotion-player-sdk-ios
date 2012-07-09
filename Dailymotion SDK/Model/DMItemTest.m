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
#import "DailymotionTestConfig.h"
#import "DMSubscriptingSupport.h"

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

- (void)testEqual
{
    DMAPI *api = self.api;
    DMItem *video1 = [DMItem itemWithType:@"video" forId:@"xmcyw2" fromAPI:api];
    DMItem *video1bis = [DMItem itemWithType:@"video" forId:@"xmcyw2" fromAPI:api];
    DMItem *video2 = [DMItem itemWithType:@"video" forId:@"xmcyw3" fromAPI:api];

    STAssertTrue([video1 isEqual:video1bis], @"Two item instances on the same id are equal");
    STAssertFalse([video1 isEqual:video2], @"Two item instances on the different id are not equal");

    NSMutableArray *array = NSMutableArray.array;
    [array addObject:video1];
    [array removeObject:video1bis];
    STAssertEquals(array.count, 0U, @"Different instance of the same item are seen equal by NSArray");
}

@end
