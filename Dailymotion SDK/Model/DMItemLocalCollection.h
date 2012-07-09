//
//  DMItemLocalCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"

@interface DMItemLocalCollection : DMItemCollection <NSCoding>

/**
 * Tells the maxiumum number of items in the collection. If more items are added to the collection,
 * the items at the opposite side of the collection will be removed.
 */
@property (nonatomic, readonly) NSUInteger countLimit;

- (id)initWithType:(NSString *)type withItemIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Add the given item to the end of the local collection if not already present in the collection.
 * If the collection hit the `countLimit`, the item at the beginning of the collection is removed.
 *
 * @param item The item to add
 */
- (void)addItem:(DMItem *)item;

/**
 * Insert an item at the beginning of the collection if not already present.
 * If the collection hit the `countLimit`, the item at the end of the collection is removed.
 *
 * @param item The item to insert
 */
- (void)pushItem:(DMItem *)item;

/**
 * Remove the item from the collection.
 *
 * @param item The item to remove
 */
- (void)removeItem:(DMItem *)item;

/**
 * Remove the item a the given location
 *
 * @param index The index of the item to remove
 */
- (void)removeItemAtIndex:(NSUInteger)index;

/**
 * Move an item from an index to another
 *
 * @param fromIndex Index of the item to move
 * @param toIndex Index to move the item to
 */
- (void)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
