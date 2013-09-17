//
//  DMItemCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "DMItemCollection.h"
#import "DMItemRemoteCollection.h"
#import "DMItemLocalCollection.h"
#import "DMAPIArchiverDelegate.h"

@implementation NSString (Plural)

- (NSString *)stringByApplyingPluralForm
{
    if (self.length == 0) return self;
    if ([self characterAtIndex:self.length - 1] == 'y')
    {
        return [[self substringToIndex:self.length - 1] stringByAppendingString:@"ies"];
    }
    else
    {
        return [self stringByAppendingString:@"s"];
    }
}

@end


@interface DMItemCollection ()

@property (nonatomic, readwrite, copy) NSString *type;
@property (nonatomic, readwrite, strong) DMAPI *api;
@property (nonatomic, readwrite, assign) NSUInteger currentEstimatedTotalItemsCount;
@property (nonatomic, readwrite, assign) NSInteger itemsCount;
@property (nonatomic, readwrite, assign) BOOL isExplicit;

@end

@implementation DMItemCollection

#pragma mark - Initializers

+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit
{
    return [self itemLocalConnectionWithType:type countLimit:countLimit fromAPI:DMAPI.sharedAPI];
}

+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    return [[DMItemLocalCollection alloc] initWithType:type withItemIds:nil countLimit:(NSUInteger)countLimit fromAPI:api];
}

+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit
{
    return [self itemLocalConnectionWithType:type withIds:ids countLimit:countLimit fromAPI:DMAPI.sharedAPI];
}

+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    return [[DMItemLocalCollection alloc] initWithType:type withItemIds:ids countLimit:(NSUInteger)countLimit fromAPI:api];
}

+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params
{
    return [self itemCollectionWithType:type forParams:params fromAPI:DMAPI.sharedAPI];
}

+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api
{
    return [[DMItemRemoteCollection alloc] initWithType:type
                                                 params:params
                                                   path:[NSString stringWithFormat:@"/%@", [type stringByApplyingPluralForm]]
                                                fromAPI:api];
}

+ (id)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type forItem:(DMItem *)item
{
    return [self itemCollectionWithConnection:connection ofType:type forItem:item withParams:nil];
}

+ (id)itemCollectionWithConnection:(NSString *)connection ofType:(NSString *)type forItem:(DMItem *)item withParams:(NSDictionary *)params
{
    return [[DMItemRemoteCollection alloc] initWithType:type
                                                 params:params
                                                   path:[NSString stringWithFormat:@"/%@/%@/%@", item.type, item.itemId, connection]
                                                fromAPI:item.api];
}

+ (id)itemCollectionFromFile:(NSString *)filePath
{
    return [self itemCollectionFromFile:filePath withAPI:DMAPI.sharedAPI];
}

+ (id)itemCollectionFromFile:(NSString *)filePath withAPI:(DMAPI *)api
{
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    DMAPIArchiverDelegate *archiverDelegate = [[DMAPIArchiverDelegate alloc] initWithAPI:api];
    unarchiver.delegate = archiverDelegate;
    DMItemRemoteCollection *itemCollection = [unarchiver decodeObjectForKey:@"collection"];
    [unarchiver finishDecoding];
    return itemCollection;
}

- (id)initWithType:(NSString *)type api:(DMAPI *)api
{
    NSAssert(type != nil, @"The type cannot be nil");
    NSAssert(api != nil, @"The api cannot be nil");

    self = [super init];
    if (self)
    {
        _type = type;
        _api = api;
        _currentEstimatedTotalItemsCount = 0;
        _itemsCount = -1;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSString *type = [coder decodeObjectForKey:@"type"];
    DMAPI *api = [coder decodeObjectForKey:@"api"];

    self = [self initWithType:type api:api];
    if (self)
    {
        _currentEstimatedTotalItemsCount = [coder decodeIntegerForKey:@"currentEstimatedTotalItemsCount"];
        _itemsCount = [coder decodeIntegerForKey:@"itemsCount"];
        _isExplicit = [coder decodeBoolForKey:@"isExplicit"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_api forKey:@"api"];
    [coder encodeBool:_isExplicit forKey:@"isExplicit"];
    [coder encodeInteger:_currentEstimatedTotalItemsCount forKey:@"currentEstimatedTotalItemsCount"];
    [coder encodeInteger:_itemsCount forKey:@"itemsCount"];
}

- (BOOL)saveToFile:(NSString *)filePath
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    DMAPIArchiverDelegate *archiverDelegate = [[DMAPIArchiverDelegate alloc] initWithAPI:self.api];
    archiver.delegate = archiverDelegate;
    [archiver encodeObject:self forKey:@"collection"];
    [archiver finishEncoding];
    return [data writeToFile:filePath atomically:YES];
}

- (BOOL)isLocal
{
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)itemAtIndex:(NSUInteger)index withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)itemBeforeItem:(DMItem *)item withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)itemAfterItem:(DMItem *)item withFields:(NSArray *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)checkPresenceOfItem:(DMItem *)item do:(void (^)(BOOL, NSError *))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)flushCache
{
}

- (BOOL)canEdit
{
    return NO;
}

- (DMItemOperation *)createItemWithFields:(NSDictionary *)fields done:(void (^)(DMItem *item, NSError *error))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)addItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)removeItem:(DMItem *)item done:(void (^)(NSError *))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (BOOL)canReorder
{
    return NO;
}

- (DMItemOperation *)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex done:(void (^)(NSError *))callback
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (DMItem *)itemWithId:(NSString *)itemId
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
