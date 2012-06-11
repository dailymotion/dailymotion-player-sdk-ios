//
//  DMAPICallQueue.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DMAPI;
@class DMAPICall;

@interface DMAPICallQueue : NSObject

@property (nonatomic, unsafe_unretained) DMAPI *delegate;

- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;
- (DMAPICall *)callWithId:(NSString *)callId;
- (DMAPICall *)removeCallWithId:(NSString *)callId;

@end


@interface DMAPICall : NSObject

@property (nonatomic, copy, readonly) NSString *callId;
@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSDictionary *args;
@property (nonatomic, strong, readonly) void (^callback)(id, NSError*);
@property (nonatomic, assign, readonly) BOOL isCancelled;

- (void)cancel;

@end