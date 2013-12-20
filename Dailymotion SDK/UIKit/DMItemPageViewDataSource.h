//
//  DMItemPageViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"
#import "DMItemDataSourceItem.h"

@class DMItemPageViewDataSource;

/**
 * The DMItemPageViewDataSourceDelegate defines optional methods to be implemented by DMItemPageViewDataSource delegate.
 */
@protocol DMItemPageViewDataSourceDelegate <NSObject>

@optional

/**
 * Sent when the data source ecouenters an error
 *
 * @param dataSource The DMItemPageViewDataSource sending the message
 * @param error The ecouentered error
 */
- (void)itemPageViewDataSource:(DMItemPageViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

/**
 * UIPageViewController data source
 */
@interface DMItemPageViewDataSource : NSObject <UIPageViewControllerDataSource>

/**
 * The object that acts as the delegate of the receiving data source.
 */
@property(nonatomic, weak) id <DMItemPageViewDataSourceDelegate> delegate;

/**
 * A block to be called when a new UIViewController should be created. This property is mandatory.
 */
@property(nonatomic, strong) UIViewController <DMItemDataSourceItem> *(^createViewControllerBlock)();

/**
 * The DMItemCollection instance to be used as data source.
 */
@property(nonatomic, strong) DMItemCollection *itemCollection;

/**
 * The last returned error.
 */
@property(nonatomic, strong) NSError *lastError;

/**
 * Returns the view controller for the given index.
 *
 * @param index The view controller index to return
 */
- (UIViewController <DMItemDataSourceItem> *)viewControllerAtIndex:(NSUInteger)index;

@end
