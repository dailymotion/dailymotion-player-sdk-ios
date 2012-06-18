//
//  DMItemCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "DMItemCollection.h"
#import "DMAPI.h"
#import "DMQueryString.h"
#import "DMAdditions.h"

static NSString *const DMEndOfList = @"DMEndOfList";
static NSCache *itemCollectionInstancesCache;

@implementation NSString (Plural)

- (NSString *)stringByApplyingPluralForm
{
    if (self.length == 0) return self;
    if ([self characterAtIndex:self.length - 1] == 'y')
    {
        return [[self substringToIndex:self.length - 1] stringByAppendingString:@"ies"];
    }
    else
    {
        return [self stringByAppendingString:@"s"];
    }
}

@end


@interface DMItemOperation (Private)

@property (nonatomic, strong) void (^cancelBlock)();

@end


@interface DMItem ()

- (void)loadInfo:(NSDictionary *)info;

@end


@interface DMItemCollection ()

@property (nonatomic, readwrite, copy) NSString *type;
@property (nonatomic, readwrite, copy) NSDictionary *params;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong) DMAPI *_api;
@property (nonatomic, strong) NSString *_path;
@property (nonatomic, strong) NSMutableArray *_cache;
@property (nonatomic, assign) NSInteger _total;

@end


@implementation DMItemCollection

+ (void)initialize
{
    itemCollectionInstancesCache = [[NSCache alloc] init];
    itemCollectionInstancesCache.countLimit = 10;
}

+ (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", type, [params stringAsQueryString]];
    DMItemCollection *itemCollection = [itemCollectionInstancesCache objectForKey:cacheKey];
    if (!itemCollection)
    {
        itemCollection = [[self alloc] initWithType:type
                                             params:params
                                               path:[NSString stringWithFormat:@"/%@", [type stringByApplyingPluralForm]]
                                            fromAPI:api];
    }

    return itemCollection;
}

+ (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@:%@:%@", item.type, item.itemId, connection, [params stringAsQueryString]];
    DMItemCollection *itemCollection = [itemCollectionInstancesCache objectForKey:cacheKey];
    if (!itemCollection)
    {
        itemCollection = [[self alloc] initWithType:item.type
                                             params:params
                                               path:[NSString stringWithFormat:@"/%@/%@/%@", item.type, item.itemId, connection]
                                            fromAPI:api];
    }

    return itemCollection;
}

- (id)initWithType:(NSString *)type params:(NSDictionary *)params path:(NSString *)path fromAPI:(DMAPI *)api
{
    if ((self = [super init]))
    {
        self.type = type;
        self.params = params;
        self._api = api;
        self._path = path;
        self._cache = [NSMutableArray array];
    }
    return self;
}

- (DMItemOperation *)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback
{
    if (self.cacheInfo && !self.cacheInfo.valid)
    {
        [self flushCache];
    }

    DMItemOperation *operation = [[DMItemOperation alloc] init];
    NSNull *null = [NSNull null];
    BOOL cacheValid = YES;
    BOOL cacheStalled = self.cacheInfo ? self.cacheInfo.stalled : YES;
    BOOL more = NO;
    NSMutableArray *items = [NSMutableArray array];

    // Check the cache contains the end of list marker, and if this marker is not before the requested page
    NSUInteger lastItemIndex = [self._cache indexOfObject:DMEndOfList];
    NSUInteger firstPageIndex = (page - 1) * itemsPerPage - 1;
    NSUInteger lastPageIndex = firstPageIndex + itemsPerPage;
    if (lastItemIndex != NSNotFound && lastItemIndex <= firstPageIndex)
    {
        cacheValid = NO;
    }

    // Check if all items are loaded
    if (cacheValid)
    {
        more = lastItemIndex == NSNotFound || lastItemIndex > lastPageIndex;
        // If the end of list marker is in this page, shrink the range to match the number or remaining pages
        NSUInteger length = !more ? lastItemIndex - firstPageIndex - 1 : itemsPerPage;
        NSArray *cachedItemIds = [self._cache objectsInRange:NSMakeRange(page, length) notFoundMarker:null];
        DMItem *item;

        for (id itemId in cachedItemIds)
        {
            if (itemId == null)
            {
                cacheValid = NO;
                break;
            }
            else if (itemId == DMEndOfList)
            {
                NSAssert(NO, @"Unexpected present of the end-of-list marker");
            }
            else
            {
                item = [DMItem itemWithType:self.type forId:itemId fromAPI:self._api];
                if (![item areFieldsCached:fields])
                {
                    items = nil;
                    cacheValid = NO;
                    break;
                }
                if (item.cacheInfo.stalled)
                {
                    cacheStalled = YES;
                }
                [items addObject:item];
            }
        }
#ifdef DEBUG
        NSLog(@"CACHE-HIT %@: page:%d, itemsPerPage: %d, lastIndexItem: %d, firstPageIndex: %d, lastPageIndex: %d, length: %d, more: %@",
              self._path, page, itemsPerPage, lastItemIndex != NSNotFound ? lastItemIndex : -1, firstPageIndex, lastPageIndex, length, more);
    }
    else
    {
        NSLog(@"CACHE-MISS %@: page:%d, itemsPerPage: %d, lastIndexItem: %d, firstPageIndex: %d, lastPageIndex: %d",
              self._path, page, itemsPerPage, lastItemIndex != NSNotFound ? lastItemIndex : -1, firstPageIndex, lastPageIndex);
#endif
    }

    if (cacheValid)
    {
        callback(items, more, self._total, cacheStalled, nil);
    }

    if (!cacheValid || cacheStalled)
    {
        __weak DMAPICall *apiCall = [self loadItemsWithFields:fields forPage:page withPageSize:itemsPerPage do:callback];
        operation.cancelBlock = ^{[apiCall cancel];};
    }

    return operation;
}

