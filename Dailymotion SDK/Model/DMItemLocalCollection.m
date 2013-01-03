//
//  DMItemLocalCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import "DMItemLocalCollection.h"
#import "DMSubscriptingSupport.h"

static DMItemOperation *fakeOperation()
{
    DMItemOperation *finishedOperation = [[DMItemOperation alloc] init];
    finishedOperation.isFinished = YES;
    return finishedOperation;
}


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
        self.currentEstimatedTotalItemsCount = __items.count;
    }
    return self;
}

#pragma mark - Archiving

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        __items = [[coder decodeObjectForKey:@"_items"] mutableCopy];
        _countLimit = [coder decodeIntegerForKey:@"countLimit"];
        self.currentEstimatedTotalItemsCount = __items.count;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:__items forKey:@"_items"];
    [coder encodeInteger:_countLimit forKey:@"countLimit"];
}

- (NSOrderedSet *)items
{
    return [NSOrderedSet orderedSetWithOrderedSet:self._items];
}

#pragma mark - Implementation

- (DMItem *)itemWithId:(NSString *)itemId;
{
    for (DMItem *item in self._items)
    {
        if ([item isKindOfClass:DMItem.class] && [item.itemId isEqualToString:itemId])
        {
            return item;
        }
    }

    return [DMItem itemWithType:self.type forId:itemId];
}

- (BOOL)isLocal
{
    return YES;
}

- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    if (index < [self._items count])
    {
        return [(DMItem *)[self._items objectAtIndex:index] withFields:fields do:callback];
    }
    else
    {
        dispatch_async(dispatch_get_current_queue(), ^
        {
            callback(nil, NO, nil);
        });
        DMItemOperation *finishedOperation = [[DMItemOperation alloc] init];
        finishedOperation.isFinished = YES;
        return finishedOperation;
    }
}

- (DMItemOperation *)itemAtIndex:(NSUInteger)index withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback;
{
    return [self withItemFields:fields atIndex:index do:^(NSDictionary *devnull, BOOL stalled, NSError *error)
    {
        if (error)
        {
            callback(nil, error);
        }
        else if (index < [self._items count])
        {
            callback([self._items objectAtIndex:index], nil);
        }
        else
        {
            callback(nil, nil);
        }                                                 
    }];
}

- (DMItemOperation *)itemBeforeItem:(DMItem *)item withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    NSInteger idx = [self._items indexOfObject:item];
    if (idx != NSNotFound && idx > 0)
    {
        return [self itemAtIndex:idx - 1 withFields:fields done:callback];
    }
    else
    {
        DMItemOperation *finishedOperation = DMItemOperation.new;
        dispatch_async(dispatch_get_current_queue(), ^
        {
            finishedOperation.isFinished = YES;
            callback(nil, nil);
        });
        return finishedOperation;
    }
}

- (DMItemOperation *)itemAfterItem:(DMItem *)item withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    NSInteger idx = [self._items indexOfObject:item];
    if (idx != NSNotFound)
    {
        return [self itemAtIndex:idx + 1 withFields:fields done:callback];
    }
    else
    {
        DMItemOperation *finishedOperation = DMItemOperation.new;
        dispatch_async(dispatch_get_current_queue(), ^
        {
            finishedOperation.isFinished = YES;
            callback(nil, nil);
        });
        return finishedOperation;
    }
}

- (DMItemOperation *)checkPresenceOfItem:(DMItem *)item do:(void (^)(BOOL present, NSError *error))callback
{
    DMItemOperation *finishedOperation = DMItemOperation.new;
    finishedOperation.isFinished = YES;
    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback([self._items containsObject:item], nil);
    });
    return finishedOperation;
}

- (void)checkItem:(DMItem *)item
{
    NSAssert([item.type isEqual:self.type], @"Item type must match collection type");
}

- (BOOL)canEdit
{
    return YES;
}

- (DMItemOperation *)addItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    if (![self._items containsObject:item])
    {
        [self checkItem:item];
        [self._items insertObject:item atIndex:0];
        if (self.countLimit != 0 && self._items.count > self.countLimit)
        {
            [self._items removeObjectsInRange:NSMakeRange(self.countLimit, self._items.count - self.countLimit)];
        }
        self.currentEstimatedTotalItemsCount = self._items.count;
    }

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

- (DMItemOperation *)removeItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    [self checkItem:item];
    [self._items removeObject:item];
    self.currentEstimatedTotalItemsCount = self._items.count;

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback
{
    [self._items removeObjectAtIndex:index];
    self.currentEstimatedTotalItemsCount = self._items.count;

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

- (void)clear
{
    [self._items removeAllObjects];
    self.currentEstimatedTotalItemsCount = self._items.count;
}

- (BOOL)canReorder
{
    return YES;
}

- (DMItemOperation *)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex done:(void (^)(NSError *))callback
{
    [self._items moveObjectsAtIndexes:[NSIndexSet indexSetWithIndex:fromIndex] toIndex:toIndex];
    self.currentEstimatedTotalItemsCount = self._items.count; // generate KVO notification to indicate the list changed

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

@end
