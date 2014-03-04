//
//  DailymotionTest.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 13/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMAPITest.h"
#import "DMTestUtils.h"
#import "DailymotionTestConfig.h"

@implementation NSURLRequest (IgnoreSSL)

// Workaround for strange SSL with SenTestCase invalid certificate bug
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    return YES;
}

@end

@implementation DMAPITest {
    NSString *username;
    NSString *password;
}

- (void)setUp {
    username = nil;
    password = nil;
}

- (DMAPI *)api {
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

- (void)testEnv {
    STAssertTrue(kDMAPIKey.length != 0, @"kDMAPIKey is missing");
    STAssertTrue(kDMAPISecret.length != 0, @"kDMAPISecret is missing");
    STAssertTrue(kDMUsername.length != 0, @"kDMUsername is missing");
    STAssertTrue(kDMPassword.length != 0, @"kDMPassword is missing");
    STAssertTrue(kDMTestFilePath.length != 0, @"kDMTestFilePath is missing");
}

- (void)testSingleCall {
    INIT(1)

    [self.api get:@"/echo" args:@{@"message" : @"test"} callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        STAssertEqualObjects([result objectForKey:@"message"], @"test", @"Is valid result.");
        DONE
    }];

    WAIT
}

- (void)testMultiCall {
    INIT(3)

    DMAPI *api = self.api;
    [api get:@"/echo" args:@{@"message" : @"test"} callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        DONE
    }];
    [api get:@"/echo" callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        DONE
    }];
    [api get:@"/videos" callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        DONE
    }];

    WAIT STAssertEquals(networkRequestCount, 1U, @"All 3 API calls has been aggregated into a single HTTP request");
}

- (void)testMergedCall {
    INIT(3)

    DMAPI *api = self.api;
    [api get:@"/videos" args:@{@"fields" : @[@"owner_screenname"]} callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        DONE
    }];
    [api get:@"/videos" args:@{@"fields" : @[@"title"]} callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        DONE
    }];
    [api get:@"/videos" args:@{@"fields" : @[@"country"]} callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        STAssertTrue([result[@"list"][0] objectForKey:@"owner_screenname"], @"Contains response with owner_screenname");
        STAssertTrue([result[@"list"][0] objectForKey:@"title"], @"Contains response with title");
        STAssertTrue([result[@"list"][0] objectForKey:@"country"], @"Contains response with country");
        DONE
    }];

    WAIT STAssertEquals(networkRequestCount, 1U, @"All 3 API calls has been merge into a single HTTP request");
}

- (void)testMergedCallPlusMulticall {
    INIT(3)

    DMAPI *api = self.api;
    [api get:@"/videos" args:@{@"fields" : @[@"title"]} callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        DONE
    }];
    [api get:@"/echo" args:@{@"message" : @"test"} callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        DONE
    }];
    [api get:@"/videos" args:@{@"fields" : @[@"owner_screenname"]} callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        DONE
    }];

    WAIT STAssertEquals(networkRequestCount, 1U, @"All 3 API calls has been merge into a single HTTP request");
}

- (void)testMultiCallIntermix {
    INIT(2)

    DMAPI *api = self.api;
    [api get:@"/echo" args:@{@"message" : @"call1"} callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertEqualObjects(result[@"message"], @"call1", @"Call #1 routed correctly");
        DONE
    }];

    // Roll the runloop once in order send the request
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    [api get:@"/echo" args:@{@"message" : @"call2"} callback:^(NSDictionary *result, DMAPICacheInfo *cacheInfo, NSError *error) {
        STAssertEqualObjects(result[@"message"], @"call2", @"Call #2 routed correctly");
        DONE
    }];

    WAIT STAssertEquals(networkRequestCount, 2U, @"The 2 API calls in two diff event loop turns hasn't been aggregated");
}

- (void)testMultiCallLimit {
    INIT(12)

    DMAPI *api = self.api;

    void (^callback)(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) = ^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        DONE
    };
    [api get:@"/echo" args:@{@"message" : @"call1"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call2"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call3"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call4"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call5"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call6"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call7"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call8"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call9"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call10"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call11"} callback:callback];
    [api get:@"/echo" args:@{@"message" : @"call12"} callback:callback];

    WAIT STAssertEquals(networkRequestCount, 2U, @"The API calls have been aggregated to 2 HTTP requests to respect the 10 call per request server limit");
}

