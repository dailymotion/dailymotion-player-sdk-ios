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

static NSString *const DMItemPageViewDataSourceUpdatedNotification = @"DMItemPageViewDataSourceUpdatedNotification";
static NSString *const DMItemPageViewDataSourceErrorNotification = @"DMItemPageViewDataSourceErrorNotification";
static NSString *const DMItemPageViewDataSourceOfflineNotification = @"DMItemPageViewDataSourceOfflineNotification";

@interface DMItemPageViewDataSource : NSObject <UIPageViewControllerDataSource>

@property (nonatomic, strong) UIViewController<DMItemDataSourceItem> *(^createViewControllerBlock)();
@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) NSError *lastError;

- (UIViewController<DMItemDataSourceItem> *)viewControllerAtIndex:(NSUInteger)index;

@end
