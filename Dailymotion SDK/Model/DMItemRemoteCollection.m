//
//  DMItemRemoteCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import "DMItemRemoteCollection.h"
#import "DMAPI.h"
#import "DMAdditions.h"
#import "DMSubscriptingSupport.h"
#import "DMAPIArchiverDelegate.h"

static NSString *const DMEndOfList = @"DMEndOfList";

@interface DMItem ()

- (void)loadInfo:(NSDictionary *)info withCacheInfo:(DMAPICacheInfo *)cacheInfo;

@end


@interface DMItemOperation (Private)

@property (nonatomic, strong) void (^cancelBlock)();

@end

@interface DMItemCollection (Private)

@property (nonatomic, readwrite, assign) NSUInteger currentEstimatedTotalItemsCount;

- (id)initWithType:(NSString *)type api:(DMAPI *)api;

@end

@interface DMItemRemoteCollection ()

@property (nonatomic, readwrite, copy) NSDictionary *params;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong) NSString *_path;
@property (nonatomic, assign) NSInteger _total;
@property (nonatomic, strong) NSMutableDictionary *_runningRequests;
@property (nonatomic, strong) NSMutableArray *_idsCache;
@property (nonatomic, strong) NSCache *_itemCache;

@end

@implementation DMItemRemoteCollection

- (id)initWithType:(NSString *)type params:(NSDictionary *)params path:(NSString *)path fromAPI:(DMAPI *)api
{
    if ((self = [super initWithType:type api:api]))
    {
        _pageSize = 25;
        _params = params;
        _cacheInfo = nil;
        __path = path;
        __total = -1;
        __runningRequests = [NSMutableDictionary dictionary];
        __idsCache = [NSMutableArray array];
        __itemCache = [[NSCache alloc] init];
        __itemCache.countLimit = 500;
    }
    return self;
}

#pragma mark - Archiving

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        _pageSize = 25;
        _params = [coder decodeObjectForKey:@"params"];
        _cacheInfo = [coder decodeObjectForKey:@"cacheInfo"];
        __path = [coder decodeObjectForKey:@"_path"];
        __total = [coder decodeIntegerForKey:@"_total"];
        __runningRequests = [NSMutableDictionary dictionary];
        __idsCache = [coder decodeObjectForKey:@"_idsCache"];
        __itemCache = [[NSCache alloc] init];
        __itemCache.countLimit = 500;

        NSDictionary *itemCache = [coder decodeObjectForKey:@"_itemCache"];
#warning TOFIX something here seems to crash the unit test with EXEC_BAD_ACCESS - certainly an ARC issue
        [itemCache enumerateKeysAndObjectsUsingBlock:^(NSString *itemId, DMItem *item, BOOL *stop)
        {
            [__itemCache setObject:item forKey:itemId];
        }];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_params forKey:@"params"];
    [coder encodeObject:_cacheInfo forKey:@"cacheInfo"];
    [coder encodeObject:__path forKey:@"_path"];
    [coder encodeInteger:__total forKey:@"_total"];
    [coder encodeObject:__idsCache forKey:@"_idsCache"];

    NSMutableDictionary *itemCache = [NSMutableDictionary dictionary];
    for (NSString *itemId in __idsCache)
    {
        if (![itemId isKindOfClass:NSString.class])
        {
            continue;
        }
        DMItem *item = [__itemCache objectForKey:itemId];
        if (item)
        {
            [itemCache setObject:item forKey:itemId];
        }
    }
    [coder encodeObject:itemCache forKey:@"_itemCache"];
}

#pragma mark - Implementation