- (void)testCallInvalidMethod {
    INIT(1)

    [self.api get:@"/invalid/path" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNotNil(error, @"Is error response");
        STAssertNil(result, @"Result is nil");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeClientCredentials {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    [api.oauth setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read"];
    [api.oauth clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeClientCredentialsRefreshToken {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api.oauth clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        STAssertNotNil(api.oauth.session.refreshToken, @"Got a refresh token");

        NSString *accessToken = api.oauth.session.accessToken;
        NSString *refreshToken = api.oauth.session.refreshToken;
        api.oauth.session.expires = [NSDate dateWithTimeIntervalSince1970:0];

        [api get:@"/auth" callback:^(NSDictionary *result2, DMAPICacheInfo *cache2, NSError *error2) {
            STAssertNil(error2, @"Is success response");
            STAssertEqualObjects(refreshToken, api.oauth.session.refreshToken, @"Same refresh token");
            STAssertFalse([accessToken isEqual:api.oauth.session.accessToken], @"Access token refreshed");
            DONE
        }];
    }];

    WAIT
}

- (void)testGrantTypeClientCredentialsRefreshWithNoRefreshToken {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api.oauth clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        STAssertNotNil(api.oauth.session.refreshToken, @"Got a refresh token");

        NSString *accessToken = api.oauth.session.accessToken;
        api.oauth.session.accessToken = nil;
        api.oauth.session.expires = [NSDate dateWithTimeIntervalSince1970:0];
        api.oauth.session.refreshToken = nil;

        [api get:@"/auth" callback:^(NSDictionary *result2, DMAPICacheInfo *cache2, NSError *error2) {
            STAssertNil(error2, @"Is success response");
            STAssertFalse([accessToken isEqual:api.oauth.session.accessToken], @"Access token refreshed with no refresh_token");
            DONE
        }];
    }];

    WAIT
}

- (void)testGrantTypeWrongPassword {
    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = @"username";
    password = @"wrong_password";
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api.oauth clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNotNil(error, @"Is error response");
        STAssertNil(result, @"Result is nil");
        DONE
    }];

    WAIT
}

- (void)testSessionChangeInvalidsCache {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:nil];
    [api.oauth clearSession];

    __block DMAPICacheInfo *privateCache;

    [api get:@"/me/videos" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        privateCache = cache;
        STAssertFalse(cache.
        public, @"The returned data is private");
        DONE
    }];

    WAIT STAssertTrue(privateCache.valid, @"Cache is valid");

    [api.oauth clearSession];

    STAssertFalse(privateCache.valid, @"Cache is no longer valid once session changed");
}

- (void)testConditionalRequest {
    INIT(1)

    DMAPI *api = self.api;

    __block DMAPICacheInfo *cacheInfo;

    [api get:@"/video/x12" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        cacheInfo = cache;
        STAssertNotNil(result, @"Result has been sent");
        STAssertNotNil(cache.etag, @"Item has an entity tag");
        DONE
    }];

    WAIT REINIT(1)

    [api get:@"/video/x12" args:nil cacheInfo:cacheInfo callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNotNil(cache.etag, @"Item has an entity tag");
        STAssertEqualObjects(cache.etag, cacheInfo.etag, @"Return object has same etag");
        STAssertNil(result, @"Result hasn't been sent because cached data is still valid");
        STAssertNil(error, @"It's not an error");
        DONE
    }];

    WAIT
}

- (void)testSessionStorage {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"write"];
    [api.oauth clearSession];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
        STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `write' scope.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `delete' scope.");
        DONE
    }];

    WAIT REINIT(1)

    api = self.api;

    api.oauth.delegate = self;
    username = nil; // should not ask for credentials
    password = nil;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"write"];
    [api get:@"/auth" callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error) {
        STAssertNil(error, @"Is success response");
        STAssertEqualObjects([result objectForKey:@"username"], kDMUsername, @"Is valid username.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"read"], @"Has `read' scope.");
        STAssertTrue([[result objectForKey:@"scope"] containsObject:@"write"], @"Has `write' scope.");
        STAssertFalse([[result objectForKey:@"scope"] containsObject:@"delete"], @"Has `delete' scope.");
        DONE
    }];

    WAIT
}

- (void)testGrantTypeAuthorization {
    // TODO: implement authorization grant type test
}

- (void)testUploadFile {
    requireAPIKey;

    INIT(1)

    DMAPI *api = self.api;
    api.oauth.delegate = self;
    username = kDMUsername;
    password = kDMPassword;
    [api.oauth setGrantType:DailymotionGrantTypePassword withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    [api.oauth clearSession];
    [api uploadFileURL:[NSURL fileURLWithPath:kDMTestFilePath] withCompletionHandler:^(NSString *url, NSError *error) {
        if (error) {
            NSLog(@"Upload error: %@", error);
        }
        STAssertNil(error, @"Is success response");
        STAssertTrue([url isKindOfClass:NSURL.class], @"Got an URL.");
        DONE
    }];

    WAIT
}

- (void)testSessionStoreKey {
    DMAPI *api = self.api;
    STAssertNil([api.oauth sessionStoreKey], @"Session store key is nil if no grant type");
    [api.oauth setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:kDMAPISecret scope:@"read write delete"];
    NSString *sessionStoreKey = [api.oauth sessionStoreKey];
    STAssertNotNil(sessionStoreKey, @"Session store key is not nil if grant type defined");
    [api.oauth setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:kDMAPIKey secret:@"another secret" scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api.oauth sessionStoreKey]], @"Session store key is different when API secret changes");
    [api.oauth setGrantType:DailymotionGrantTypeClientCredentials withAPIKey:@"another key" secret:kDMAPISecret scope:@"read write delete"];
    STAssertTrue(![sessionStoreKey isEqual:[api.oauth sessionStoreKey]], @"Session store key is different when API key changes");
}

- (void)dailymotionOAuthRequest:(DMOAuthClient *)request didRequestUserCredentialsWithHandler:(void (^)(NSString *username, NSString *password))setCredentials; {
    if (username) {
        setCredentials(username, password);
    }
    else {
        STFail(@"API unexpectedly asked for end-user credentials");
    }
}

@end
