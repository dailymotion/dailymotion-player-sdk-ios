//
//  DMItemTableViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import "DMItemTableViewDataSource.h"
#import "DMItemDataSourceItem.h"
#import "DMSubscriptingSupport.h"
#import "objc/runtime.h"

static char operationKey;

@interface DMItemTableViewDataSource ()

@property (nonatomic, assign) BOOL _loaded;
@property (nonatomic, strong) NSMutableArray *_operations;

@end

@implementation DMItemTableViewDataSource

- (id)init
{
    if ((self = [super init]))
    {
        [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

- (void)dealloc
{
    if (self._loaded)
    {
        [self cancelAllOperations];
        [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
        [self removeObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus"];
    }
}

- (void)cancelAllOperations
{
    [self._operations makeObjectsPerformSelector:@selector(cancel)];
    [self._operations removeAllObjects];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (!self._loaded)
        {
            UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
            NSAssert(cell, @"DMItemTableViewDataSource: You must set DMItemTableViewDataSource.cellIdentifier to a reusable cell identifier pointing to an instance of UITableViewCell conform to the DMItemTableViewCell protocol");
            NSAssert([cell conformsToProtocol:@protocol(DMItemDataSourceItem)], @"DMItemTableViewDataSource: UITableViewCell returned by DMItemTableViewDataSource.cellIdentifier must comform to DMItemTableViewCell protocol");

            __weak DMItemTableViewDataSource *bself = self;
            DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
            {
                if (error)
                {
                    bself.lastError = error;
                    bself._loaded = NO;
                    [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
                }
            }];
            self._operations = [NSMutableArray arrayWithObject:operation];
            [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];

            self._loaded = YES;
        }
        return self.itemCollection.currentEstimatedTotalItemsCount;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];

    DMItemOperation *previousOperation = objc_getAssociatedObject(cell, &operationKey);
    [previousOperation cancel];

    [cell prepareForLoading];

    __weak DMItemTableViewDataSource *bself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        __strong UITableViewCell <DMItemDataSourceItem> *scell = cell;
        if (scell)
        {
            objc_setAssociatedObject(scell, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (error)
            {
                BOOL notify = !bself.lastError; // prevents from error storms
                bself.lastError = error;
                if (notify)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
                }
            }
            else
            {
                bself.lastError = nil;
                [scell setFieldsData:data];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        if (!self._loaded) return;
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
    }
    else if ([keyPath isEqualToString:@"itemCollection.api.currentReachabilityStatus"] && object == self)
    {
        if (!self._loaded) return;
        DMNetworkStatus previousRechabilityStatus = ((NSNumber *)change[NSKeyValueChangeOldKey]).intValue;
        if (self.itemCollection.api.currentReachabilityStatus != DMNotReachable && previousRechabilityStatus == DMNotReachable)
        {
            // Became recheable: notify table view controller that it should reload table data
            [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
        }
        else if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && previousRechabilityStatus != DMNotReachable)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceOfflineNotification object:self];
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
