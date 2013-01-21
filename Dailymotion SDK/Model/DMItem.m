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

+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId
{
    return [self itemWithType:type forId:itemId fromAPI:DMAPI.sharedAPI];
}

+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    return [[self alloc] initWithType:type forId:itemId fromAPI:api];
}

- (id)initWithType:(NSString *)type forId:(NSString *)itemId
{
    return [self initWithType:type forId:itemId fromAPI:DMAPI.sharedAPI];
}

- (id)initWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api
{
    NSParameterAssert(type != nil);
    NSParameterAssert(itemId != nil);
    NSParameterAssert(api != nil);
    NSParameterAssert([type isKindOfClass:NSString.class]);
    NSParameterAssert([itemId isKindOfClass:NSString.class]);
    NSParameterAssert([api isKindOfClass:DMAPI.class]);

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

- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type
{
    return [DMItemCollection itemCollectionWithConnection:connection ofType:type forItem:self];
}

- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type withParams:(NSDictionary *)params
{
    return [DMItemCollection itemCollectionWithConnection:connection ofType:type forItem:self withParams:params];
}

- (BOOL)isEqual:(DMItem *)object
{
    BOOL eq = [object isKindOfClass:self.class] && [self.type isEqualToString:object.type] && [self.itemId isEqualToString:object.itemId];

    if (eq && [self.type isEqualToString:@"tile"] && self.cachedFields[@"video"])
    {
        // Fragile workaround to search results behing same tile id with different video property
        eq = [self.cachedFields[@"video"] isEqualToString:object.cachedFields[@"video"]];
    }

    return eq;
}

- (NSUInteger)hash
{
    return self.type.hash ^ self.itemId.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@(%@): %@", self.type, self.itemId, [self._fieldsCache description]];
}

- (NSDictionary *)cachedFields
{
    return [NSDictionary dictionaryWithDictionary:self._fieldsCache];
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
    NSDictionary *data = [self._fieldsCache dictionaryForKeys:fields options:DMDictionaryOptionFilterNullValues];
    BOOL allFieldsCached = [self areFieldsCached:fields];
    BOOL someFieldsCached = allFieldsCached || [data count] > 0;
    BOOL cacheStalled = self.cacheInfo ? self.cacheInfo.stalled : YES;

    if (someFieldsCached)
    {
        callback(data, cacheStalled || !allFieldsCached, nil);
    }

    if (!allFieldsCached || cacheStalled)
    {
        // Perform conditional request only if we already have all requested fields in cache
        BOOL conditionalRequest = allFieldsCached && cacheStalled;

        __weak DMItem *wself = self;
        DMAPICall *apiCall = [self.api get:self._path
                                      args:@{@"fields": fields}
                                 cacheInfo:(conditionalRequest ? self.cacheInfo : nil)
                                  callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
        {
            if (!wself) return;
            __strong DMItem *sself = wself;
            if (!error && sself.cacheInfo.etag && cache.etag && ![sself.cacheInfo.etag isEqualToString:cache.etag])
            {
                // If new etag is different from previous etag, clear already cached fields
                [sself flushCache];
            }

            sself.cacheInfo = cache;

            if (error)
            {
                callback(nil, NO, error);
            }
            else
            {
                [result enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop)
                {
                    sself._fieldsCache[key] = object;
                }];

                if (result[@"id"] && ![self.itemId isEqualToString:result[@"id"]])
                {
                    // The id of the item in response has changed, this can happen when using an id alias like "me"
                    sself.itemId = result[@"id"];
                }

                callback([sself._fieldsCache dictionaryForKeys:fields options:DMDictionaryOptionFilterNullValues], NO, nil);
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

    __weak DMItem *wself = self;
    DMAPICall *apiCall = [self.api post:self._path args:data callback:^(NSDictionary *result, DMAPICacheInfo *cache, NSError *error)
    {
        if (!wself) return;
        __strong DMItem *sself = wself;
        [sself flushCache];
        callback(error);
        operation.isFinished = YES;
    }];

    operation.cancelBlock = ^{[apiCall cancel];};

    return operation;
}

- (DMItemOperation *)subItemWithType:(NSString *)type forField:(NSString *)subItemField done:(void (^)(DMItem *item, NSError *error))callback
{
    DMItemOperation *operation;

    NSString *itemId;

    if ((itemId = self._fieldsCache[subItemField]) || (itemId = self._fieldsCache[[subItemField stringByAppendingString:@".id"]]))
    {
        operation = DMItemOperation.new;
        operation.isFinished = YES;
        NSString *fieldPrefix = [subItemField stringByAppendingString:@"."];
        NSMutableDictionary *subItemCache = NSMutableDictionary.dictionary;
        [self._fieldsCache enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop)
        {
            if ([key hasPrefix:fieldPrefix])
            {
                subItemCache[[key substringFromIndex:fieldPrefix.length]] = value;
            }
        }];
        DMItem *subItem = [DMItem itemWithType:type forId:itemId];
        subItem._fieldsCache = subItemCache;
        callback(subItem, nil);
    }
    else
    {
        operation = [self withFields:@[subItemField] do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (error)
            {
                callback(nil, error);
            }
            else if (!data[subItemField])
            {
                callback(nil, nil);
            }
            else
            {
                callback([DMItem itemWithType:type forId:data[subItemField]], nil);
            }
        }];
    }

    return operation;
}

@end
