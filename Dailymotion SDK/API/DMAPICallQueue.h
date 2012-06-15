//
//  DMAPICallQueue.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DMAPICall.h"

@class DMAPI;

@interface DMAPICallQueue : NSObject

- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;
- (DMAPICall *)callWithId:(NSString *)callId;
- (DMAPICall *)removeCallWithId:(NSString *)callId;
- (BOOL)removeCall:(DMAPICall *)call;

- (BOOL)handleCall:(DMAPICall *)call withHandler:(id)handler;
- (void)unhandleCall:(DMAPICall *)call;
- (id)handlerForCall:(DMAPICall *)call;
- (BOOL)hasUnhandledCalls;
- (NSArray *)callsWithHandler:(id)handler;
- (NSArray *)callsWithNoHandler;

@end
