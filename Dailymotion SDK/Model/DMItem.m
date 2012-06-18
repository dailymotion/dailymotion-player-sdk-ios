//
//  DMItem.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMItem.h"
#import "DMAdditions.h"

static NSCache *itemInstancesCache;

@interface DMItemOperation (Private)

@property (nonatomic, strong) void (^cancelBlock)();

@end


@interface DMItem ()

@property (nonatomic, readwrite, copy) NSString *type;
@property (nonatomic, readwrite, copy) NSString *itemId;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong) DMAPI *_api;
@property (nonatomic, strong) NSString *_path;
@property (strong) NSMutableDictionary *_fieldsCache;

@end


@implementation DMItem

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
    }

    return self;
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

- (void)flushCache
{
    [self._fieldsCache removeAllObjects];
    self.cacheInfo = nil;
}

- (BOOL)areFieldsCached:(NSArray *)fields
{
    if (self.cacheInfo && !self.cacheInfo.valid)
    {
        [self flushCache];
    }

    fields = [[NSSet setWithArray:fields] allObjects]; // Ensure unique fields
    NSDictionary *data = [self._fieldsCache dictionaryForKeys:fields];
    return [data count] == [fields count];
}

- (DMItemOperation *)withFields:(NSArray *)fields do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    if (self.cacheInfo && !self.cacheInfo.valid)
    {
        [self flushCache];
    }

    DMItemOperation *operation = [[DMItemOperation alloc] init];
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
        __weak DMAPICall *apiCall = [self._api get:self._path
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

        operation.cancelBlock = ^{[apiCall cancel];};
    }

    return operation;
}

@end
