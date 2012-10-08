//
//  DMItemCollectionViewController.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 21/09/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemCollectionViewDataSource.h"

/**
 * UICollectionViewController subclass configured to use DMItemCollectionViewDataSource as default datasource.
 *
 * To use this class, you must set the itemDataSource.cellIdentifier and itemDataSource.cellClass with
 * a UICollectionViewCell reusable identifier and class previously registered to the controller's
 * collectionView using registerClass:forCellWithReuseIdentifier: or set in Interface Builder.
 * Be careful to register a UICollectionViewCell sub-class which implement the DMItemDataSourceItem protocol.
 *
 * To load data in the table, set the itemDataSource.itemCollection to the wanted DMItemCollection.
 * The best place to set this property is in the viewDidLoad method, but it can be set anywhere else.
 * Changing this property at any time will reload the table view to show the new data.
 */
@interface DMItemCollectionViewController : UICollectionViewController <DMItemCollectionViewDataSourceDelegate>

/**
 * @name Accessing the Data Source
 */

/**
 * The DMItemTableViewDataSource data source.
 */
@property (nonatomic, readonly) DMItemCollectionViewDataSource *itemDataSource;

@end
