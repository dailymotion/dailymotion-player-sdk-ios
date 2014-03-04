//
//  DMAPIMergedCall.m
//  Dailymotion SDK
//
//  Created by Fabrice Aneche on 24/02/14.
//
//

#import "DMAPIMergedCall.h"
#import "DMQueryString.h"

@interface DMAPIMergedCall ()
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSDictionary *args;
@property (nonatomic, copy) NSString *callId;
@property (nonatomic, assign, readwrite) BOOL isCancelled;
@end

@implementation DMAPIMergedCall

- (id)initWithCall:(DMAPICall *)call {
    self = [super init];
    if (self) {
        _calls = [NSMutableArray arrayWithCapacity:2];
        [call addObserver:self forKeyPath:@"isCancelled" options:0 context:NULL];
        [_calls addObject:call];
        self.path = call.path;
        self.method = call.method;
        self.args = call.args;
        self.callId = [NSString stringWithFormat:@"M%@", call.callId];
    }
    return self;
}

- (void)addCall:(DMAPICall *)call {
    @synchronized (self) {
        if (![self isMergeableWith:call]) return;

        //merge args[@"fields"]
        NSMutableDictionary *mArgs = [self.args mutableCopy];

        NSMutableArray *currentFields = [self.args[@"fields"] mutableCopy];
        [currentFields addObjectsFromArray:call.args[@"fields"]];
        mArgs[@"fields"] = currentFields;
        self.args = [NSDictionary dictionaryWithDictionary:mArgs];
        [call addObserver:self forKeyPath:@"isCancelled" options:0 context:NULL];
        [self.calls addObject:call];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DMAPICallS MERGED(%@): %@ %@?%@", self.callId, self.method, self.path, [self.args stringAsQueryString]];
}

- (DMAPICallResultBlock)callback {
    DMAPICallResultBlock block = ^(id result, DMAPICacheInfo *cacheInfo, NSError *error) {
        for (DMAPICall *call in self.calls) {
            if (![call isCancelled]) {
                call.callback(result, cacheInfo, error);
            }
        }
    };
    return block;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isCancelled"] && [object isKindOfClass:[DMAPICall class]] && [(DMAPICall *)object isCancelled]) {
        if (object == self) return;
        
        BOOL isTotallyCancelled = YES;
        [object removeObserver:self forKeyPath:@"isCancelled"];
        
        for (DMAPICall *call in self.calls) {
            if (!call.isCancelled) {
                isTotallyCancelled = NO;
            }
        }
        if (isTotallyCancelled) {
            self.isCancelled = YES;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

// Calling cancel on sub calls
- (void)cancel {
    for (DMAPICall *call in self.calls) {
        [call cancel];
    }
    self.isCancelled = YES;
}

- (void)dealloc {
    [self cancel];
}

@end
