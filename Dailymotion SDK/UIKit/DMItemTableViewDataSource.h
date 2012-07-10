//
//  DMItemTableViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"

static NSString *const DMItemTableViewDataSourceLoadingNotification = @"DMItemTableViewDataSourceLoadingNotification";
static NSString *const DMItemTableViewDataSourceUpdatedNotification = @"DMItemTableViewDataSourceUpdatedNotification";
static NSString *const DMItemTableViewDataSourceErrorNotification = @"DMItemTableViewDataSourceErrorNotification";
static NSString *const DMItemTableViewDataSourceOfflineNotification = @"DMItemTableViewDataSourceOfflineNotification";

@interface DMItemTableViewDataSource : NSObject <UITableViewDataSource>

@property (nonatomic, copy) NSString *cellIdentifier;
@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) NSError *lastError;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, assign) BOOL reorderable;

- (void)cancelAllOperations;

@end
