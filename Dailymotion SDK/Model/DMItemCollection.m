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

- (void)loadInfo:(NSDictionary *)info withCacheInfo:(DMAPICacheInfo *)cacheInfo;

@end


@interface DMItemCollection ()

@property (nonatomic, readwrite, copy) NSString *type;
@property (nonatomic, readwrite, copy) NSDictionary *params;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, readwrite, assign) NSUInteger pageSize;
@property (nonatomic, readwrite, assign) NSUInteger currentEstimatedTotalItemsCount;
@property (nonatomic, strong) DMAPI *_api;
@property (nonatomic, strong) NSString *_path;
@property (nonatomic, strong) NSMutableArray *_cache;
@property (nonatomic, assign) NSInteger _total;
@property (nonatomic, strong) NSMutableDictionary *_runningRequests;

@end


@implementation DMItemCollection

+ (void)initialize
{
    itemCollectionInstancesCache = [[NSCache alloc] init];
    itemCollectionInstancesCache.countLimit = 10;

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                      object:nil
                                                       queue:nil usingBlock:^(NSNotification *note)
    {
        [itemCollectionInstancesCache removeAllObjects];
    }];
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
        [itemCollectionInstancesCache setObject:itemCollection forKey:cacheKey];
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
        _type = type;
        _params = params;
        _pageSize = 25;
        _currentEstimatedTotalItemsCount = 0;
        __api = api;
        __path = path;
        __cache = [NSMutableArray array];
        __runningRequests = [NSMutableDictionary dictionary];
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

    @synchronized(self._cache)
    {
        // Check the cache contains the end of list marker, and if this marker is not before the requested page
        NSUInteger lastItemIndex = [self._cache indexOfObject:DMEndOfList];
        NSUInteger pageFirstIndex = (page - 1) * itemsPerPage;
        NSUInteger pageLastIndex = pageFirstIndex + itemsPerPage;
        if (lastItemIndex != NSNotFound && lastItemIndex <= pageFirstIndex)
        {
            cacheValid = NO;
        }

        // Check if all items are loaded
        // TODO: find a way to not have to execute this each time
        if (cacheValid)
        {
            more = lastItemIndex == NSNotFound || lastItemIndex > pageLastIndex;
            // If the end of list marker is in this page, shrink the range to match the number or remaining pages
            NSUInteger length = !more ? lastItemIndex - pageFirstIndex : itemsPerPage;
            NSArray *cachedItemIds = [self._cache objectsInRange:NSMakeRange(pageFirstIndex, length) notFoundMarker:null];
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
                    NSAssert(NO, @"Unexpected presence of the end-of-list marker");
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
    }

    if (cacheValid)
    {
        callback(items, more, self._total, cacheStalled, nil);
    }

    if (!cacheValid || cacheStalled)
    {
        // Handle situation when several requests with exactly same page/pageSize configuration are performed
        // in parallele, ensure we only execute the request once and calls all callbacks at once once completed
        @synchronized(self._runningRequests)
        {
            NSString *requestKey = [NSString stringWithFormat:@"%d:%d", page, itemsPerPage];
            NSMutableDictionary *requestInfo = self._runningRequests[requestKey];
            __block void (^bcallback)(NSArray *, BOOL, NSInteger, BOOL, NSError *) = callback;
            __weak DMItemOperation *boperation = operation;
            __weak DMItemCollection *bself = self;
            if (!requestInfo)
            {
                requestInfo = [NSMutableDictionary dictionary];
                requestInfo[@"callbacks"] = [NSMutableArray arrayWithObject:bcallback];
                requestInfo[@"operations"] = [NSMutableArray arrayWithObject:boperation];
                requestInfo[@"cleanupBlock"] = ^
                {
                    NSMutableDictionary *_requestInfo = bself._runningRequests[requestKey];
                    [_requestInfo removeAllObjects];
                    [bself._runningRequests removeObjectForKey:requestKey];
                };
                requestInfo[@"apiCall"] = [self loadItemsWithFields:fields forPage:page withPageSize:itemsPerPage do:^(NSArray *_items, BOOL _more, NSInteger _total, BOOL _stalled, NSError *_error)
                {
                    @synchronized(bself._runningRequests)
                    {
                        NSMutableDictionary *_requestInfo = bself._runningRequests[requestKey];
                        void (^cb)(NSArray *, BOOL, NSInteger, BOOL, NSError *);
                        for (cb in (NSMutableArray *)_requestInfo[@"callbacks"])
                        {
                            cb(_items, _more, _total, _stalled, _error);
                        }
                        for (DMItemOperation *op in (NSMutableArray *)_requestInfo[@"operations"])
                        {
                            op.isFinished = YES;
                        }
                        ((void (^)())_requestInfo[@"cleanupBlock"])();
                    }
                }];
                self._runningRequests[requestKey] = requestInfo;
            }
            else
            {
                [(NSMutableArray *)requestInfo[@"callbacks"] addObject:bcallback];
                [(NSMutableArray *)requestInfo[@"operations"] addObject:boperation];
            }

            operation.cancelBlock = ^
            {
                @synchronized(bself._runningRequests)
                {
                    NSMutableDictionary *_requestInfo = bself._runningRequests[requestKey];
                    [(NSMutableArray *)_requestInfo[@"operations"] removeObject:boperation];
                    NSMutableArray *callbacks = _requestInfo[@"callbacks"];
                    [callbacks removeObject:bcallback];
                    if (callbacks.count == 0)
                    {
                        [(DMAPICall *)_requestInfo[@"apiCall"] cancel];
                        ((void (^)())_requestInfo[@"cleanupBlock"])();
                    }
                }
            };
        }
    }
    else
    {
        operation.isFinished = YES;
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

        bself._total = result[@"total"] ? [result[@"total"] intValue] : -1;
        BOOL more = [result[@"has_more"] boolValue];
        NSMutableArray *ids = [NSMutableArray arrayWithCapacity:itemsPerPage];
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:itemsPerPage];

        for (NSDictionary *itemData in list)
        {
            DMItem *item = [DMItem itemWithType:bself.type forId:itemData[@"id"] fromAPI:bself._api];
            // Where we overload the item cache info by list cache info. This is not quite correct as item
            // cache isn't list cache but it shouldn't hurt for 99.9% of the cases.
            [item loadInfo:itemData withCacheInfo:cacheInfo];
            [items addObject:item];
            [ids addObject:itemData[@"id"]];
        }

        @synchronized(bself._cache)
        {
            if (cacheInfo.etag && bself.cacheInfo.etag && ![cacheInfo.etag isEqualToString:bself.cacheInfo.etag])
            {
                // The etag as changed, clear all previously cached pages
                [bself._cache removeAllObjects];
            }
            bself.cacheInfo = cacheInfo;

            [bself._cache replaceObjectsInRange:NSMakeRange((page - 1) * itemsPerPage, [ids count]) withObjectsFromArray:ids fillWithObject:[NSNull null]];

            if (!more)
            {
                // Add an end-of-list marker
                NSUInteger lastCacheIndex = [bself._cache count] - 1;
                NSUInteger eolIndex = (page - 1) * itemsPerPage + [ids count];
                bself._total = eolIndex;
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
            else
            {
                if (page > 1)
                {
                    // Handle when actual list raised by more than one page compared to cache
                    NSUInteger oelIndex;
                    while ((oelIndex = [bself._cache indexOfObject:DMEndOfList inRange:NSMakeRange(0, (page - 1) * itemsPerPage - 1)]) != NSNotFound)
                    {
                        bself._cache[oelIndex] = [NSNull null];
                    }
                }
            }

            NSUInteger maxEstimatedItemsCount = bself.pageSize * 100;
            if (bself._total == -1)
            {
                // If server didn't returned an estimated total and we don't know the current list boundary,
                // set the estimated total to current cache size + one page. It won't be accurate for the
                // majority of the case, but this value isn't to be shown to the end user, only to help building
                // the UI.
                NSUInteger fakedTotal = MIN([bself._cache count] + bself.pageSize, maxEstimatedItemsCount);
                if (bself.currentEstimatedTotalItemsCount != fakedTotal)
                {
                    bself.currentEstimatedTotalItemsCount = fakedTotal;
                }
            }
            else if (bself.currentEstimatedTotalItemsCount != MIN((NSUInteger)bself._total, maxEstimatedItemsCount))
            {
                bself.currentEstimatedTotalItemsCount = MIN(bself._total, maxEstimatedItemsCount);
            }
        }

        callback(items, more, bself._total, NO, nil);
    }];
}

- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    if (self.cacheInfo && self.cacheInfo.valid && !self.cacheInfo.stalled && index < [self._cache count] && self._cache[index] != DMEndOfList)
    {
        DMItem *item = [DMItem itemWithType:self.type forId:self._cache[index] fromAPI:self._api];
        if (!item.cacheInfo.stalled && [item areFieldsCached:fields])
        {
            return [item withFields:fields do:^(NSDictionary *data, BOOL _stalled, NSError *error)
            {
                // Shortcut to return fully cached, not stalled items
                callback(data, NO, error);
            }];
        }
    }

    // If item isn't full cached or list is stalled, bulk load items of the same page
    NSUInteger pageSize = self.pageSize;
    NSUInteger page = floorf(index / self.pageSize) + 1;
    return [self itemsWithFields:fields forPage:page withPageSize:pageSize do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (error)
        {
            callback(nil, NO, error);
            return;
        }

        NSUInteger localIndex = index - ((page - 1) * pageSize);

        if (localIndex >= [items count] || items[localIndex] == DMEndOfList)
        {
            callback(nil, NO, error);
            return;
        }

        DMItem *item = items[localIndex];
        [item withFields:fields do:^(NSDictionary *_data, BOOL _stalled, NSError *_error)
        {
            // The list cache stall info prevail on the item's on
            callback(_data, stalled, _error);
        }];
    }];
}

- (void)flushCache
{
    @synchronized(self._cache)
    {
        [self._cache removeAllObjects];
    }
}

@end
