//
//  DMItemCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItem.h"

/**
 * Abstract (cluster) class for DMItem collection handling. This object is used to handle list of DMItem.
 * There is two concreat implementation of this class:
 *
 * - DMItemRemoteCollection is used to handle list of DMItem objects stored on Dailymotion (i.e.: searches, playlists, comments, etc.)
 * - DMItemLocalCollection is used to handle locally stored list of (remote) DMItem objects (i.e.: history, quicklist)
 */
@interface DMItemCollection : NSObject <NSCoding>

/**
 * @name Creating a DMItemCollection Instance
 */

/**
 * Return an empty local collection of items
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param countLimit The maximum number of item allowed in the collection
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Return an empty local collection of items
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param countLimit The maximum number of item allowed in the collection
 */
+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit;

/**
 * Return a local collection of items with the given ids
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param ids The list of item ids to store in the collection
 * @param countLimit The maximum number of item allowed in the collection
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Return a local collection of items with the given ids
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param ids The list of item ids to store in the collection
 * @param countLimit The maximum number of item allowed in the collection
 */
+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit;

/**
 * Instanciate an item collection for a given object type with some optional paramters
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param params Parameters to filter or sort the result
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

/**
 * Instanciate an item collection for a given object type with some optional paramters
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param params Parameters to filter or sort the result
 */
+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params;

/**
 * Instanciate an item collection for an item connection
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feeds)
 * @param type The item type name (i.e.: video, user, playlist)
 * @param item The item to load connection from
 * @param params Optional parameters to filter/sort the result
 */
+ (id)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type forItem:(DMItem *)item withParams:(NSDictionary *)params;

/**
 * Instanciate an item collection for an item connection
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feeds)
 * @param type The item type name (i.e.: video, user, playlist)
 * @param item The item to load connection from
 */
+ (id)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type forItem:(DMItem *)item;

/**
 * Load a collection from a previously archived collection file.
 *
 * NOTE: This method is synchrone, you must not call it from main thread
 *
 * @param filePath Path to the archive file
 * @param api The DMAPI object to use with the unarchived collection
 */
+ (id)itemCollectionFromFile:(NSString *)filePath withAPI:(DMAPI *)api;

/**
 * Load a collection from a previously archived collection file.
 *
 * NOTE: This method is synchrone, you must not call it from main thread
 *
 * @param filePath Path to the archive file
 */
+ (id)itemCollectionFromFile:(NSString *)filePath;

/**
 * @name Properties
 */

/** The DMItem type of DMItem objects contained in this collection (ie: video, comment, user) */
@property (nonatomic, readonly, copy) NSString *type;

/** The underlaying DMAPI instance */
@property (nonatomic, readonly, strong) DMAPI *api;

/**
 * Return YES if the collection isn't comming from the remote API
 */
- (BOOL)isLocal;

/**
 * Return the current view of the object on the number of item that may be present in the list.
 *
 * This number is an estimation that may be either returned by the server or computed by the class.
 * You may use KVO on this property to know when the collection content has changed so you can refresh
 * the UI.
 */
@property (nonatomic, readonly, assign) NSUInteger currentEstimatedTotalItemsCount;

/**
 * @name Writting Collection to Disk
 */

/**
 * Persists the collection with currenly cached items data to disk
 *
 * NOTE: This method is synchrone, you must not call it from main thread
 *
 * @param filePath Path to the archive file
 * @return Return YES on success
 */
- (BOOL)saveToFile:(NSString *)filePath;

/**
 * @name Reading Collection
 */

/**
 * Gather the fields data for the item located at the given index in the collection.
 * @param fields A list of object fields names to load
 * @param index The index of the requested item in the collection
 * @param callback The block to call with resulting field data
 *
 * @return A DMItemOperation instance able to cancel the request.
 */
- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback;

/**
 * Fetch the DMItem for the collection at a specified index in order to edit it
 *
 * @param index The index of the item to edit
 * @param fields The fields to load with the item
 * @param callback The block to call once operation is completed
 *
 * @return A DMItemOperation instance able to cancel the request.
 */
- (DMItemOperation *)itemAtIndex:(NSUInteger)index withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback;

/**
 * Check of a given item is present in the collection.
 * NOTE: This does only work with connections or local collections. For remote collections it generates
 * the following request: GET /<object>/ID/<connection>/ITEM_ID
 *
 * @param item The item to check presence of
 * @param callback The block to call once operation is completed
 *
 * @return A DMItemOperation instance able to cancel the request.
 */
- (DMItemOperation *)checkPresenceOfItem:(DMItem *)item do:(void (^)(BOOL present, NSError *error))callback;

/**
 * @name Editing Collection
 */

/**
 * Indicates if the collection can be edited by adding or deleting items.
 */
- (BOOL)canEdit;

/**
 * Insert an item at the head of the collection if not already present.
 * If the collection hit the `countLimit`, the item at the end of the collection is removed.
 *
 * @param item The item to insert
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)addItem:(DMItem *)item done:(void (^)(NSError *error))callback;

/**
 * Remove the item from the collection.
 *
 * @param item The item to remove.
 * @param callback The block to be called once operation is completed.
 */
- (DMItemOperation *)removeItem:(DMItem *)item done:(void (^)(NSError *error))callback;

/**
 * Remove the item a the given location
 *
 * @param index The index of the item to remove
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback;

/**
 * Indicates if the item if the collection can be reordered using `moveItemAtIndex:toIndex:` method.
 */
- (BOOL)canReorder;

/**
 * Move an item from an index to another
 *
 * @param fromIndex Index of the item to move
 * @param toIndex Index to move the item to
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex done:(void (^)(NSError *error))callback;

/**
 * @name Managing Cache
 */

/**
 * Return a DMItem with same type as the current collection for the given id. If the collection as
 * an item with the same id in its cache, the cached item is returned.
 *
 * @param itemId The id of the item to return.
 *
 * @return DMItem from the collection's cache if any or a new item otherwise.
 */
- (DMItem *)itemWithId:(NSString *)itemId;

/**
 * Flush all previously loaded cache for this collection (won't flush items cache data)
 */
- (void)flushCache;

@end
