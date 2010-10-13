//
//  DailymotionTest.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 13/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DailymotionTest.h"
#import "DailymotionTestConfig.h"

@implementation DailymotionTest

- (void)setUp
{
    [results release], results = nil;
    results = [[NSMutableArray alloc] init];
}

- (void)waitResponseWithTimeout:(NSTimeInterval)timeout
{
    NSDate *expires = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([results count] == 0 && [expires timeIntervalSinceNow] > 0)
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testSingleCall
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"test" forKey:@"message"] delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"test", @"Is valid result.");
}

- (void)testMultiCall
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"test" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:nil delegate:self];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)3, @"There's is 3 results.");
    STAssertEqualObjects([[results objectAtIndex:0] valueForKey:@"type"], @"success", @"First result is success.");
    STAssertEqualObjects([[[results objectAtIndex:0] objectForKey:@"result"] objectForKey:@"message"], @"test", @"First result is valid.");
    STAssertEqualObjects([[results objectAtIndex:1] valueForKey:@"type"], @"error", @"Second result is error.");
    STAssertEqualObjects([[results objectAtIndex:2] valueForKey:@"type"], @"auth_required", @"Third result is auth_required.");
}

- (void)testMultiCallIntermix
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call1" forKey:@"message"] delegate:self];

    // Roll the runloop once in order send the request
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call2" forKey:@"message"] delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 results.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call1", @"Is first call.");

    // Reinit the result queue
    [results release], results = nil;
    results = [[NSMutableArray alloc] init];
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 results.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call2", @"Is first call.");
}

- (void)testMultiCallLimit
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call1" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call2" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call3" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call4" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call5" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call6" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call7" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call8" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call9" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call10" forKey:@"message"] delegate:self];
    [api callMethod:@"test.echo" withArguments:[NSDictionary dictionaryWithObject:@"call11" forKey:@"message"] delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)10, @"There's is 10 results, not 11.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call10", @"The last result is the 10th.");

    // Reinit the result queue
    [results release], results = nil;
    results = [[NSMutableArray alloc] init];
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"The 11th result made its way on a second request.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call11", @"It's the 11th one.");
}

- (void)testGrantTypeNone
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api setGrantType:DailymotionGrantTypeNone withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    NSDictionary *result = [[results lastObject] objectForKey:@"result"];
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `read' scope.");
}

- (void)testGrantTypePassword
{
    Dailymotion *api = [[Dailymotion alloc] init];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          kDMUsername, @"username",
                          kDMPassword, @"password",
                          nil];
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete" info:info];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    NSDictionary *result = [[results lastObject] objectForKey:@"result"];
    STAssertEqualObjects([result objectForKey:@"username"], kDMUsername, @"Is valid username.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `read' scope.");

}

- (void)testGrantTypeToken
{
    // TODO: implement token grant type
}

- (void)testUploadFile
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api setGrantType:DailymotionGrantTypeNone withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api uploadFile:kDMTestFilePath delegate:self];

    [self waitResponseWithTimeout:100];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"file_upload", @"Is file_upload response");
    STAssertNotNil([[results lastObject] objectForKey:@"url"], @"Got an URL.");
}

- (void)dailymotion:(Dailymotion *)dailymotion didReturnResult:(id)result userInfo:(NSDictionary *)userInfo
{
    [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"success", @"type", result, @"result", nil]];
}

- (void)dailymotion:(Dailymotion *)dailymotion didReturnError:(NSError *)error userInfo:(NSDictionary *)userInfo
{
    [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"error", @"type", error, @"error", nil]];
}

- (void)dailymotion:(Dailymotion *)dailymotion didRequestAuthWithMessage:(NSString *)message userInfo:(NSDictionary *)userInfo
{
    [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"auth_required", @"type", message, @"message", nil]];
}

- (void)dailymotion:(Dailymotion *)dailymotion didUploadFileAtURL:(NSString *)URL
{
    [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"file_upload", @"type", URL, @"url", nil]];
}

@end
