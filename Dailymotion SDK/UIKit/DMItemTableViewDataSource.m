//
//  DMItemTableViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import "DMItemTableViewDataSource.h"
#import "DMItemTableViewCell.h"
#import "objc/runtime.h"

static char operationKey;

@interface DMItemTableViewDataSource ()

@property (nonatomic, assign) BOOL _loaded;
@property (nonatomic, strong) NSMutableArray *_operations;

@end

@implementation DMItemTableViewDataSource

- (void)cancelAllOperations
{
    [self._operations makeObjectsPerformSelector:@selector(cancel)];
    [self._operations removeAllObjects];
}

- (void)dealloc
{
    if (self._loaded)
    {
        [self cancelAllOperations];
        [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (!self._loaded)
        {
            UITableViewCell <DMItemTableViewCell> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
            NSAssert(cell, @"DMItemTableViewDataSource: You must set DMItemTableViewDataSource.cellIdentifier to a reusable cell identifier pointing to an instance of UITableViewCell conform to the DMItemTableViewCell protocol");
            NSAssert([cell conformsToProtocol:@protocol(DMItemTableViewCell)], @"DMItemTableViewDataSource: UITableViewCell returned by DMItemTableViewDataSource.cellIdentifier must comform to DMItemTableViewCell protocol");
            [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
            DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error){}];
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
    __weak UITableViewCell <DMItemTableViewCell> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];

    DMItemOperation *previousOperation = objc_getAssociatedObject(cell, &operationKey);
    [previousOperation cancel];

    [cell prepareForLoading];

    __weak DMItemTableViewDataSource *bself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        __strong UITableViewCell <DMItemTableViewCell> *scell = cell;
        if (scell)
        {
            objc_setAssociatedObject(scell, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (error)
            {
                bself.lastError = error;
                [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
            }
            else
            {
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
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
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