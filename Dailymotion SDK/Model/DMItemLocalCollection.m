//
//  DMItemLocalCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import "DMItemLocalCollection.h"
#import "DMSubscriptingSupport.h"

@interface DMItemCollection (Private)

- (id)initWithType:(NSString *)type api:(DMAPI *)api;

@end


@interface DMItemLocalCollection ()

@property (nonatomic, readwrite, assign) NSUInteger currentEstimatedTotalItemsCount;
@property (nonatomic, strong) NSMutableOrderedSet *_items;

@end


@implementation DMItemLocalCollection

- (id)initWithType:(NSString *)type withItemIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    if ((self = [self initWithType:type api:api]))
    {
        __items = NSMutableOrderedSet.orderedSet;
        for (NSString *itemId in ids)
        {
            [__items addObject:[DMItem itemWithType:type forId:itemId fromAPI:api]];
        }
        _countLimit = countLimit;
        self.currentEstimatedTotalItemsCount = ids.count;
    }
    return self;
}

#pragma mark - Archiving

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        __items = [coder decodeObjectForKey:@"_items"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:__items forKey:@"_items"];
}

#pragma mark - Implementation

- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    if (index < [self._items count])
    {
        return [(DMItem *)self._items[index] withFields:fields do:callback];
    }
    else
    {
        callback(nil, NO, nil);
        DMItemOperation *finishedOperation = [[DMItemOperation alloc] init];
        finishedOperation.isFinished = YES;
        return finishedOperation;
    }
}

- (void)checkItem:(DMItem *)item
{
    NSAssert([item.type isEqual:self.type], @"Item type must match collection type");
}

- (void)addItem:(DMItem *)item
{
    [self checkItem:item];
    [self._items removeObject:item];
    [self._items addObject:item];
    if (self._items.count > self.countLimit)
    {
        [self._items removeObjectsInRange:NSMakeRange(0, self._items.count - self.countLimit)];
    }
    self.currentEstimatedTotalItemsCount = self._items.count;
}

- (void)pushItem:(DMItem *)item
{
    [self checkItem:item];
    [self._items removeObject:item];
    [self._items insertObject:item atIndex:0];
    if (self._items.count > self.countLimit)
    {
        [self._items removeObjectsInRange:NSMakeRange(self.countLimit, self._items.count - self.countLimit)];
    }
    self.currentEstimatedTotalItemsCount = self._items.count;
}

- (void)removeItem:(DMItem *)item
{
    [self checkItem:item];
    [self._items removeObject:item];
    self.currentEstimatedTotalItemsCount = self._items.count;
}

- (void)removeItemAtIndex:(NSUInteger)index
{
    [self._items removeObjectAtIndex:index];
    self.currentEstimatedTotalItemsCount = self._items.count;
}

@end
