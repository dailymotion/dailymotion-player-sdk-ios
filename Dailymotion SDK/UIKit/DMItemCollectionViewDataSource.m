//
//  DMItemCollectionViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 21/09/12.
//
//

#import "DMItemCollectionViewDataSource.h"
#import "DMItemDataSourceItem.h"
#import "DMItemRemoteCollection.h"
#import "objc/runtime.h"

static char operationKey;

@interface DMItemCollectionViewDataSource ()

@property (nonatomic, assign) BOOL reloading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSMutableArray *operations;
@property (nonatomic, weak) UICollectionView *lastCollectionView;

@end

@implementation DMItemCollectionViewDataSource

- (id)init
{
    self = [super init];
    if (self)
    {
        self.autoReloadData = YES;
        [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [self cancelAllOperations];
    [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
    [self removeObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus"];
}

- (void)cancelAllOperations
{
    for (DMItemOperation *operation in self.operations)
    {
        [operation removeObserver:self forKeyPath:@"isFinished"];
    }
    [self.operations makeObjectsPerformSelector:@selector(cancel)];
    [self.operations removeAllObjects];
}

- (void)setItemCollection:(DMItemCollection *)itemCollection
{
    if (_itemCollection != itemCollection)
    {
        _itemCollection = itemCollection;

        self.loaded = NO;
        if (_itemCollection.isLocal)
        {
            // Local connection doesn't need pre-loading of the list
            self.loaded = YES;
            if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidFinishLoadingData:)])
            {
                [self.delegate itemCollectionViewDataSourceDidFinishLoadingData:self];
            }
        }
        if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidChange:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.delegate itemCollectionViewDataSourceDidChange:self];
            });
        }
        if (self.autoReloadData)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.lastCollectionView reloadData];
            });
        }
    }
}

- (void)reload
{
    [self reload:nil];
}

- (void)reload:(void (^)())completionBlock
{
    if (![self.itemCollection isKindOfClass:DMItemRemoteCollection.class])
    {
        if (completionBlock) completionBlock();
        return;
    }

    self.reloading = YES;
    ((DMItemRemoteCollection *)self.itemCollection).cacheInfo.valid = NO;
    UICollectionViewCell <DMItemDataSourceItem> *cell = self.cellClass.new;
    __weak DMItemCollectionViewDataSource *wself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemCollectionViewDataSource *sself = wself;
        sself.reloading = NO;
        if (completionBlock) completionBlock();
    }];

    if (operation && !operation.isFinished) // The operation can be synchrone in case the itemCollection was already loaded or restored from disk
    {
        [self.operations addObject:operation];
        [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    }
}

- (void)reloadIfNeeded
{
    if ([self.itemCollection isKindOfClass:DMItemRemoteCollection.class]
        && (self.itemCollection.currentEstimatedTotalItemsCount == 0 || ((DMItemRemoteCollection *)self.itemCollection).cacheInfo.stalled))
    {
        [self reload];
    }
}

