//
//  DMAPICall.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMAPICall.h"

@interface DMAPICall ()

@property (nonatomic, copy, readwrite) NSString *callId;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, copy, readwrite) NSString *path;
@property (nonatomic, copy, readwrite) NSDictionary *args;
@property (nonatomic, strong, readwrite) void (^callback)(id, NSError*);
@property (nonatomic, assign, readwrite) BOOL isCancelled;

@end

@implementation DMAPICall

@synthesize callId = _callId;
@synthesize method = _method;
@synthesize path = _path;
@synthesize args = _args;
@synthesize callback = _callback;
@synthesize isCancelled = _isCancelled;

- (id)init
{
    if ((self = [super init]))
    {
        _isCancelled = NO;
    }
    return self;
}

- (void)cancel
{
    self.isCancelled = YES;
}

@end