//
//  DMAPICall.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMAPICall.h"
#import "DMQueryString.h"

@interface DMAPICall ()

@property (nonatomic, copy, readwrite) NSString *callId;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, copy, readwrite) NSString *path;
@property (nonatomic, copy, readwrite) NSDictionary *args;
@property (nonatomic, strong, readwrite) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong, readwrite) DMAPICallResultBlock callback;
@property (nonatomic, assign, readwrite) BOOL isCancelled;
@end


@implementation DMAPICall

- (id)init {
    self = [super init];
    if (self) {
        _isCancelled = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DMAPICall(%@): %@ %@?%@", self.callId, self.method, self.path, [self.args stringAsQueryString]];
}

- (void)cancel {
    self.isCancelled = YES;
}

// return true if oCall is asking for exactly the same things but args["fields"]
- (BOOL)isMergeableWith:(DMAPICall *)call {
    NSMutableDictionary *cleanedArgs = [NSMutableDictionary dictionaryWithDictionary:self.args];
    [cleanedArgs removeObjectForKey:@"fields"];

    NSMutableDictionary *cleanedOArgs = [NSMutableDictionary dictionaryWithDictionary:call.args];
    [cleanedOArgs removeObjectForKey:@"fields"];
    return (!self.isCancelled && !call.isCancelled && [self.method isEqualToString:call.method] && [self.path isEqualToString:call.path] && [cleanedArgs isEqualToDictionary:cleanedOArgs]);
}

@end
