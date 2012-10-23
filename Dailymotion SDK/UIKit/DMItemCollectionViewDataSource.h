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

/**
 * The DMItemCollectionViewDataSourceDelegate protocol defines optional methods for DMItemCollectionViewDataSource delegates.
 */
@protocol DMItemCollectionViewDataSourceDelegate <NSObject>

@optional

/**
 * Sent when the DMItemCollection is modified.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 */
- (void)itemCollectionViewDataSourceDidChange:(DMItemCollectionViewDataSource *)dataSource;

/**
 * Sent when the datasource estimated total number of item changed.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 * @param estimatedTotalItems The new estimated total number of items.
 */
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didUpdateWithEstimatedTotalItemsCount:(NSUInteger)estimatedTotalItems;

/**
 * Sent when the data source start to load data from the network.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 */
- (void)itemCollectionViewDataSourceDidStartLoadingData:(DMItemCollectionViewDataSource *)dataSource;

/**
 * Sent when the data source finished loading data from the network.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 */
- (void)itemCollectionViewDataSourceDidFinishLoadingData:(DMItemCollectionViewDataSource *)dataSource;

/**
 * Sent when the data for a cell has been loaded.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 * @param indexPath The indexPath of the cell (note: section is always 0).
 * @param data The loaded item data.
 */
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didLoadCellContentAtIndexPath:(NSIndexPath *)indexPath withData:(NSDictionary *)data;

/**
 * Sent when a cell has been deleted.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 * @param indexPath The indexPath of the deleted cell.
 */
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didDeleteCellAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Sent when the underlaying API goes offline either because the device lost its network connectivity
 * or if the Dailymotion API aren't reachable for some reason.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 */
- (void)itemCollectionViewDataSourceDidEnterOfflineMode:(DMItemCollectionViewDataSource *)dataSource;

/**
 * Sent when the network access to the underlaying API is restored.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 */
- (void)itemCollectionViewDataSourceDidLeaveOfflineMode:(DMItemCollectionViewDataSource *)dataSource;

/**
 * Sent when an error occures.
 *
 * @param dataSource The DMItemCollectionViewDataSource sending this message.
 * @param error The error
 */
- (void)itemCollectionViewDataSource:(DMItemCollectionViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

/**
 * The DMItemCollectionViewDataSource class implements a standard UICollectionViewDataSource exposing data
 * from the Dailymotion API through a DMItemCollection.
 *
 * @see DMItemCollectionViewController for a ready to use `UICollectionViewController` setup with this data source.
 */
@interface DMItemCollectionViewDataSource : NSObject <UICollectionViewDataSource>

/**
 * @name Configuring Data Source
 */

/**
 * If set to YES, instruct the data source this DMItemCollection supports editing (insert and delete).
 */
@property (nonatomic, assign) BOOL editable;

/**
 * If set to YES, instruct the data source this DMItemCollection supports reordering of rows.
 */
@property (nonatomic, assign) BOOL reorderable;

/**
 * The UICollectionViewCell reusable identifier to be used for items.
 */
@property (nonatomic, assign) NSString *cellIdentifier;

/**
 * The UICollectionViewCell to be used for items.
 */
@property (nonatomic, assign) Class cellClass;

/**
 * The DMItemCollection used as source to access data.
 */
@property (nonatomic, strong) DMItemCollection *itemCollection;

/**
 * @name Accessing the Delegate
 */

/**
 * The object that acts as the delegate of the receiving data source.
 *
 * This object must implement the DMItemCollectionViewDataSourceDelegate protocol.
 */
@property (nonatomic, weak) id<DMItemCollectionViewDataSourceDelegate> delegate;

/**
 * @name Cancelling
 */

/**
 * Cancel all running requests for this data source.
 */
- (void)cancelAllOperations;

/**
 * @name Reloading
 */

/**
 * Reload the data source data from network
 */
- (void)reload;

/**
 * Reload the data source data from network
 *
 * @param completionBlock Block to be called with reload is completed.
 */
- (void)reload:(void (^)())completionBlock;

@property (nonatomic, strong) NSError *lastError;


@end
