//
//  DailymotionTest.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 13/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DailymotionTest.h"
#import "DailymotionTestConfig.h"

@implementation NSURLRequest (IgnoreSSL)

// Workaround for strange SSL with SenTestCase invalid certificate bug
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}

@end

@implementation DailymotionTest

- (void)tearDown
{
    [results release], results = nil;
    [username release], username = nil;
    [password release], password = nil;
}

- (void)waitResponseWithTimeout:(NSTimeInterval)timeout
{
    [results release], results = nil;
    results = [[NSMutableArray alloc] init];

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

    [api release];
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

    [api release];
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
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 results.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call2", @"Is first call.");

    [api release];
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
    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"The 11th result made its way on a second request.");
    STAssertEqualObjects([[[results lastObject] objectForKey:@"result"] objectForKey:@"message"], @"call11", @"It's the 11th one.");

    [api release];
}

- (void)testCallInvalidMethod
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api callMethod:@"invalid.method" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"error", @"Is error response");

    [api release];
}

- (void)testGrantTypeClientCredentials
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    NSDictionary *result = [[results lastObject] objectForKey:@"result"];
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `read' scope.");

    [api release];
}

- (void)testGrantTypeClientCredentialsRefreshToken
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api clearSession];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");

    NSString *accessToken = [api.session objectForKey:@"access_token"];
    NSMutableDictionary *session = [api.session mutableCopy];
    [session setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"expires"];
    [session removeObjectForKey:@"refresh_token"];
    api.session = session;

    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    STAssertFalse([accessToken isEqual:[api.session objectForKey:@"access_token"]], @"Access token refreshed with not refresh_token");

    [api release];
}

- (void)testGrantTypeWrongPassword
{
    Dailymotion *api = [[Dailymotion alloc] init];
    api.UIDelegate = self;
    username = @"username";
    password = @"wrong_password";
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"error", @"Is error response");
}

- (void)testGrantTypePassword
{
    Dailymotion *api = [[Dailymotion alloc] init];
    api.UIDelegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    NSDictionary *result = [[results lastObject] objectForKey:@"result"];
    STAssertEqualObjects([result objectForKey:@"username"], kDMUsername, @"Is valid username.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `read' scope.");
    STAssertTrue([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `read' scope.");

    [api release];
    [username release], username = nil;
    [password release], password = nil;
    api = [[Dailymotion alloc] init];
    api.UIDelegate = self;
    [api setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api callMethod:@"auth.info" withArguments:nil delegate:self];

    [self waitResponseWithTimeout:5];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"success", @"Is success response");
    result = [[results lastObject] objectForKey:@"result"];
    STAssertEqualObjects([result objectForKey:@"username"], kDMUsername, @"Is valid username.");

    [api release];
}

- (void)testGrantTypeAuthorization
{
    // TODO: implement authorization grant type test
}

- (void)testUploadFile
{
    Dailymotion *api = [[Dailymotion alloc] init];
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api clearSession];
    [api uploadFile:kDMTestFilePath delegate:self];

    [self waitResponseWithTimeout:100];

    STAssertEquals([results count], (NSUInteger)1, @"There's is 1 result.");
    STAssertEqualObjects([[results lastObject] valueForKey:@"type"], @"file_upload", @"Is file_upload response");
    STAssertNotNil([[results lastObject] objectForKey:@"url"], @"Got an URL.");

    [api release];
}

- (void)testSessionStoreKey
{
    Dailymotion *api = [[Dailymotion alloc] init];
    STAssertNil([api sessionStoreKey], @"Session store key is nil if no grant type");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    NSString *sessionStoreKey = [api sessionStoreKey];
    STAssertNotNil(sessionStoreKey, @"Session store key is not nil if grant type defined");
    STAssertTrue([sessionStoreKey length] < 50, @"Session store key is not too long");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:@"another secret" scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api sessionStoreKey]], @"Session store key is different when API secret changes");
    [api setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:@"another key" secret:kDMAPISecret scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api sessionStoreKey]], @"Session store key is different when API key changes");

    [api release];
}

- (void)dailymotionDidRequestUserCredentials:(Dailymotion *)dailymotion
{
    NSLog(@"call delegate cred");
    if (username)
    {
        [dailymotion setUsername:username password:password];
    }
    else
    {
        STAssertTrue(NO, @"API unexpectedly asked for end-user credentials");
    }
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
