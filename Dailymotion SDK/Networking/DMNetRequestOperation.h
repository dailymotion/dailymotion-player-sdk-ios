//
//  DMNetRequestOperation.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^FailureBlock)(NSError *error);

@interface DMNetRequestOperation : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) void (^progressHandler)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite);
@property (nonatomic, strong) void (^completionHandler)(NSURLResponse *response, NSData *responseData, NSError *connectionError);

- (id)initWithRequest:(NSURLRequest *)request;

@end
