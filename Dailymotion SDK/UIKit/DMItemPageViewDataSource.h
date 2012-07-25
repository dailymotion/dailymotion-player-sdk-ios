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

@protocol DMItemPageViewDataSourceDelegate <NSObject>

@optional

- (void)itemPageViewDataSource:(DMItemPageViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

@interface DMItemPageViewDataSource : NSObject <UIPageViewControllerDataSource>

@property (nonatomic, weak) id<DMItemPageViewDataSourceDelegate> delegate;
@property (nonatomic, strong) UIViewController<DMItemDataSourceItem> *(^createViewControllerBlock)();
@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) NSError *lastError;

- (UIViewController<DMItemDataSourceItem> *)viewControllerAtIndex:(NSUInteger)index;

@end
