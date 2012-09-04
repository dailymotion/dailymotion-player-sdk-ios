//
//  DMItem.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMAPI.h"
#import "DMItemOperation.h"

@class DMItemCollection;

@interface DMItem : NSObject <NSCoding>

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, copy) NSString *itemId;
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, readonly, strong) DMAPI *api;
@property (nonatomic, readonly, copy) NSDictionary *cachedFields;

/**
 * Get an DMItem for a given object name (i.e.: video, user, playlist) and an object id
 *
 * @param type The item type name
 * @param objectId The item id
 * @param api The DMAPI object to use to retrieve item data
 *
 * @return A shared instance of DMItem for the requested object
 */
+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api;

/**
 * Get an DMItem for a given object name (i.e.: video, user, playlist) and an object id
 *
 * @param type The item type name
 * @param objectId The item id
 *
 * @return A shared instance of DMItem for the requested object
 */
+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId;

/**
 * Get an instance of DMItemCollection of a given connection to the item
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feed)
 * @param type The connection type name
 * @param item The item to load connection from
 * @param params Optional parameters to filter/sort the result
 *
 * @see DMItemCollection
 */
- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type withParams:(NSDictionary *)params;

/**
 * Get an instance of DMItemCollection of a given connection to the item
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feed)
 * @param type The connection type name
 * @param item The item to load connection from
 *
 * @see DMItemCollection
 */
- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type;

/**
 * Load some fields from either API or cache and callback the passed block with the fields data
 *
 * NOTE: The callback may be called twice if the data was found in the cache but stalled.
 *       First time, the callback will be returned with `stalled` parameter to YES and second time
 *       the `stalled` parameter will be NO. If some fields are cached and other are missing, the
 *       a first callback will return all available fields data and stalled flag will be YES.
 *
 * @prarm fields A list of object fields names to load
 * @param callback The block to call with resulting field data
 *
 * @return A DMItemOperation instance able to cancel the request
 */
- (DMItemOperation *)withFields:(NSArray *)fields do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback;

/**
 * Edit some item fields
 *
 * @param data A dictionary containing fields to modify with their new value
 * @param done The block to call when operation is completed
 *
 * @return A DMItemOperation instance able to cancel the request
 */
- (DMItemOperation *)editWithData:(NSDictionary *)data done:(void (^)(NSError *error))callback;

/**
 * Test if fields are present in the cache
 *
 * @prarm fields A list of object fields names to test
 */
- (BOOL)areFieldsCached:(NSArray *)fields;

/**
 * Flush all previously loaded cache for this item
 */
- (void)flushCache;

@end
