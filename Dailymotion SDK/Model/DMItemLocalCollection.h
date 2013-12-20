//
//  DMItemLocalCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"

/**
 * This class handles locally stored list of (remote) DMItem objects. It may be used to implement features like
 * history, unlogged favorites, quicklists etc.
 */
@interface DMItemLocalCollection : DMItemCollection <NSCoding>

/**
 * @name Initializing Local Collection
 */

/**
 * New local collection with a list of DMItem ids.
 * Prefer itemLocalConnectionWithType:withIds:countLimit:fromAPI: to this method.
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param ids The list of item ids to store in the collection
 * @param countLimit The maximum number of item allowed in the collection
 * @param api The DMAPI object to use to retrieve data
 */
- (id)initWithType:(NSString *)type withItemIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * @name Collection Settings
 */

/**
 * Tells the maxiumum number of items in the collection. If more items are added to the collection,
 * the items at the opposite side of the collection will be removed. A limit of 0 means no limit.
 */
@property(nonatomic, readonly) NSUInteger countLimit;

/**
 * The list of DMItem objects stored in this collection
 */
@property(nonatomic, readonly) NSOrderedSet *items;


/**
 * @name Editing Local Collection
 */

/**
 * Remove all the items of the collection
 */
- (void)clear;


@end
