//
//  DMOAuthRequestOperation.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DMNetworking;

@interface DMOAuthRequestOperation : NSOperation

@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, strong, readonly) NSDictionary *headers;
@property (nonatomic, strong, readonly) id payload;
@property (nonatomic, strong) void (^progressHandler)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite);
@property (nonatomic, strong) void (^completionHandler)(NSURLResponse *response, NSData *data, NSError *error);

- (id)initWithURL:(NSURL *)URL method:(NSString *)method headers:(NSDictionary *)headers payload:(id)payload networkQueue:(DMNetworking *)networkQueue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler;

- (void)cancel;

- (void)cancelWithError:(NSError *)error;

@end
