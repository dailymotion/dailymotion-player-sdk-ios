//
//  DMItem.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMItem.h"
#import "DMAdditions.h"

static NSString *const DMItemCacheNamespaceInvalidatedNotification = @"DMItemCacheNamespaceInvalidatedNotification";
static NSCache *itemInstancesCache;

@interface DMItem ()

@property (nonatomic, readwrite, copy) NSString *type;
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

+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", type, itemId];
    DMItem *item = [itemInstancesCache objectForKey:cacheKey];
    if (!item)
    {
        item = [[self alloc] initWithType:type forId:itemId fromAPI:api];
    }

    return item;
}

- (id)initWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    if ((self = [super init]))
    {
        self.type = type;
        self.itemId = itemId;
        self._api = api;
        self._path = [NSString stringWithFormat:@"/%@/%@", type, itemId];
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

- (NSString *)description
{
    return [self._fieldsCache description];
}

- (void)loadInfo:(NSDictionary *)info
{
    __block NSMutableDictionary *fieldsCache = self._fieldsCache;

    [info enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
    {
        fieldsCache[key] = obj;
    }];

    self.cacheInfo = nil;
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

- (BOOL)areFieldsCached:(NSArray *)fields
{
    fields = [[NSSet setWithArray:fields] allObjects]; // Ensure unique fields
    NSDictionary *data = [self._fieldsCache dictionaryForKeys:fields];
    return [data count] == [fields count];
}

- (void)withFields:(NSArray *)fields do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    fields = [[NSSet setWithArray:fields] allObjects]; // Ensure unique fields
    NSDictionary *data = [self._fieldsCache dictionaryForKeys:fields];
    BOOL allFieldsCached = [data count] == [fields count];
    BOOL someFieldsCached = allFieldsCached || [data count] > 0;
    BOOL cacheStalled = self.cacheInfo ? self.cacheInfo.stalled : YES;

    if (someFieldsCached)
    {
        callback(data, cacheStalled || !allFieldsCached, nil);
    }

    if (!allFieldsCached || cacheStalled)
    {
        NSArray *fieldsToLoad = fields;
        if (!allFieldsCached && !cacheStalled)
        {
            // Only load the missing fields if the cache is still valid
            fieldsToLoad = [data allMissingKeysForKeys:fields];
        }

        // Perform conditional request only if we already have all requested fields in cache
        BOOL conditionalRequest = allFieldsCached && cacheStalled;

        __weak DMItem *bself = self;

        [self._api get:self._path
                  args:@{@"fields": fieldsToLoad}
             cacheInfo:(conditionalRequest ? self.cacheInfo : nil)
              callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
        {
            if (!error && bself.cacheInfo.etag && cache.etag && ![bself.cacheInfo.etag isEqualToString:cache.etag])
            {
                // If new etag is different from previous etag, clear already cached fields
                [bself flushCache];
            }

            bself.cacheInfo = cache;

            if (error)
            {
                callback(nil, NO, error);
            }
            else
            {
                [result enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop)
                {
                    bself._fieldsCache[key] = object;
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
