//
//  DailymotionTest.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 13/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#define kDMAPIEndpointURL [NSURL URLWithString:@"http://api.local.dailymotion.com/json"]
#define kDMOAuthAuthorizeEndpointURL [NSURL URLWithString:@"http://api.local.dailymotion.com/oauth/authorize"]
#define kDMOAuthTokenEndpointURL [NSURL URLWithString:@"http://api.local.dailymotion.com/oauth/authorize"]

#import <SenTestingKit/SenTestingKit.h>
#import "Dailymotion.h"

@interface DailymotionTest : SenTestCase <DailymotionDelegate>
{
    NSMutableArray *results;
}

@end
