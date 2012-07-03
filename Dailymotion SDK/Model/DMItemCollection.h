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
@property (nonatomic, readonly, strong) DMAPI *api;
@property (nonatomic, readonly, assign) NSUInteger pageSize;
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;

/**
 * Return the current view of the object on the number of item that may be present in the list. This number
 * is an estimation that may be either be returned by the server or computed by the class when end of the
 * list is hit. When server doesn't return estimation on total items in the collection and client didn't
 * hit the end of the list, the estimated count is equal to the current number of cached item + `pageSize`,
 * which may be incorrect if the next page isn't full. When no item are cached yet, this field returns 0.
 */
@property (nonatomic, readonly, assign) NSUInteger currentEstimatedTotalItemsCount;

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
- (DMItemOperation *)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback;

/**
 * Gather the fields data for the item located at the given index in the collection. If colleciton as no information
 * for the given index yet, a list request is performed for a page of `pageSize` items. This pervents from
 * generating too many small requests.
 *
 * @prarm fields A list of object fields names to load
 * @param index The index of the requested item in the collection
 * @param callback The block to call with resulting field data
 *
 * @return A DMItemOperation instance able to cancel the request.
 */
- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback;

/**
 * Flush all previously loaded cache for this collection (won't flush items cache data)
 */
- (void)flushCache;

@end
