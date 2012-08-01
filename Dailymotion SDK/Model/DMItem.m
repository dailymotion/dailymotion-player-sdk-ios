//
//  DMItem.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import "DMItem.h"
#import "DMAdditions.h"
#import "DMItemCollection.h"
#import "DMSubscriptingSupport.h"

@interface DMItemOperation (Private)

@property (nonatomic, strong) void (^cancelBlock)();

@end


@interface DMItem ()

@property (nonatomic, readwrite, copy) NSString *type;
@property (nonatomic, readwrite, copy) NSString *itemId;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, readwrite, strong) DMAPI *api;
@property (nonatomic, strong) NSString *_path;
@property (nonatomic, strong) NSMutableDictionary *_fieldsCache;

@end


@implementation DMItem

+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    return [[self alloc] initWithType:type forId:itemId fromAPI:api];
}

- (id)initWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    NSAssert(type != nil, @"The type cannot be nil");
    NSAssert(itemId != nil, @"The item id cannot be nil");
    NSAssert(api != nil, @"The api cannot be nil");

    if ((self = [super init]))
    {
        _type = type;
        _itemId = itemId;
        _api = api;
        __path = [NSString stringWithFormat:@"/%@/%@", type, itemId];
        __fieldsCache = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_itemId forKey:@"itemId"];
    [coder encodeObject:_cacheInfo forKey:@"cacheInfo"];
    [coder encodeObject:_api forKey:@"api"];
    [coder encodeObject:__fieldsCache forKey:@"_fieldsCache"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSString *type = [coder decodeObjectForKey:@"type"];
    NSString *itemId = [coder decodeObjectForKey:@"itemId"];
    DMAPI *api = [coder decodeObjectForKey:@"api"];

    if ((self = [self initWithType:type forId:itemId fromAPI:api]))
    {
        _cacheInfo = [coder decodeObjectForKey:@"cacheInfo"];
        __fieldsCache = [coder decodeObjectForKey:@"_fieldsCache"];
    }

    return self;
}

- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type withParams:(NSDictionary *)params
{
    return [DMItemCollection itemCollectionWithConnection:connection ofType:type forItem:self withParams:params];
}

- (BOOL)isEqual:(DMItem *)object
{
    return [object isKindOfClass:self.class] && [self.type isEqualToString:object.type] && [self.itemId isEqualToString:object.itemId];
}

- (NSUInteger)hash
{
    return self.type.hash ^ self.itemId.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@(%@): %@", self.type, self.itemId, [self._fieldsCache description]];
}

- (void)loadInfo:(NSDictionary *)info withCacheInfo:(DMAPICacheInfo *)cacheInfo
{
    __block NSMutableDictionary *fieldsCache = self._fieldsCache;

    [info enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
    {
        fieldsCache[key] = obj;
    }];

    self.cacheInfo = cacheInfo;
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
        DMAPICall *apiCall = [self.api get:self._path
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

            operation.isFinished = YES;
        }];

        operation.cancelBlock = ^{[apiCall cancel];};
    }
    else
    {
        operation.isFinished = YES;
    }

    return operation;
}

- (DMItemOperation *)editWithData:(NSDictionary *)data done:(void (^)(NSError *error))callback
{
    DMItemOperation *operation = [[DMItemOperation alloc] init];

    if (!data || data.count == 0)
    {
        operation.isFinished = YES;
        callback(nil);
        return operation;
    }

    // Apply new data to local object so UI can be updated before the API operation complete
    [self loadInfo:data withCacheInfo:self.cacheInfo];

    __weak DMItem *bself = self;
    DMAPICall *apiCall = [self.api post:self._path args:data callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
    {
        [bself flushCache];
        callback(error);
        operation.isFinished = YES;
    }];

    operation.cancelBlock = ^{[apiCall cancel];};

    return operation;
}

@end
