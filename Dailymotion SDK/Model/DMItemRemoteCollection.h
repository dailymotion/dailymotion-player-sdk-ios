//
//  DMItemRemoteCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMAPICacheInfo.h"
#import "DMItemCollection.h"

/**
 * Concreat implementation of DMItemCollection handling remote list of DMItem to be retrived thru the Dailymotion API.
 */
@interface DMItemRemoteCollection : DMItemCollection  <NSCoding>

@property (nonatomic, readonly, assign) NSUInteger pageSize;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) NSDictionary *params;
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;

- (id)initWithType:(NSString *)type params:(NSDictionary *)params path:(NSString *)path fromAPI:(DMAPI *)api;

/**
 * Retrieve items with specified pre-cached fields on the current collection with given pagination information.
 *
 * The data may come from cache or network. If cached data are stalled, the block will be called twice. First time
 * the data will come from the stalled cache, the `stalled` parameter is then set to `YES`. In parallele, an API
 * request is automatically performed to retrieve fresh data. On success the block is called a second time with
 * the `stalled` parameter set to `NO`.
 *
 * @param fields The list of fields to retrieve for each items of the list.
 * @param page The page offset.
 * @param itemsPerPage The number of items per page to retrieve.
 * @param callback The block to be called with the result.
 */
- (DMItemOperation *)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback;

@end
