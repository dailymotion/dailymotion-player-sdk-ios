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

@protocol DMItemTableViewDataSourceDelegate <NSObject>

@optional

- (void)itemTableViewDataSourceStartedLoadingData:(DMItemTableViewDataSource *)dataSource;
- (void)itemTableViewDataSourceDidUpdateContent:(DMItemTableViewDataSource *)dataSource;
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didLoadCellContentAtIndexPath:(NSIndexPath *)indexPath withData:(NSDictionary *)data;
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didDeleteCellAtIndexPath:(NSIndexPath *)indexPath;
- (void)itemTableViewDataSourceDidEnterOfflineMode:(DMItemTableViewDataSource *)dataSource;
- (void)itemTableViewDataSourceDidLeaveOfflineMode:(DMItemTableViewDataSource *)dataSource;
- (void)itemTableViewDataSource:(DMItemTableViewDataSource *)dataSource didFailWithError:(NSError *)error;

@end

@interface DMItemTableViewDataSource : NSObject <UITableViewDataSource>

@property (nonatomic, weak) id<DMItemTableViewDataSourceDelegate> delegate;
@property (nonatomic, copy) NSString *cellIdentifier;
@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) NSError *lastError;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, assign) BOOL reorderable;

- (void)cancelAllOperations;

@end
