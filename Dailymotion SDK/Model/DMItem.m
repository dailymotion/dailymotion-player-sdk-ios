//
//  DMItem.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMItem.h"
#import "NSDictionary+DMAdditions.h"

static NSString *const DMItemCacheNamespaceInvalidatedNotification = @"DMItemCacheNamespaceInvalidatedNotification";
static NSCache *itemInstancesCache;

@interface DMItem ()

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite, copy) NSString *itemId;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong) DMAPI *_api;
@property (nonatomic, strong) NSString *_path;
@property (strong) NSMutableDictionary *_fieldsCache;

@end

@implementation DMItem
{
    DMAPICacheInfo *_cacheInfo;
}

+ (void)initialize
{
    itemInstancesCache = [[NSCache alloc] init];
    itemInstancesCache.countLimit = 500;
}

+ (DMItem *)itemWithName:(NSString *)name forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", name, itemId];
    DMItem *item = [itemInstancesCache objectForKey:cacheKey];
    if (!item)
    {
        item = [[self alloc] initWithName:name forId:itemId fromAPI:api];
    }

    return item;
}

- (id)initWithName:(NSString *)name forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    if ((self = [super init]))
    {
        self.name = name;
        self.itemId = itemId;
        self._api = api;
        self._path = [NSString stringWithFormat:@"/%@/%@", name, itemId];
        self._fieldsCache = [[NSMutableDictionary alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(invalidateNamespaces:)
                                                     name:DMItemCacheNamespaceInvalidatedNotification
                                                   object:nil];

        [self._api addObserver:self forKeyPath:@"session" options:0 context:NULL];
    }

    return self;
}

- (void)dealloc
{
    [self._api removeObserver:self forKeyPath:@"session"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (DMAPICacheInfo *)cacheInfo
{
    return _cacheInfo;
}

- (void)setCacheInfo:(DMAPICacheInfo *)cacheInfo
{
    _cacheInfo = cacheInfo;
    if (cacheInfo.invalidates)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemCacheNamespaceInvalidatedNotification
                                                            object:cacheInfo.invalidates];
    }
}

- (void)flushCache
{
    [self._fieldsCache removeAllObjects];
    self.cacheInfo = nil;
}

- (void)withFields:(NSArray *)fields do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    NSDictionary *data = [self._fieldsCache dictionaryForKeys:fields];
    BOOL allFieldsCached = [[data allKeysForObject:[NSNull null]] count] == 0;
    BOOL someFieldsCached = allFieldsCached || [[data allKeysForObject:[NSNull null]] count] < [fields count];
    BOOL cacheStalled = self.cacheInfo ? self.cacheInfo.stalled : YES;

    if (someFieldsCached)
    {
        callback(allFieldsCached ? data : [data dictionaryByFilteringNullValues], cacheStalled || !allFieldsCached, nil);
    }

    if (!allFieldsCached || cacheStalled)
    {
        NSArray *fieldsToLoad = fields;
        if (!allFieldsCached && !cacheStalled)
        {
            // Only load the missing fields if the cache is still valid
            fieldsToLoad = [data allKeysForObject:[NSNull null]];
        }

        // Perform conditional request only if we already have all requested fields in cache
        BOOL conditionalRequest = allFieldsCached && cacheStalled;

        __weak DMItem *bself = self;

        [self._api get:self._path
                  args:@{@"fields": fieldsToLoad}
             cacheInfo:(conditionalRequest ? self.cacheInfo : nil)
              callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
        {
            bself.cacheInfo = cache;

            if (error)
            {
                callback(nil, NO, error);
            }
            else
            {
                [result enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop)
                {
                    [bself._fieldsCache setObject:object forKey:key];
                }];

                callback([bself._fieldsCache dictionaryForKeys:fields], NO, nil);
            }
        }];
    }
}

#pragma mark - Event Handlers

- (void)invalidateNamespaces:(NSNotification *)notification
{
    NSArray *invalidatedNamespaces = notification.object;
    if ([invalidatedNamespaces containsObject:self.cacheInfo.namespace])
    {
        self.cacheInfo.stalled = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Flush cache of private objects when session change
    if (self._api == object && self.cacheInfo && !self.cacheInfo.public && [keyPath isEqualToString:@"session"])
    {
        [self flushCache];
    }
}

@end
