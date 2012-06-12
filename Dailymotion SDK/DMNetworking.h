//
//  DMNetworking.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 08/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DMNetRequestOperation.h"

@class DMNetworkingShowstopperOperation;

@interface DMNetworking : NSObject

@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, assign) NSUInteger maxConcurrency;
@property (nonatomic, assign) NSUInteger timeout;

- (DMNetRequestOperation *)getURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)deleteURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

- (void)cancelAllConnections;

@end