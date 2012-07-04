//
//  DMAPICallQueue.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMAPICallQueue.h"
#import "DMAPI.h"
#import "DMAdditions.h"
#import "DMSubscriptingSupport.h"

@interface DMAPICall ()

@property (nonatomic, copy, readwrite) NSString *callId;
@property (nonatomic, copy, readwrite) NSString *method;
@property (nonatomic, copy, readwrite) NSString *path;
@property (nonatomic, copy, readwrite) NSDictionary *args;
@property (nonatomic, strong, readwrite) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong, readwrite) DMAPICallResultBlock callback;
@property (nonatomic, assign, readwrite) BOOL isCancelled;

@end

@interface DMAPICallQueue ()

@property (nonatomic, assign) NSUInteger _callNextId;
@property (nonatomic, strong) NSMutableDictionary *_callQueue;
@property (nonatomic, strong) NSMutableDictionary *_callHandlers;

@end

@implementation DMAPICallQueue

- (id)init
{
    if ((self = [super init]))
    {
        _count = 0;
        __callNextId = 0;
        __callQueue = [[NSMutableDictionary alloc] init];
        __callHandlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Queue

- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback
{
    @synchronized(self)
    {
        NSString *callId = [NSString stringWithFormat:@"%d", self._callNextId++];
        DMAPICall *call = [[DMAPICall alloc] init];
        call.callId = callId;
        call.path = path;
        call.method = method;
        call.args = args;
        call.cacheInfo = cacheInfo;
        if (callback)
        {
            call.callback = callback;
        }
        else
        {
            call.callback = ^(id result, DMAPICacheInfo *cache, NSError *error) {/* noop */};
        }

        self._callQueue[callId] = call;
        self._callHandlers[callId] = [NSNull null];

        [call addObserver:self forKeyPath:@"isCancelled" options:0 context:NULL];

        self.count = [self._callQueue.allValues count];
        return call;
    }
}


- (DMAPICall *)callWithId:(NSString *)callId
{
    return self._callQueue[callId];
}

- (DMAPICall *)removeCallWithId:(NSString *)callId
{
    @synchronized(self)
    {
        DMAPICall *call = [self callWithId:callId];
        [call removeObserver:self forKeyPath:@"isCancelled"];
        [self._callQueue removeObjectForKey:callId];
        [self._callHandlers removeObjectForKey:callId];
        self.count = [self._callQueue.allValues count];
        return call;
    }
}

- (BOOL)removeCall:(DMAPICall *)call
{
    @synchronized(self)
    {
        if (self._callQueue[call.callId])
        {
            [call removeObserver:self forKeyPath:@"isCancelled"];
            [self._callQueue removeObjectForKey:call.callId];
            [self._callHandlers removeObjectForKey:call.callId];
            self.count = [self._callQueue.allValues count];
            return YES;
        }
        else
        {
            return NO;
        }
    }
}


#pragma mark - Call Handlers

- (BOOL)handleCall:(DMAPICall *)call withHandler:(id)handler
{
    if ([self._callHandlers[call.callId] isEqual:[NSNull null]])
    {
        self._callHandlers[call.callId] = handler;
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)unhandleCall:(DMAPICall *)call
{
    self._callHandlers[call.callId] = [NSNull null];
}

- (id)handlerForCall:(DMAPICall *)call
{
    if ([self._callHandlers[call.callId] isEqual:[NSNull null]])
    {
        return nil;
    }
    else
    {
        return self._callHandlers[call.callId];
    }
}

- (NSSet *)handlersOfKind:(Class)kind
{
    NSMutableSet *handlers = [NSMutableSet set];
    [self._callHandlers.allValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        if ([obj isKindOfClass:kind])
        {
            [handlers addObject:obj];
        }
    }];
    return handlers;
}

- (BOOL)hasUnhandledCalls
{
    return [[self._callHandlers allKeysForObject:[NSNull null]] count] > 0;
}

- (NSArray *)callsWithHandler:(id)handler
{
    return [self._callQueue objectsForExistingKeys:[self._callHandlers allKeysForObject:handler]];
}

- (NSArray *)callsWithNoHandler
{
    return [[self callsWithHandler:[NSNull null]] sortedArrayUsingComparator:^NSComparisonResult(DMAPICall *call1, DMAPICall *call2)
    {
        return [call1.callId compare:call2.callId options:NSNumericSearch];
    }];
}


#pragma mark - Events

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"isCancelled"] && [object isKindOfClass:[DMAPICall class]] && [(DMAPICall *)object isCancelled])
    {
        [self cancelCall:object];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)cancelCall:(DMAPICall *)call
{
    id handler = [self handlerForCall:call];
    if (!handler)
    {
        // The call hasn't been handled yet, just forget it
        [self removeCall:call];
    }
    else if ([handler respondsToSelector:@selector(cancel)])
    {
        // The call has been handled and is cancellabled but it may be part of a batch request
        BOOL requestCancellable = YES;
        for (DMAPICall *queuedCall in [self callsWithHandler:handler])
        {
            if (queuedCall != call && ![queuedCall isCancelled])
            {
                requestCancellable = NO;
                break;
            }
        }

        if (requestCancellable)
        {
            // All sibbling calls of the cancelled call batch are cancelled
            // => we can cancel the whole handler
            [handler performSelector:@selector(cancel)];
            for (DMAPICall *canceledCall in [self callsWithHandler:handler])
            {
                [self removeCall:canceledCall];
            }
        }
        else
        {
            // Some calls sibbling calls in the same batch request are not cancelled
            // => the cancelled call will be ignored on result
            // nothing to do here
        }
    }
}


@end
