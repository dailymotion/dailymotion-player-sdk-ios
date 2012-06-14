//
//  DMAPICallQueue.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMAPICallQueue.h"
#import "DMAPI.h"

@interface DMAPI (Cancel)

- (void)cancelCall:(DMAPICall *)call;

@end


@interface DMAPICall ()

@property (nonatomic, copy, readwrite) NSString *callId;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, copy, readwrite) NSString *path;
@property (nonatomic, copy, readwrite) NSDictionary *args;
@property (nonatomic, strong, readwrite) void (^callback)(id, NSError*);
@property (nonatomic, assign, readwrite) BOOL isCancelled;

@end

@interface DMAPICallQueue ()

@property (nonatomic, assign) NSUInteger _callNextId;
@property (nonatomic, strong) NSMutableDictionary *_callQueue;

@end

@implementation DMAPICallQueue

- (id)init
{
    if ((self = [super init]))
    {
        self._callNextId = 0;
        self._callQueue = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback
{
    @synchronized(self)
    {
        NSString *callId = [NSString stringWithFormat:@"%d", self._callNextId++];
        DMAPICall *call = [[DMAPICall alloc] init];
        call.callId = callId;
        call.path = path;
        call.method = method;
        call.args = args;
        if (callback)
        {
            call.callback = callback;
        }
        else
        {
            call.callback = ^(id result, NSError *error) {/* noop */};
        }

        [self._callQueue setObject:call forKey:callId];
        
        [call addObserver:self forKeyPath:@"isCancelled" options:0 context:NULL];

        return call;
    }
}


- (DMAPICall *)callWithId:(NSString *)callId
{
    return [self._callQueue objectForKey:callId];
}

- (DMAPICall *)removeCallWithId:(NSString *)callId
{
    @synchronized(self)
    {
        DMAPICall *call = [self callWithId:callId];
        [call removeObserver:self forKeyPath:@"isCancelled"];
        [self._callQueue removeObjectForKey:callId];
        return call;
    }
}

- (BOOL)removeCall:(DMAPICall *)call
{
    @synchronized(self)
    {
        if ([self._callQueue objectForKey:call.callId])
        {
            [call removeObserver:self forKeyPath:@"isCancelled"];
            [self._callQueue removeObjectForKey:call.callId];
            return YES;
        }
        else
        {
            return NO;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"isCancelled"] && [object isKindOfClass:[DMAPICall class]] && [(DMAPICall *)object isCancelled])
    {
        [self.delegate cancelCall:object];
    }
}

@end
