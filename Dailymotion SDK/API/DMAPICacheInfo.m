//
//  DMAPICacheInfo.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMAPICacheInfo.h"
#import "DMAPI.h"

static NSString *const DMAPICacheInfoInvalidatedNotification = @"DMAPICacheInfoInvalidatedNotification";

@interface DMAPICacheInfo ()

@property (nonatomic, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSString *namespace;
@property (nonatomic, readwrite) NSArray *invalidates;
@property (nonatomic, readwrite) NSString *etag;
@property (nonatomic, readwrite, assign) BOOL public;
@property (nonatomic, readwrite, assign) NSTimeInterval maxAge;
@property (nonatomic, weak) DMAPI *_api;

@end


@implementation DMAPICacheInfo
{
    BOOL _stalled;
}

- (id)initWithCacheInfo:(NSDictionary *)cacheInfo fromAPI:(DMAPI *)api
{
    if ((self = [super init]))
    {
        self.date = [NSDate date];
        self.namespace = cacheInfo[@"namespace"];
        self.invalidates = cacheInfo[@"invalidates"];
        self.etag = cacheInfo[@"etag"];
        self.public = [cacheInfo[@"public"] boolValue];
        self.maxAge = [cacheInfo[@"maxAge"] floatValue];
        self.valid = YES;

        if (self.invalidates)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:DMAPICacheInfoInvalidatedNotification
                                                                object:self.invalidates];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(invalidateNamespaces:)
                                                     name:DMAPICacheInfoInvalidatedNotification
                                                   object:nil];

        if (!self.public)
        {
            self._api = api;
            [self._api addObserver:self forKeyPath:@"oauth.session" options:0 context:NULL];
        }
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (!self.public)
    {
        [self._api removeObserver:self forKeyPath:@"oauth.session"];
    }
}

- (BOOL)stalled
{
    return _stalled || [self.date timeIntervalSinceNow] > self.maxAge;
}

- (void)setStalled:(BOOL)stalled
{
    _stalled = stalled;
}

- (void)invalidateNamespaces:(NSNotification *)notification
{
    NSArray *invalidatedNamespaces = notification.object;
    if ([invalidatedNamespaces containsObject:self.namespace])
    {
        self.stalled = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Flush cache of private objects when session change
    if (self._api == object && !self.public && [keyPath isEqualToString:@"oauth.session"])
    {
        self.valid = NO;
    }
}

@end
