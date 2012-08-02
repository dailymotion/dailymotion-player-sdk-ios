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
@property (nonatomic, strong) NSMutableArray *_listCache;

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
        __listCache = [NSMutableArray array];
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
        __listCache = [coder decodeObjectForKey:@"_listCache"];
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
    [coder encodeObject:__listCache forKey:@"_listCache"];
}

#pragma mark - Implementation

- (DMItem *)itemWithId:(NSString *)itemId atIndex:(NSUInteger)index
{
    DMItem *item = [self itemAtIndex:index];

    if (item && ![item.itemId isEqualToString:itemId])
    {
        item = nil;
    }
    if (!item)
    {
        item = [DMItem itemWithType:self.type forId:itemId fromAPI:self.api];

        if (self._listCache.count > index)
        {
            self._listCache[index] = item;
        }
        else if (self._listCache.count == index)
        {
            [self._listCache addObject:item];
        }
        else
        {
            [self._listCache raise:index withObject:[NSNull null]];
            [self._listCache addObject:item];
        }
    }

    return item;
}

- (DMItem *)itemAtIndex:(NSUInteger)index
{
    DMItem *item;
    if (index < [self._listCache count] && [self._listCache[index] isKindOfClass:DMItem.class])
    {
        item = self._listCache[index];
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

    @synchronized(self._listCache)
    {
        // Check the cache contains the end of list marker, and if this marker is not before the requested page
        NSUInteger lastItemIndex = [self._listCache indexOfObject:DMEndOfList];
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
            NSArray *cachedItems = [self._listCache objectsInRange:NSMakeRange(pageFirstIndex, length) notFoundMarker:null];
            DMItem *item;

            for (item in cachedItems)
            {
                if ((id)item == null)
                {
                    cacheValid = NO;
                    break;
                }
                else if ((id)item == DMEndOfList)
                {
                    NSAssert(NO, @"Unexpected presence of the end-of-list marker");
                }
                else
                {
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
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:itemsPerPage];

        @synchronized(bself._listCache)
        {
            if (cacheInfo.etag && bself.cacheInfo.etag && ![cacheInfo.etag isEqualToString:bself.cacheInfo.etag])
            {
                // The etag as changed, clear all previously cached pages
                [bself._listCache removeAllObjects];
            }
            bself.cacheInfo = cacheInfo;

            NSUInteger idx = (page - 1) * itemsPerPage;
            for (NSDictionary *itemData in list)
            {
                DMItem *item = [bself itemWithId:itemData[@"id"] atIndex:idx++];
                [item loadInfo:itemData withCacheInfo:cacheInfo];
                [items addObject:item];
            }

            if (!more)
            {
                // Add an end-of-list marker
                NSUInteger lastCacheIndex = [bself._listCache count] - 1;
                NSUInteger eolIndex = (page - 1) * itemsPerPage + [list count];
                bself._total = eolIndex;
                if (lastCacheIndex == eolIndex - 1)
                {
                    [bself._listCache addObject:DMEndOfList];
                }
                else if (lastCacheIndex < eolIndex - 1)
                {
                    // Cache was smaller than new actual size
                    [bself._listCache raise:eolIndex withObject:[NSNull null]];
                    [bself._listCache addObject:DMEndOfList];
                }
                else
                {
                    // Cache was larger than new actual size
                    bself._listCache[eolIndex] = DMEndOfList;
                    // Shrink the cache to the new size
                    [bself._listCache shrink:eolIndex + 1];
                }
            }
            else
            {
                if (page > 1)
                {
                    // Handle when actual list raised by more than one page compared to cache
                    NSUInteger oelIndex;
                    while ((oelIndex = [bself._listCache indexOfObject:DMEndOfList inRange:NSMakeRange(0, (page - 1) * itemsPerPage - 1)]) != NSNotFound)
                    {
                        bself._listCache[oelIndex] = [NSNull null];
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
                NSUInteger fakedTotal = MIN([bself._listCache count] + bself.pageSize, maxEstimatedItemsCount);
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
    if (self.cacheInfo && self.cacheInfo.valid && !self.cacheInfo.stalled && [self itemAtIndex:index])
    {
        DMItem *item = [self itemAtIndex:index];
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

- (DMItemOperation *)itemAtIndex:(NSUInteger)index withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback;
{
    __weak DMItemRemoteCollection *bself = self;
    return [self withItemFields:fields atIndex:index do:^(NSDictionary *devnull, BOOL stalled, NSError *error)
    {
        if (error)
        {
            callback(nil, error);
        }
        else if ([bself itemAtIndex:index])
        {
            callback([bself itemAtIndex:index], nil);
        }
        else
        {
            callback(nil, nil);
        }                                                 
    }];
}

- (void)flushCache
{
    @synchronized(self._listCache)
    {
        [self._listCache removeAllObjects];
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

    if ([self._listCache containsObject:item])
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

    NSUInteger idx = [self._listCache indexOfObject:item];
    if (idx != NSNotFound)
    {
        [self._listCache removeObjectAtIndex:idx];
        self.currentEstimatedTotalItemsCount -= 1; // required by deleteCellAtIndexPath
        self.cacheInfo.stalled = NO;
    }

    __weak DMItemRemoteCollection *bself = self;
    DMAPICall *apiCall = [self.api delete:[self._path stringByAppendingFormat:@"/%@", item.itemId] callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        if (error && idx != NSNotFound)
        {
            // Try to reinsert the item at the same position in case of API error
            // May lead to inconsistencies but this will be fixed by the next fetch
            [bself._listCache insertObject:item.itemId atIndex:idx];
        }
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

    if ([self itemAtIndex:index])
    {
        return [self removeItem:[self itemAtIndex:index] done:callback];
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
            else if ([bself itemAtIndex:index])
            {
                subOperation = [bself removeItem:[self itemAtIndex:index] done:^(NSError *error2)
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
