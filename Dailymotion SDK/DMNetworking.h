//
//  DMNetworking.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 08/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DMNetworkingOperation;
@class DMNetworkingShowstopperOperation;

@interface DMNetworking : NSObject

@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, assign) NSUInteger maxConcurrency;
@property (nonatomic, assign) NSUInteger timeout;

- (DMNetworkingOperation *)getURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)getURL:(NSURL *)URL headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)postURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)putURL:(NSURL *)URL payload:(id)payload headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)deleteURL:(NSURL *)URL completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;
- (DMNetworkingOperation *)deleteURL:(NSURL *)URL headers:(NSDictionary *)headers dependsOn:(NSOperation *)dependency completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

- (void)cancelAllConnections;

@end

typedef void(^FailureBlock)(NSError *error);

@interface DMNetworkingOperation : NSOperation <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, readonly) NSData *responseData;
@property (nonatomic, strong) void (^progressHandler)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite);
@property (nonatomic, strong) void (^completionHandler)(NSURLResponse *response, NSData *responseData, NSError *connectionError);

- (id)initWithRequest:(NSURLRequest *)request;

@end

@interface DMNetworkingShowstopperOperation : NSOperation

- (void)done;

@end