//
//  DMAPICall.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DMAPICacheInfo.h"

typedef void (^DMAPICallResultBlock)(id result, DMAPICacheInfo *cacheInfo, NSError *error);

@interface DMAPICall : NSObject

@property (nonatomic, copy, readonly) NSString *callId;
@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSDictionary *args;
@property (nonatomic, strong, readonly) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong, readonly) DMAPICallResultBlock callback;
@property (nonatomic, assign, readonly) BOOL isCancelled;

@property (nonatomic, strong) DMAPICall *parent;

// is this call mergeable with oCall
// mergeable stands for same requests with differents or same fields
- (BOOL)isMergeableWith:(DMAPICall *)oCall;

- (void)cancel;

@end
