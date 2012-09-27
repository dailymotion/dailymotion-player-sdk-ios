//
//  DMItemCollectionViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 21/09/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemCollection.h"

@class DMItemCollectionViewDataSource;

@protocol DMItemCollectionViewDataSourceDelegate <NSObject>

@optional

- (void)itemCollectionViewDataSourceDidChange:(DMItemCollectionViewDataSource *)dataSource;
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didUpdateWithEstimatedTotalItemsCount:(NSUInteger)estimatedTotalItems;
- (void)itemCollectionViewDataSourceDidStartLoadingData:(DMItemCollectionViewDataSource *)dataSource;
- (void)itemCollectionViewDataSourceDidFinishLoadingData:(DMItemCollectionViewDataSource *)dataSource;
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didLoadCellContentAtIndexPath:(NSIndexPath *)indexPath withData:(NSDictionary *)data;
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didDeleteCellAtIndexPath:(NSIndexPath *)indexPath;
- (void)itemCollectionViewDataSourceDidEnterOfflineMode:(DMItemCollectionViewDataSource *)dataSource;
- (void)itemCollectionViewDataSourceDidLeaveOfflineMode:(DMItemCollectionViewDataSource *)dataSource;
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

@interface DMItemCollectionViewDataSource : NSObject <UICollectionViewDataSource>

@property (nonatomic, weak) id<DMItemCollectionViewDataSourceDelegate> delegate;
@property (nonatomic, assign) Class cellClass;
@property (nonatomic, assign) NSString *cellIdentifier;
@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) NSError *lastError;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, assign) BOOL reorderable;

- (void)cancelAllOperations;
- (void)reload:(void (^)())completionBlock;

@end
