//
//  DMAPICacheInfo.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMAPICacheInfo.h"

@interface DMAPICacheInfo ()

@property (nonatomic, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSString *namespace;
@property (nonatomic, readwrite) NSArray *invalidates;
@property (nonatomic, readwrite) NSString *etag;
@property (nonatomic, readwrite, assign) BOOL public;
@property (nonatomic, readwrite, assign) NSTimeInterval maxAge;

@end


@implementation DMAPICacheInfo
{
    BOOL _stalled;
}

- (id)initWithCacheInfo:(NSDictionary *)cacheInfo
{
    if ((self = [super init]))
    {
        self.date = [NSDate date];
        self.namespace = cacheInfo[@"namespace"];
        self.invalidates = cacheInfo[@"invalidates"];
        self.etag = cacheInfo[@"etag"];
        self.public = [cacheInfo[@"public"] boolValue];
        self.maxAge = [cacheInfo[@"maxAge"] floatValue];
    }

    return self;
}

- (BOOL)stalled
{
    return _stalled || [self.date timeIntervalSinceNow] > self.maxAge;
}

- (void)setStalled:(BOOL)stalled
{
    _stalled = stalled;
}

@end
