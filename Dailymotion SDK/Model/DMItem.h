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

/**
 * A kind of ORM for Dailymotion remote objects. This class handles API calls, caching of results, cache invalidation etc.
 */
@interface DMItem : NSObject <NSCoding>

/** @name Creating a DMItem Instance */

/**
 * Get an DMItem for a given object name (i.e.: video, user, playlist) and an object id
 *
 * @param type The item type name
 * @param itemId The item id
 * @param api The DMAPI object to use to retrieve item data
 *
 * @return A shared instance of DMItem for the requested object
 */
+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId fromAPI:(DMAPI *)api;

/**
 * Get an DMItem for a given object name (i.e.: video, user, playlist) and an object id
 *
 * @param type The item type name
 * @param itemId The item id
 *
 * @return A shared instance of DMItem for the requested object
 */
+ (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId;

/** @name Getting Connected Collections */

/**
 * Get an instance of DMItemCollection of a given connection to the item
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feed)
 * @param type The connection type name
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
 *
 * @see DMItemCollection
 */
- (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type;

/** @name Properties */

/** The item type (ie: video, comment, user) */
@property (nonatomic, readonly, copy) NSString *type;
/** The item id */
@property (nonatomic, readonly, copy) NSString *itemId;
/** Current cache info for the item */
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;
/** The underlaying DMAPI instance */
@property (nonatomic, readonly, strong) DMAPI *api;
/** Cached fields */
@property (nonatomic, readonly, copy) NSDictionary *cachedFields;

/** @name Reading and Writing Item Fields */

/**
 * Load some fields from either API or cache and callback the passed block with the fields data
 *
 * NOTE: The callback may be called twice if the data was found in the cache but stalled.
 *       First time, the callback will be returned with `stalled` parameter to YES and second time
 *       the `stalled` parameter will be NO. If some fields are cached and other are missing, the
 *       a first callback will return all available fields data and stalled flag will be YES.
 *
 * @param fields A list of object fields names to load
 * @param callback The block to call with resulting field data
 *
 * @return A DMItemOperation instance able to cancel the request
 */
- (DMItemOperation *)withFields:(NSArray *)fields do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback;

/**
 * Edit some item fields
 *
 * @param data A dictionary containing fields to modify with their new value
 * @param callback The block to call when operation is completed
 *
 * @return A DMItemOperation instance able to cancel the request
 */
- (DMItemOperation *)editWithData:(NSDictionary *)data done:(void (^)(NSError *error))callback;

/** @name Managing Cache */

/**
 * Test if fields are present in the cache
 *
 * @param fields A list of object fields names to test
 */
- (BOOL)areFieldsCached:(NSArray *)fields;

/**
 * Flush all previously loaded cache for this item
 */
- (void)flushCache;

/**
 * Get a DMItem from an object field
 *
 * @param type The type of the sub item
 * @param subItemField The name of the field holding the sub item
 * @param callback The block to call with the initialized sub item
 *
 * @return A DMItemOperation instance able to cancel the request
 */
- (DMItemOperation *)subItemWithType:(NSString *)type forField:(NSString *)subItemField done:(void (^)(DMItem *item, NSError *error))callback;

@end
