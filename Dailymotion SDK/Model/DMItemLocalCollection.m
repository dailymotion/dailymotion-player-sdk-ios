//
//  DMItemLocalCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 06/07/12.
//
//

#import "DMItemLocalCollection.h"

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
@property (nonatomic, readwrite, assign) NSInteger itemsCount;
@property (nonatomic, strong) NSMutableOrderedSet *privateItems;

@end


@implementation DMItemLocalCollection


- (id)initWithType:(NSString *)type withItemIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    self = [self initWithType:type api:api];
    if (self)
    {
        _privateItems = [NSMutableOrderedSet orderedSet];
        for (NSString *itemId in ids)
        {
            [_privateItems addObject:[DMItem itemWithType:type forId:itemId fromAPI:api]];
        }
        _countLimit = countLimit;
        self.currentEstimatedTotalItemsCount = self.itemsCount = [_privateItems count];
    }
    return self;
}

#pragma mark - Archiving

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        _privateItems = [[coder decodeObjectForKey:@"_items"] mutableCopy];
        _countLimit = [coder decodeIntegerForKey:@"countLimit"];
        self.currentEstimatedTotalItemsCount = self.itemsCount = [_privateItems count];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_privateItems forKey:@"_items"];
    [coder encodeInteger:_countLimit forKey:@"countLimit"];
}

- (NSOrderedSet *)items
{
    return [NSOrderedSet orderedSetWithOrderedSet:_privateItems];
}

#pragma mark - Implementation

- (DMItem *)itemWithId:(NSString *)itemId;
{
    for (DMItem *item in self.privateItems)
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
    if (index < [self.privateItems count])
    {
        return [(DMItem *)[self.privateItems objectAtIndex:index] withFields:fields do:callback];
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
        else if (index < [self.privateItems count])
        {
            callback([self.privateItems objectAtIndex:index], nil);
        }
        else
        {
            callback(nil, nil);
        }
    }];
}

- (DMItemOperation *)itemBeforeItem:(DMItem *)item withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    NSInteger idx = [self.privateItems indexOfObject:item];
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
    NSInteger idx = [self.privateItems indexOfObject:item];
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
        callback([self.privateItems containsObject:item], nil);
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
    if (![self.privateItems containsObject:item])
    {
        [self checkItem:item];
        [self.privateItems insertObject:item atIndex:0];
        if (self.countLimit != 0 && [self.privateItems count] > self.countLimit)
        {
            [self.privateItems removeObjectsInRange:NSMakeRange(self.countLimit, [self.privateItems count] - self.countLimit)];
        }
        self.currentEstimatedTotalItemsCount = self.itemsCount = [self.privateItems count];
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
    [self.privateItems removeObject:item];
    self.currentEstimatedTotalItemsCount = self.itemsCount = [self.privateItems count];

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback
{
    [self.privateItems removeObjectAtIndex:index];
    self.currentEstimatedTotalItemsCount = self.itemsCount = [self.privateItems count];

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

- (void)clear
{
    [self.privateItems removeAllObjects];
    self.currentEstimatedTotalItemsCount = self.itemsCount = [self.privateItems count];
}

- (BOOL)canReorder
{
    return YES;
}

- (DMItemOperation *)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex done:(void (^)(NSError *))callback
{
    [self.privateItems moveObjectsAtIndexes:[NSIndexSet indexSetWithIndex:fromIndex] toIndex:toIndex];
    self.currentEstimatedTotalItemsCount = self.itemsCount = [self.privateItems count]; // generate KVO notification to indicate the list changed

    dispatch_async(dispatch_get_current_queue(), ^
    {
        callback(nil);
    });
    return fakeOperation();
}

@end
