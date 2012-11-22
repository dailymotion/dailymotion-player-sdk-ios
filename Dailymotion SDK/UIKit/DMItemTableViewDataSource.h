//
//  DMItemTableViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"

@class DMItemTableViewDataSource;

/**
 * The DMItemTableViewDataSourceDelegate protocol defines optional methods for DMItemTableViewDataSource delegates.
 */
@protocol DMItemTableViewDataSourceDelegate <NSObject>

@optional

/**
 * Sent when the DMItemCollection is modified.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 */
- (void)itemTableViewDataSourceDidChange:(DMItemTableViewDataSource *)dataSource;

/**
 * Sent when the datasource estimated total number of item changed.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 * @param estimatedTotalItems The new estimated total number of items.
 */
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didUpdateWithEstimatedTotalItemsCount:(NSUInteger)estimatedTotalItems;

/**
 * Sent when the data source start to load data from the network.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 */
- (void)itemTableViewDataSourceDidStartLoadingData:(DMItemTableViewDataSource *)dataSource;

/**
 * Sent when the data source finished loading data from the network.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 */
- (void)itemTableViewDataSourceDidFinishLoadingData:(DMItemTableViewDataSource *)dataSource;

/**
 * Sent when the data for a cell has been loaded.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 * @param indexPath The indexPath of the cell (note: section is always 0).
 * @param data The loaded item data.
 */
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didLoadCellContentAtIndexPath:(NSIndexPath *)indexPath withData:(NSDictionary *)data;

/**
 * Sent when a cell has been deleted.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 * @param indexPath The indexPath of the deleted cell.
 */
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didDeleteCellAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Sent when the underlaying API goes offline either because the device lost its network connectivity
 * or if the Dailymotion API aren't reachable for some reason.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 */
- (void)itemTableViewDataSourceDidEnterOfflineMode:(DMItemTableViewDataSource *)dataSource;

/**
 * Sent when the network access to the underlaying API is restored.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 */
- (void)itemTableViewDataSourceDidLeaveOfflineMode:(DMItemTableViewDataSource *)dataSource;

/**
 * Sent when an error occures.
 *
 * @param dataSource The DMItemTableViewDataSource sending this message.
 * @param error The error
 */
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

/**
 * The DMItemTableViewDataSource class implements a standard UITableViewDataSource exposing data from the Dailymotion API
 * through a DMItemCollection.
 *
 * @see DMItemTableViewController for a ready to use `UITableViewController` setup with this data source.
 */
@interface DMItemTableViewDataSource : NSObject <UITableViewDataSource>

/**
 * @name Configuring Data Source
 */

/**
 * Automatic refresh of data source when model changes. Default value is YES
 */
@property (nonatomic, assign) BOOL autoReloadData;

/**
 * If set to YES, instruct the data source this DMItemCollection supports editing (insert and delete).
 */
@property (nonatomic, assign) BOOL editable;

/**
 * If set to YES, instruct the data source this DMItemCollection supports reordering of rows.
 */
@property (nonatomic, assign) BOOL reorderable;

/**
 * The UITableViewCell reusable identifier to be used for rows.
 *
 * This identifier must be set in interface builder or registered using `UITableView`'s `registerClass:forCellReuseIdentifier:` method.
 *
 * ATTENTION: The registered UITableViewCell must implemented the DMItemDataSourceItem protocol.
 */
@property (nonatomic, copy) NSString *cellIdentifier;


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
 * This object must implement the DMItemTableViewDataSourceDelegate protocol.
 */
@property (nonatomic, weak) id<DMItemTableViewDataSourceDelegate> delegate;

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
 * Reload the data source if data is salled
 */
- (void)reloadIfNeeded;


/**
 * Reload the data source data from network
 *
 * @param completionBlock Block to be called with reload is completed.
 */
- (void)reload:(void (^)())completionBlock;

@property (nonatomic, strong) NSError *lastError;


@end
