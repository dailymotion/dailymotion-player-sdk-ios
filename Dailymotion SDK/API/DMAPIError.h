//
//  DMAPIError.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const DailymotionTransportErrorDomain;
extern NSString *const DailymotionAuthErrorDomain;
extern NSString *const DailymotionApiErrorDomain;

@interface DMAPIError : NSObject

+ (NSError *)errorWithMessage:(NSString *)message domain:(NSString *)domain type:(id)type response:(NSURLResponse *)response data:(NSData *)data;

+ (NSError *)errorWithMessage:(NSString *)message domain:(NSString *)domain type:(id)type response:(NSURLResponse *)response data:(NSData *)data userInfo:(NSDictionary *)additionnalUserInfo;

@end
