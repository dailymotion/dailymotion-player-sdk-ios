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

@property (nonatomic, weak) DMAPI *delegate;

- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;
- (DMAPICall *)callWithId:(NSString *)callId;
- (DMAPICall *)removeCallWithId:(NSString *)callId;
- (BOOL)removeCall:(DMAPICall *)call;

@end
