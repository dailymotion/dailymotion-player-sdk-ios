//
//  DMItemCollectionViewController.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 21/09/12.
//
//

#import "DMItemCollectionViewController.h"
#import "DMAlert.h"

@interface DMItemCollectionViewController ()

@property(nonatomic, readwrite) DMItemCollectionViewDataSource *itemDataSource;

@end

@implementation DMItemCollectionViewController

- (DMItemCollectionViewDataSource *)itemDataSource {
    if (!_itemDataSource) {
        _itemDataSource = [[DMItemCollectionViewDataSource alloc] init];
        _itemDataSource.delegate = self;
    }

    return _itemDataSource;
}

#pragma Table Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.itemDataSource collectionView:collectionView numberOfItemsInSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.itemDataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
}

#pragma mark - DMItemTableViewDataSourceDelegate

- (void)itemCollectionViewDataSourceDidChange:(DMItemCollectionViewDataSource *)dataSource; {
}

- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didUpdateWithEstimatedTotalItemsCount:(NSUInteger)estimatedTotalItems {
}

- (void)itemCollectionViewDataSourceDidStartLoadingData:(DMItemCollectionViewDataSource *)dataSource {
}

- (void)itemCollectionViewDataSourceDidFinishLoadingData:(DMItemCollectionViewController *)dataSource {
}

- (void)itemCollectionViewDataSourceDidEnterOfflineMode:(DMItemCollectionViewController *)dataSource {
}

- (void)itemCollectionViewDataSourceDidLeaveOfflineMode:(DMItemCollectionViewController *)dataSource {
}

- (void)itemCollectionViewDataSource:(DMItemCollectionViewController *)dataSource didFailWithError:(NSError *)error {
    [DMAlertView showAlertViewWithTitle:@"Error"
                                message:error.localizedDescription
                      cancelButtonTitle:@"Dismiss"
                      otherButtonTitles:nil
                           dismissBlock:nil
                            cancelBlock:nil];
}

@end

@implementation UICollectionView (DMItemCollectionViewDataSource)

- (DMItemCollectionViewDataSource *)itemDataSource {
    return (DMItemCollectionViewDataSource *) self.dataSource;
}

@end