- (DMAPICall *)loadItemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback
{
    NSMutableDictionary *params = [self.params mutableCopy];
    params[@"page"] = [NSNumber numberWithInt:page];
    params[@"limit"] = [NSNumber numberWithInt:itemsPerPage];

    NSMutableSet *fieldsSet = [NSMutableSet setWithArray:fields];
    [fieldsSet addObject:@"id"]; // Enforce id retrival
    params[@"fields"] = [fieldsSet allObjects];

    __weak DMItemCollection *bself = self;

    return [self._api get:self._path args:params cacheInfo:nil callback:^(NSDictionary *result, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        if (error)
        {
            callback(nil, NO, -1, NO, error);
            return;
        }

        NSArray *list = result[@"list"];
        if (!list)
        {
            callback(@[], NO, -1, NO, nil);
            return;
        }

        self.cacheInfo = cacheInfo;
        self._total = result[@"total"] ? [result[@"total"] intValue] : -1;
        BOOL more = [result[@"has_more"] boolValue];
        NSMutableArray *ids = [NSMutableArray arrayWithCapacity:itemsPerPage];
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:itemsPerPage];

        for (NSDictionary *itemData in list)
        {
            DMItem *item = [DMItem itemWithType:bself.type forId:itemData[@"id"] fromAPI:bself._api];
            [item loadInfo:itemData];
            [items addObject:item];
            [ids addObject:itemData[@"id"]];
        }

        [bself._cache replaceObjectsInRange:NSMakeRange(page, [ids count]) withObjectsFromArray:ids fillWithObject:[NSNull null]];

        if (!more)
        {
            // Add an end-of-list marker
            NSUInteger lastCacheIndex = [bself._cache count] - 1;
            NSUInteger eolIndex = (page - 1) * itemsPerPage + [ids count];
            if (lastCacheIndex == eolIndex - 1)
            {
                [bself._cache addObject:DMEndOfList];
            }
            else if (lastCacheIndex < eolIndex - 1)
            {
                // Cache was smaller than new actual size
                [bself._cache raise:eolIndex withObject:[NSNull null]];
                [bself._cache addObject:DMEndOfList];
            }
            else
            {
                // Cache was larger than new actual size
                bself._cache[eolIndex] = DMEndOfList;
                // Shrink the cache to the new size
                [bself._cache shrink:eolIndex + 1];
            }
        }
        else if (page > 1)
        {
            // Handle when actual list raised by more than one page compared to cache
            [self._cache removeObject:DMEndOfList inRange:NSMakeRange(0, (page - 1) * itemsPerPage - 1)];
        }

        callback(items, more, self._total, NO, nil);
    }];
}

- (void)flushCache
{
    [self._cache removeAllObjects];
}

@end
