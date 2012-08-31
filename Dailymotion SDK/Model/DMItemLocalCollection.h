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
 * the items at the opposite side of the collection will be removed. A limit of 0 means no limit.
 */
@property (nonatomic, readonly) NSUInteger countLimit;
@property (nonatomic, readonly) NSOrderedSet *items;

- (id)initWithType:(NSString *)type withItemIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Remove all the items of the collection
 */
- (void)clear;


@end
