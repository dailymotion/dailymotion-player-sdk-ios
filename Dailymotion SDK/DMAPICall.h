//
//  DMAPICall.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMAPICall : NSObject

@property (nonatomic, copy, readonly) NSString *callId;
@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSDictionary *args;
@property (nonatomic, strong, readonly) void (^callback)(id, NSError*);
@property (nonatomic, assign, readonly) BOOL isCancelled;

- (void)cancel;

@end