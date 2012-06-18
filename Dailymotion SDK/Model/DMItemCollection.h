//
//  DMItemCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItem.h"

@class DMAPI;

@interface DMItemCollection : NSObject

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, copy) NSDictionary *params;
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;

/**
 * Instanciate an item collection for a given object type with some optional paramters
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param params Parameters to filter or sort the result
 * @param api The DMAPI object to use to retrieve data
 */
+ (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

/**
 * Instanciate an item collection for an item connection
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feed)
 * @param item The item to load connection from
 * @param params Optional parameters to filter/sort the result
 * @param api The DMAPI object to use to retrieve data
 */
+ (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

/**
 * Retrieve items with specified pre-cached fields on the current collection with given pagination information.
 *
 * The data may come from cache or network. If cached data are stalled, the block will be called twice. First time
 * the data will come from the stalled cache, the `stalled` parameter is then set to `YES`. In parallele, an API
 * request is automatically performed to retrieve fresh data. On success the block is called a second time with
 * the `stalled` parameter set to `NO`.
 */
- (void)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback;

/**
 * Flush all previously loaded cache for this collection (won't flush items cache data)
 */
- (void)flushCache;

@end
