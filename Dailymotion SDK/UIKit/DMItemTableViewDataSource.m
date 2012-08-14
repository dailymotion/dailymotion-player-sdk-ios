//
//  DMItemTableViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import "DMItemTableViewDataSource.h"
#import "DMItemDataSourceItem.h"
#import "DMItemLocalCollection.h"
#import "DMItemRemoteCollection.h"
#import "DMSubscriptingSupport.h"
#import "objc/runtime.h"
#import "objc/message.h"

static char operationKey;

@interface DMItemTableViewDataSource ()

@property (nonatomic, assign) BOOL _loaded;
@property (nonatomic, strong) NSMutableArray *_operations;
@property (nonatomic, weak) UITableView *_lastTableView;

@end

@implementation DMItemTableViewDataSource

- (id)init
{
    if ((self = [super init]))
    {
        [self addObserver:self forKeyPath:@"itemCollection" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [self cancelAllOperations];
    [self removeObserver:self forKeyPath:@"itemCollection"];
    [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
    [self removeObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus"];
}

- (void)cancelAllOperations
{
    for (DMItemOperation *operation in self._operations)
    {
        [operation removeObserver:self forKeyPath:@"isFinished"];
    }
    [self._operations makeObjectsPerformSelector:@selector(cancel)];
    [self._operations removeAllObjects];
}

#pragma Table Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    self._lastTableView = tableView;
    BOOL networkLoadingWhileOffline = self.itemCollection.api.currentReachabilityStatus == DMNotReachable && [self.itemCollection isKindOfClass:DMItemRemoteCollection.class];

    if (!self._loaded && self.itemCollection && !networkLoadingWhileOffline)
    {
        UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
        NSAssert(cell, @"DMItemTableViewDataSource: You must set DMItemTableViewDataSource.cellIdentifier to a reusable cell identifier pointing to an instance of UITableViewCell conform to the DMItemTableViewCell protocol");
        NSAssert([cell conformsToProtocol:@protocol(DMItemDataSourceItem)], @"DMItemTableViewDataSource: UITableViewCell returned by DMItemTableViewDataSource.cellIdentifier must comform to DMItemDataSourceItem protocol");

        __weak DMItemTableViewDataSource *wself = self;
        DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (!wself) return;
            __strong DMItemTableViewDataSource *sself = wself;

            if (error)
            {
                sself.lastError = error;
                sself._loaded = NO;
                if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didFailWithError:)])
                {
                    [sself.delegate itemTableViewDataSource:sself didFailWithError:error];
                }
            }
            else
            {
                if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidFinishLoadingData:)])
                {
                    [self.delegate itemTableViewDataSourceDidFinishLoadingData:self];
                }
                [self._lastTableView reloadData];
            }
        }];
        // Cleanup running operations
        [self cancelAllOperations];
        self._operations = [NSMutableArray array];
        if (!operation.isFinished) // The operation can be synchrone in case the itemCollection was already loaded or restored from disk
        {
            [self._operations addObject:operation];
            [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];

            // Only notify about loading if we have something to load on the network
            if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidStartLoadingData:)])
            {
                [self.delegate itemTableViewDataSourceDidStartLoadingData:self];
            }
        }

        self._loaded = YES;
    }
    return self.itemCollection.currentEstimatedTotalItemsCount;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    self._lastTableView = tableView;
    __weak UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];

    DMItemOperation *previousOperation = objc_getAssociatedObject(cell, &operationKey);
    [previousOperation cancel];

    [cell prepareForLoading];

    __weak DMItemTableViewDataSource *wself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemTableViewDataSource *sself = wself;

        __strong UITableViewCell <DMItemDataSourceItem> *scell = cell;
        if (scell)
        {
            objc_setAssociatedObject(scell, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (error)
            {
                BOOL notify = !sself.lastError; // prevents from error storms
                sself.lastError = error;
                if (notify)
                {
                    if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didFailWithError:)])
                    {
                        [sself.delegate itemTableViewDataSource:sself didFailWithError:error];
                    }
                }
            }
            else
            {
                sself.lastError = nil;
                [scell setFieldsData:data];
                if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didLoadCellContentAtIndexPath:withData:)])
                {
                    [sself.delegate itemTableViewDataSource:sself didLoadCellContentAtIndexPath:indexPath withData:data];
                }
            }
        }
    }];

    if (!operation.isFinished)
    {
        [self._operations addObject:operation];
        [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
        objc_setAssociatedObject(cell, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return cell;
}

#pragma mark - Table Editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemCollection canEdit] && self.editable;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete && [self.itemCollection canEdit] && self.editable)
    {
        __weak DMItemTableViewDataSource *wself = self;
        [self.itemCollection removeItemAtIndex:indexPath.row done:^(NSError *error)
        {
            if (!wself) return;
            __strong DMItemTableViewDataSource *sself = wself;

            if (error)
            {
                sself.lastError = error;
                if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didFailWithError:)])
                {
                    [sself.delegate itemTableViewDataSource:sself didFailWithError:error];
                }
            }
            else
            {
                sself.lastError = nil;
                if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didDeleteCellAtIndexPath:)])
                {
                    [sself.delegate itemTableViewDataSource:sself didDeleteCellAtIndexPath:indexPath];
                }
            }
        }];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemCollection canReorder] && self.reorderable;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    if ([self.itemCollection canReorder] && self.reorderable)
    {
        __weak DMItemTableViewDataSource *wself = self;
        [self.itemCollection moveItemAtIndex:fromIndexPath.row toIndex:toIndexPath.row done:^(NSError *error)
        {
            if (!wself) return;
            __strong DMItemTableViewDataSource *sself = wself;

            if (error)
            {
                sself.lastError = error;
                if ([sself.delegate respondsToSelector:@selector(itemTableViewDataSource:didFailWithError:)])
                {
                    [sself.delegate itemTableViewDataSource:sself didFailWithError:error];
                }
            }
            else
            {
                sself.lastError = nil;
            }
        }];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection"] && object == self)
    {
        self._loaded = NO;
        if ([self.itemCollection isKindOfClass:DMItemLocalCollection.class])
        {
            // Local connection doesn't need pre-loading of the list
            self._loaded = YES;
        }
        if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidChange:)])
        {
            dispatch_async(dispatch_get_current_queue(), ^
            {
                [self.delegate itemTableViewDataSourceDidChange:self];
            });
        }
        [self._lastTableView reloadData];
    }
    else if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        if (!self._loaded) return;
        if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidChange:)])
        {
            [self.delegate itemTableViewDataSourceDidChange:self];
        }
        [self._lastTableView reloadData];
    }
    else if ([keyPath isEqualToString:@"itemCollection.api.currentReachabilityStatus"] && object == self)
    {
        if (change[NSKeyValueChangeOldKey] == NSNull.null)
        {
            if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && [self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidEnterOfflineMode:)])
            {
                // We always start by getting this status before even when connected, immediately followed by a reachable notif if finaly connected
                [(NSObject *)self.delegate performSelector:@selector(itemTableViewDataSourceDidEnterOfflineMode:) withObject:self afterDelay:1];
            }
        }
        else
        {
            DMNetworkStatus previousRechabilityStatus = ((NSNumber *)change[NSKeyValueChangeOldKey]).intValue;
            if (self.itemCollection.api.currentReachabilityStatus != DMNotReachable && previousRechabilityStatus == DMNotReachable)
            {
                [NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(itemTableViewDataSourceDidEnterOfflineMode:) object:self];
                // Became recheable: notify table view controller that it should reload table data
                if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidLeaveOfflineMode:)])
                {
                    [self.delegate itemTableViewDataSourceDidLeaveOfflineMode:self];
                }
                [self._lastTableView reloadData];
            }
            else if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && previousRechabilityStatus != DMNotReachable)
            {
                if ([self.delegate respondsToSelector:@selector(itemTableViewDataSourceDidEnterOfflineMode:)])
                {
                    [self.delegate itemTableViewDataSourceDidEnterOfflineMode:self];
                }
            }
        }
    }
    else if ([keyPath isEqualToString:@"isFinished"] && [object isKindOfClass:DMItemOperation.class])
    {
        if (((DMItemOperation *)object).isFinished)
        {
            [self._operations removeObject:object];
            [object removeObserver:self forKeyPath:@"isFinished"];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