#pragma Collection Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    self.lastCollectionView = collectionView;
    BOOL networkLoadingWhileOffline = self.itemCollection.api.currentReachabilityStatus == DMNotReachable && [self.itemCollection isKindOfClass:DMItemRemoteCollection.class];

    if (!self.loaded && self.itemCollection && !networkLoadingWhileOffline)
    {
        UICollectionViewCell <DMItemDataSourceItem> *cell = self.cellClass.new;
        NSAssert(cell, @"DMItemCollectionViewDataSource: You must set DMItemCollectionViewDataSource.cellClass to a child of UICollectionViewCell conforming to the DMItemDataSourceItem protocol");
        NSAssert([cell conformsToProtocol:@protocol(DMItemDataSourceItem)], @"DMItemCollectionViewDataSource: UICollectionViewCell returned by DMItemCollectionViewDataSource.cellClass must comform to DMItemDataSourceItem protocol");

        __weak DMItemCollectionViewDataSource *wself = self;
        DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (!wself) return;
            __strong DMItemCollectionViewDataSource *sself = wself;

            if (error)
            {
                sself.lastError = error;
                sself.loaded = NO;
                if ([sself.delegate respondsToSelector:@selector(itemCollectionViewDataSource:didFailWithError:)])
                {
                    [sself.delegate itemCollectionViewDataSource:sself didFailWithError:error];
                }
            }
            else
            {
                if ([sself.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidFinishLoadingData:)])
                {
                    [sself.delegate itemCollectionViewDataSourceDidFinishLoadingData:self];
                }
                if ([sself.delegate respondsToSelector:@selector(itemCollectionViewDataSource:didUpdateWithEstimatedTotalItemsCount:)])
                {
                    [sself.delegate itemCollectionViewDataSource:sself didUpdateWithEstimatedTotalItemsCount:sself.itemCollection.currentEstimatedTotalItemsCount];
                }
                [sself.lastCollectionView reloadData];
            }
        }];
        // Cleanup running operations
        [self cancelAllOperations];
        self.operations = [NSMutableArray array];
        if (!operation.isFinished) // The operation can be synchrone in case the itemCollection was already loaded or restored from disk
        {
            [self.operations addObject:operation];
            [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];

            // Only notify about loading if we have something to load on the network
            if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidStartLoadingData:)])
            {
                [self.delegate itemCollectionViewDataSourceDidStartLoadingData:self];
            }
        }

        self.loaded = YES;
    }
    return self.itemCollection.currentEstimatedTotalItemsCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.lastCollectionView = collectionView;
    __weak UICollectionViewCell <DMItemDataSourceItem> *cell = [collectionView dequeueReusableCellWithReuseIdentifier:self.cellIdentifier forIndexPath:indexPath];
    NSAssert([cell isKindOfClass:self.cellClass], @"The cellIdentifier must point to a reuseable cell nib pointing to the same class as defined in cellClass");

    DMItemOperation *previousOperation = objc_getAssociatedObject(cell, &operationKey);
    [previousOperation cancel];

    [cell prepareForLoading];
    if ([cell respondsToSelector:@selector(setItem:)])
    {
        [cell setItem:nil];
    }

    __weak DMItemCollectionViewDataSource *wself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemCollectionViewDataSource *sself = wself;

        __strong UICollectionViewCell <DMItemDataSourceItem> *scell = cell;
        if (scell)
        {
            objc_setAssociatedObject(scell, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (error)
            {
                if ([scell respondsToSelector:@selector(setError:)])
                {
                    [scell setError:error];
                }
                else
                {
                    BOOL notify = !sself.lastError; // prevents from error storms
                    sself.lastError = error;
                    if (notify)
                    {
                        if ([sself.delegate respondsToSelector:@selector(itemCollectionViewDataSource:didFailWithError:)])
                        {
                            [sself.delegate itemCollectionViewDataSource:sself didFailWithError:error];
                        }
                    }
                }
            }
            else
            {
                sself.lastError = nil;
                if (!data) return; // Reached and of list, the number of item in the list will be updated after this cell is displayed
                [scell setFieldsData:data];
                if ([sself.delegate respondsToSelector:@selector(itemCollectionViewDataSource:didLoadCellContentAtIndexPath:withData:)])
                {
                    [sself.delegate itemCollectionViewDataSource:sself didLoadCellContentAtIndexPath:indexPath withData:data];
                }

                if ([scell respondsToSelector:@selector(setItem:)])
                {
                    [sself.itemCollection itemAtIndex:indexPath.row withFields:nil done:^(DMItem *item, NSError *e2)
                    {
                        [scell setItem:item];
                    }];
                }
            }
        }
    }];

    if (operation && !operation.isFinished)
    {
        [self.operations addObject:operation];
        [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
        objc_setAssociatedObject(cell, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return cell;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        if (!self.itemCollection) return;
        if (!self.loaded) return;
        if (self.reloading && self.itemCollection.currentEstimatedTotalItemsCount == 0) return;
        if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSource:didUpdateWithEstimatedTotalItemsCount:)])
        {
            [self.delegate itemCollectionViewDataSource:self didUpdateWithEstimatedTotalItemsCount:self.itemCollection.currentEstimatedTotalItemsCount];
        }
        if (self.autoReloadData)
        {
            [self.lastCollectionView reloadData];
        }
    }
    else if ([keyPath isEqualToString:@"itemCollection.api.currentReachabilityStatus"] && object == self)
    {
        if (!self.itemCollection) return;
        if (change[NSKeyValueChangeOldKey] == NSNull.null)
        {
            if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && [self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidEnterOfflineMode:)])
            {
                [(NSObject *)self.delegate performSelector:@selector(itemCollectionViewDataSourceDidEnterOfflineMode:) withObject:self afterDelay:1];
            }
        }
        else
        {
            DMNetworkStatus previousReachabilityStatus = ((NSNumber *)change[NSKeyValueChangeOldKey]).intValue;
            if (self.itemCollection.api.currentReachabilityStatus != DMNotReachable && previousReachabilityStatus == DMNotReachable)
            {
                [NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(itemCollectionViewDataSourceDidEnterOfflineMode:) object:self];
                // Became recheable: notify collection view controller that it should reload collection view data
                if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidLeaveOfflineMode:)])
                {
                    [self.delegate itemCollectionViewDataSourceDidLeaveOfflineMode:self];
                }
                [self.lastCollectionView reloadData];
            }
            else if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && previousReachabilityStatus != DMNotReachable)
            {
                if ([self.delegate respondsToSelector:@selector(itemCollectionViewDataSourceDidEnterOfflineMode:)])
                {
                    [(NSObject *)self.delegate performSelector:@selector(itemCollectionViewDataSourceDidEnterOfflineMode:) withObject:self afterDelay:1];
                }
            }
        }
    }
    else if ([keyPath isEqualToString:@"isFinished"])
    {
        if ([object isKindOfClass:DMItemOperation.class] && ((DMItemOperation *)object).isFinished)
        {
            [self.operations removeObject:object];
            [object removeObserver:self forKeyPath:@"isFinished"];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
