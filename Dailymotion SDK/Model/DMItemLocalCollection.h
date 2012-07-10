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

@end
