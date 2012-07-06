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

- (id)initWithType:(NSString *)type withItemIds:(NSArray *)ids fromAPI:(DMAPI *)api;

- (void)addItem:(DMItem *)item;
- (void)insertItem:(DMItem *)item atIndex:(NSUInteger)index;
- (void)removeItem:(DMItem *)item;
- (void)removeItemAtIndex:(NSUInteger)index;

@end
