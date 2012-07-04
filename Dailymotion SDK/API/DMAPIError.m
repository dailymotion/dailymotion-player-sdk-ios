//
//  DMAPIError.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMAPIError.h"
#import "DMSubscriptingSupport.h"

NSString * const DailymotionTransportErrorDomain = @"DailymotionTransportErrorDomain";
NSString * const DailymotionAuthErrorDomain = @"DailymotionAuthErrorDomain";
NSString * const DailymotionApiErrorDomain = @"DailymotionApiErrorDomain";

@implementation DMAPIError

+ (NSError *)errorWithMessage:(NSString *)message domain:(NSString *)domain type:(id)type response:(NSURLResponse *)response data:(NSData *)data
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (type)
    {
        userInfo[@"error"] = [type description];
    }
    if (message)
    {
        userInfo[NSLocalizedDescriptionKey] = message;
    }
    if (response)
    {
        userInfo[@"status-code"] = [NSNumber numberWithInt:httpResponse.statusCode];

        if (httpResponse.allHeaderFields[@"Content-Type"])
        {
            userInfo[@"content-type"] = httpResponse.allHeaderFields[@"Content-Type"];
        }
    }
    if (data)
    {
        userInfo[@"content-data"] = data;
    }

    NSInteger code = 0;
    if ([type isKindOfClass:[NSNumber class]])
    {
        code = ((NSNumber *)type).intValue;
    }

    return [NSError errorWithDomain:domain code:code userInfo:userInfo];
}


@end
