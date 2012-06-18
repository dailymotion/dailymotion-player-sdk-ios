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

/**
 * Easier to use interface on tope of NSURLConnection using NSOperation to handle maximum settable
 * maximum concurrent connection limit.
 */
@interface DMNetworking : NSObject

/**
 * Set this value to customize the userAgent.
 *
 * Nil value means default NSURLConnection user-agent.
 */
@property (nonatomic, copy) NSString *userAgent;

/**
 * Set the maximum number of concurrent connection allowed for this network queue.
 */
@property (nonatomic, assign) NSUInteger maxConcurrency;

/**
 * Defines the default timeout for connections created in this queue
 */
@property (nonatomic, assign) NSUInteger timeout;

/**
 * A global accross all queues number of requests sent by this call for accounting
 */
+ (NSUInteger)totalRequestCount;

/**
 * Perform a GET request
 */
- (DMNetRequestOperation *)getURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a GET request with custom additional headers
 */
- (DMNetRequestOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a POST request with a given payload
 */
- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a POST request with a given payload and some custom additional headers
 */
- (DMNetRequestOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a PUT request with a given payload
 */
- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a PUT request with a given payload and some custom additional headers
 */
- (DMNetRequestOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a DELETE request
 */
- (DMNetRequestOperation *)deleteURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform a DELETE request with some custom additional headers
 */
- (DMNetRequestOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Perform ah HTTP request
 *
 * @param URL The URL of the request
 * @param method The HTTP method of the request
 * @param payload The request body
 * @param headers The request additional headers
 * @param cachePolicy The NSURLRequestCachePolicy to use for this request
 * @param handler The block to be called once request is completed
 *
 * @return A DMNetRequestOperation setup and queued in the current network queue
 */
- (DMNetRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Cancel all currently running requests of this queue
 */
- (void)cancelAllConnections;

@end