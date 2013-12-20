//
//  DMItemTableViewController.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemTableViewDataSource.h"

/**
 * UITableViewController subclass configured to use DMItemTableViewDataSource as default datasource.
 *
 * To use this class, you must set the itemDataSource.cellIdentifier with a UITableViewCell reusable
 * identifier previously registered to the controller's tableView using registerClass:forCellReuseIdentifier:
 * or set in Interface Builder. Be careful to register a UITableViewCell sub-class which implement the
 * DMItemDataSourceItem protocol.
 *
 * To load data in the table, set the itemDataSource.itemCollection to the wanted DMItemCollection.
 * The best place to set this property is in the viewDidLoad method, but it can be set anywhere else.
 * Changing this property at any time will reload the table view to show the new data.
 */
@interface DMItemTableViewController : UITableViewController <DMItemTableViewDataSourceDelegate>

/**
 * @name Accessing the Data Source
 */

/**
 * The DMItemTableViewDataSource data source.
 */
@property(nonatomic, readonly) DMItemTableViewDataSource *itemDataSource;

@end