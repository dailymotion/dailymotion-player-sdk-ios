//
//  DMItemTableViewController.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import "DMItemTableViewController.h"
#import "DMAlert.h"
#import "DMItemRemoteCollection.h"

@interface DMItemTableViewController ()

@property (nonatomic, readwrite) DMItemTableViewDataSource *itemDataSource;

@end

@implementation DMItemTableViewController

- (DMItemTableViewDataSource *)itemDataSource
{
    if (!_itemDataSource)
    {
        _itemDataSource = [[DMItemTableViewDataSource alloc] init];
        _itemDataSource.delegate = self;
    }

    return _itemDataSource;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.itemDataSource reloadIfNeeded];
}

#pragma Table Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.itemDataSource tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemDataSource tableView:tableView canEditRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.itemDataSource tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemDataSource tableView:tableView canMoveRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    [self.itemDataSource tableView:tableView moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
}

#pragma mark - DMItemTableViewDataSourceDelegate

- (void)itemTableViewDataSourceDidChange:(DMItemTableViewDataSource *)dataSource;
{
}

- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didUpdateWithEstimatedTotalItemsCount:(NSUInteger)estimatedTotalItems
{

}

- (void)itemTableViewDataSourceDidStartLoadingData:(DMItemTableViewDataSource *)dataSource
{
}

- (void)itemTableViewDataSourceDidFinishLoadingData:(DMItemTableViewController *)dataSource
{
}

- (void)itemTableViewDataSourceDidEnterOfflineMode:(DMItemTableViewController *)dataSource
{
}

- (void)itemTableViewDataSourceDidLeaveOfflineMode:(DMItemTableViewController *)dataSource
{
}

- (void)itemTableViewDataSource:(DMItemTableViewController *)dataSource didFailWithError:(NSError *)error
{
    [UIAlertView showAlertViewWithTitle:@"Error"
                                message:error.localizedDescription
                      cancelButtonTitle:@"Dismiss"
                      otherButtonTitles:nil
                           dismissBlock:nil
                            cancelBlock:nil];
}

@end

@implementation UITableView (DMItemTableViewDataSource)

- (DMItemTableViewDataSource *)itemDataSource
{
    return (DMItemTableViewDataSource *)self.dataSource;
}

@end