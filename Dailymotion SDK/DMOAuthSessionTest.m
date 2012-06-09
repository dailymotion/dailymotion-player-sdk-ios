//
//  DMOAuthSessionTest.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthSessionTest.h"

@implementation DMOAuthSessionTest

- (void)testUnserializeInvalidSession
{
    NSDictionary *sessionInfo;
    DMOAuthSession *session;

    sessionInfo = [NSDictionary dictionary];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];
    STAssertNil(session, @"Empty session is not accepted");

    sessionInfo = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"access_token"];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];
    STAssertNil(session, @"Session with null access_token is not accepted");

    sessionInfo = [NSDictionary dictionaryWithObject:@"" forKey:@"access_token"];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];
    STAssertNil(session, @"Session with empty access_token is not accepted");
}

- (void)testUnserializeValidSession
{
    NSDictionary *sessionInfo;
    DMOAuthSession *session;

    sessionInfo = [NSDictionary dictionaryWithObject:@"1k3j2kj3k2j3kdj233kdj2" forKey:@"access_token"];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];
    STAssertNotNil(session, @"Session just an access token is accepted");
    STAssertEqualObjects(session.accessToken, [sessionInfo valueForKey:@"access_token"], @"Access token is set");
    STAssertNil(session.refreshToken, @"Refresh token not set");

    sessionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"1k3j2kj3k2j3kdj233kdj2", @"access_token",
                   @"k2j3kdjio234jknsakfjh2", @"refresh_token",
                   @"scope1 scope2", @"scope",
                   [NSNumber numberWithInt:3200], @"expires_in",
                   nil];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];
    STAssertNotNil(session, @"Full session is accepted");
    STAssertEqualObjects(session.accessToken, [sessionInfo valueForKey:@"access_token"], @"Access token is set");
    STAssertEqualObjects(session.refreshToken, [sessionInfo valueForKey:@"refresh_token"], @"Refresh token is set");
    STAssertEqualObjects(session.scope, [sessionInfo valueForKey:@"scope"], @"Scope token is set");
    STAssertEqualsWithAccuracy([session.expires timeIntervalSinceNow], [[sessionInfo valueForKey:@"expires_in"] doubleValue], 1, @"Expires token is set");
}

- (void)testKeychainStore
{
    NSDictionary *sessionInfo;
    DMOAuthSession *session, *restoredSession;

    sessionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"1k3j2kj3k2j3kdj233kdj2", @"access_token",
                   @"k2j3kdjio234jknsakfjh2", @"refresh_token",
                   @"scope1 scope2", @"scope",
                   [NSNumber numberWithInt:3200], @"expires_in",
                   nil];
    session = [DMOAuthSession sessionWithSessionInfo:sessionInfo];

    STAssertTrue([session storeInKeychainWithIdentifier:@"com.dailymotion.test"], @"Keychain store succeed");

    restoredSession = [DMOAuthSession sessionFromKeychainIdentifier:@"com.dailymotion.test"];
    STAssertNotNil(restoredSession, @"Session found in keychain");
    STAssertEqualObjects(restoredSession.refreshToken, session.refreshToken, @"Restored refresh token from keychain");

    [session clearFromKeychainWithIdentifier:@"com.dailymotion.test"];

    restoredSession = [DMOAuthSession sessionFromKeychainIdentifier:@"com.dailymotion.test"];
    STAssertNil([DMOAuthSession sessionFromKeychainIdentifier:@"com.dailymotion.test"], @"Cannot be found once cleared");
}

@end
