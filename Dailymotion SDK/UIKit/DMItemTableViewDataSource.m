//
//  DMItemTableViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import "DMItemTableViewDataSource.h"
#import "DMItemTableViewCell.h"

@interface DMItemTableViewDataSource ()

@property (nonatomic, assign) BOOL loaded;

@end

@implementation DMItemTableViewDataSource

- (void)dealloc
{
    if (self.loaded)
    {
        [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (!self.loaded)
        {
            UITableViewCell <DMItemTableViewCell> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
            NSAssert(cell, @"DMItemTableViewDataSource: You must set DMItemTableViewDataSource.cellIdentifier to a reusable cell identifier pointing to an instance of UITableViewCell conform to the DMItemTableViewCell protocol");
            NSAssert([cell conformsToProtocol:@protocol(DMItemTableViewCell)], @"DMItemTableViewDataSource: UITableViewCell returned by DMItemTableViewDataSource.cellIdentifier must comform to DMItemTableViewCell protocol");
            [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
            [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error){}];
            self.loaded = YES;
        }
        return self.itemCollection.currentEstimatedTotalItemsCount;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak UITableViewCell <DMItemTableViewCell> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];

    [cell.operation cancel];
    [cell prepareForLoading];

    cell.operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        __strong UITableViewCell <DMItemTableViewCell> *scell = cell;
        if (scell)
        {
            scell.operation = nil;

            if (error)
            {
                // TODO
            }
            else
            {
                [scell setFieldsData:data];
            }
        }
    }];

    return cell;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