- (DMItem *)itemWithId:(NSString *)itemId
{
    DMItem *item = [self._itemCache objectForKey:itemId];
    if (!item)
    {
        item = [DMItem itemWithType:self.type forId:itemId fromAPI:self.api];
        [self._itemCache setObject:item forKey:itemId];
    }
    return item;
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

    @synchronized(self._idsCache)
    {
        // Check the cache contains the end of list marker, and if this marker is not before the requested page
        NSUInteger lastItemIndex = [self._idsCache indexOfObject:DMEndOfList];
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
            NSArray *cachedItemIds = [self._idsCache objectsInRange:NSMakeRange(pageFirstIndex, length) notFoundMarker:null];
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
                    item = [self itemWithId:itemId];
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
            __weak DMItemRemoteCollection *bself = self;
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
                        if (!_requestInfo) return;
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
                    if (!_requestInfo) return;
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
    NSMutableDictionary *params = self.params ? self.params.mutableCopy : NSMutableDictionary.dictionary;
    params[@"page"] = [NSNumber numberWithInt:page];
    params[@"limit"] = [NSNumber numberWithInt:itemsPerPage];

    NSMutableSet *fieldsSet = [NSMutableSet setWithArray:fields];
    [fieldsSet addObject:@"id"]; // Enforce id retrival
    params[@"fields"] = [fieldsSet allObjects];

    __weak DMItemRemoteCollection *bself = self;

    return [self.api get:self._path args:params cacheInfo:nil callback:^(NSDictionary *result, DMAPICacheInfo *cacheInfo, NSError *error)
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
            DMItem *item = [bself itemWithId:itemData[@"id"]];
            [item loadInfo:itemData withCacheInfo:cacheInfo];
            [items addObject:item];
            [ids addObject:itemData[@"id"]];
        }

        @synchronized(bself._idsCache)
        {
            if (cacheInfo.etag && bself.cacheInfo.etag && ![cacheInfo.etag isEqualToString:bself.cacheInfo.etag])
            {
                // The etag as changed, clear all previously cached pages
                [bself._idsCache removeAllObjects];
            }
            bself.cacheInfo = cacheInfo;

            [bself._idsCache replaceObjectsInRange:NSMakeRange((page - 1) * itemsPerPage, [ids count]) withObjectsFromArray:ids fillWithObject:[NSNull null]];

            if (!more)
            {
                // Add an end-of-list marker
                NSUInteger lastCacheIndex = [bself._idsCache count] - 1;
                NSUInteger eolIndex = (page - 1) * itemsPerPage + [ids count];
                bself._total = eolIndex;
                if (lastCacheIndex == eolIndex - 1)
                {
                    [bself._idsCache addObject:DMEndOfList];
                }
                else if (lastCacheIndex < eolIndex - 1)
                {
                    // Cache was smaller than new actual size
                    [bself._idsCache raise:eolIndex withObject:[NSNull null]];
                    [bself._idsCache addObject:DMEndOfList];
                }
                else
                {
                    // Cache was larger than new actual size
                    bself._idsCache[eolIndex] = DMEndOfList;
                    // Shrink the cache to the new size
                    [bself._idsCache shrink:eolIndex + 1];
                }
            }
            else
            {
                if (page > 1)
                {
                    // Handle when actual list raised by more than one page compared to cache
                    NSUInteger oelIndex;
                    while ((oelIndex = [bself._idsCache indexOfObject:DMEndOfList inRange:NSMakeRange(0, (page - 1) * itemsPerPage - 1)]) != NSNotFound)
                    {
                        bself._idsCache[oelIndex] = [NSNull null];
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
                NSUInteger fakedTotal = MIN([bself._idsCache count] + bself.pageSize, maxEstimatedItemsCount);
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
    if (self.cacheInfo && self.cacheInfo.valid && !self.cacheInfo.stalled && index < [self._idsCache count] && self._idsCache[index] != DMEndOfList)
    {
        DMItem *item = [self itemWithId:self._idsCache[index]];
        if (!item.cacheInfo.stalled && [item areFieldsCached:fields])
        {
            return [item withFields:fields do:^(NSDictionary *data, BOOL _stalled, NSError *error)
            {
                // Shortcut to return fully cached, not stalled items
                callback(data, NO, error);
            }];
        }
    }

    // If item isn't fully cached or list is stalled, bulk load items of the same page to prevent repeated requests on list views
    NSUInteger pageSize = self.pageSize;
    NSUInteger page = floorf(index / pageSize) + 1;
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
    @synchronized(self._idsCache)
    {
        [self._idsCache removeAllObjects];
        [self._itemCache removeAllObjects];
        self.currentEstimatedTotalItemsCount = 0;
        self._total = -1;
    }
}

- (BOOL)canEdit
{
    // TODO: handle rights
    return YES;
}

- (DMItemOperation *)addItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    DMItemOperation *operation = [[DMItemOperation alloc] init];

    if ([self._idsCache containsObject:item.itemId])
    {
        callback(nil);
        operation.isFinished = YES;
    }
    else
    {
        __weak DMItemRemoteCollection *bself = self;
        DMAPICall *apiCall = [self.api post:[self._path stringByAppendingFormat:@"/%@", item.itemId] callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
        {
            bself.cacheInfo.stalled = NO;
            callback(error);
        }];

        operation.cancelBlock = ^
        {
            [apiCall cancel];
        };
    }

    return operation;
}

- (DMItemOperation *)removeItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    DMItemOperation *operation = [[DMItemOperation alloc] init];

    __weak DMItemRemoteCollection *bself = self;
    DMAPICall *apiCall = [self.api delete:[self._path stringByAppendingFormat:@"/%@", item.itemId] callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        bself.cacheInfo.stalled = NO;
        callback(error);
    }];

    operation.cancelBlock = ^
    {
        [apiCall cancel];
    };

    return operation;
}

- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback
{
    DMItemOperation *operation = [[DMItemOperation alloc] init];

    if (index < [self._idsCache count] && self._idsCache[index] != DMEndOfList)
    {
        DMItem *item = [self itemWithId:self._idsCache[index]];
        return [self removeItem:item done:callback];
    }
    else
    {
        __weak DMItemRemoteCollection *bself = self;
        __block DMItemOperation *subOperation = [self withItemFields:@[] atIndex:index do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (error)
            {
                callback(error);
                operation.isFinished = YES;
            }
            else if (index < [bself._idsCache count] && bself._idsCache[index] != DMEndOfList)
            {
                DMItem *item = [bself itemWithId:bself._idsCache[index]];
                subOperation = [bself removeItem:item done:^(NSError *error2)
                {
                    callback(error2);
                    operation.isFinished = YES;
                }];
            }
            else
            {
                callback(nil);
                operation.isFinished = YES;
            }
        }];

        operation.cancelBlock = ^
        {
            [subOperation cancel];
        };
    }

    return operation;
}

- (BOOL)canReorder
{
    return NO; // TODO
}

@end
