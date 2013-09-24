//
//  DMAPICacheInfo.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMAPICacheInfo.h"
#import "DMAPI.h"

NSString *const DMAPICacheInfoInvalidatedNotification = @"DMAPICacheInfoInvalidatedNotification";

@interface DMAPICacheInfo ()

@property (nonatomic, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSString *namespace;
@property (nonatomic, readwrite) NSArray *invalidates;
@property (nonatomic, readwrite) NSString *etag;
@property (nonatomic, readwrite, assign) BOOL public;
@property (nonatomic, readwrite, assign) NSTimeInterval maxAge;
@property (nonatomic, weak) DMAPI *api;

@end


@implementation DMAPICacheInfo
{
    BOOL _stalled;
}

- (id)initWithCacheInfo:(NSDictionary *)cacheInfo fromAPI:(DMAPI *)api
{
    self = [super init];
    if (self)
    {
        _date = [NSDate date];
        _namespace = cacheInfo[@"namespace"];
        _invalidates = cacheInfo[@"invalidates"];
        _etag = cacheInfo[@"etag"];
        _public = [cacheInfo[@"public"] boolValue];
        _maxAge = MAX([cacheInfo[@"maxAge"] floatValue], 900);
        _valid = YES;

        if (_invalidates)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:DMAPICacheInfoInvalidatedNotification
                                                                object:self.invalidates];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(invalidateNamespaces:)
                                                     name:DMAPICacheInfoInvalidatedNotification
                                                   object:nil];

        if (!_public)
        {
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSMutableDictionary *cacheInfo = [NSMutableDictionary dictionary];
    if (_namespace) cacheInfo[@"namespace"] = _namespace;
    // Do not archive invalidates as we don't want to invalidate current cached data on unarchiving
    // if (_invalidates) cacheInfo[@"invalidates"] = _invalidates;
    if (_etag) cacheInfo[@"etag"] = _etag;
    cacheInfo[@"public"] = [NSNumber numberWithBool:_public];
    cacheInfo[@"maxAge"] = [NSNumber numberWithFloat:_maxAge];
    [coder encodeObject:cacheInfo forKey:@"cacheInfo"];
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeBool:_valid forKey:@"valid"];
    [coder encodeBool:_stalled forKey:@"stalled"];
    [coder encodeObject:_api forKey:@"_api"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSDictionary *cacheInfo = [coder decodeObjectForKey:@"cacheInfo"];
    DMAPI *api = [coder decodeObjectForKey:@"_api"];

    self = [self initWithCacheInfo:cacheInfo fromAPI:api];
    if (self)
    {
        _date = [coder decodeObjectForKey:@"date"];
        _valid = [coder decodeBoolForKey:@"valid"];
        _stalled = [coder decodeBoolForKey:@"stalled"];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (!self.public)
    {
        [self.api removeObserver:self forKeyPath:@"oauth.session"];
    }
}

- (BOOL)stalled
{
    return _stalled || [NSDate.date timeIntervalSinceDate:self.date] > self.maxAge;
}

- (void)setStalled:(BOOL)stalled
{
    _stalled = stalled;
}

- (void)invalidateNamespaces:(NSNotification *)notification
{
    NSArray *invalidatedNamespaces = notification.object;
    if ([invalidatedNamespaces containsObject:self.namespace] || [invalidatedNamespaces containsObject:@"*"])
    {
        self.stalled = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Flush cache of private objects when session change
    if (self.api == object && !self.public && [keyPath isEqualToString:@"oauth.session"])
    {
        self.valid = NO;
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
