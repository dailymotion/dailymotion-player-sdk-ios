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

@end

@implementation DMItemCollection

#pragma mark - Initializers

+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    return [[DMItemLocalCollection alloc] initWithType:type withItemIds:nil countLimit:(NSUInteger)countLimit fromAPI:api];
}

+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api
{
    return [[DMItemLocalCollection alloc] initWithType:type withItemIds:ids countLimit:(NSUInteger)countLimit fromAPI:api];
}

+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api
{
    return [[DMItemRemoteCollection alloc] initWithType:type
                                                 params:params
                                                   path:[NSString stringWithFormat:@"/%@", [type stringByApplyingPluralForm]]
                                                fromAPI:api];
}

+ (id)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;
{
    return [[DMItemRemoteCollection alloc] initWithType:item.type
                                                 params:params
                                                   path:[NSString stringWithFormat:@"/%@/%@/%@", item.type, item.itemId, connection]
                                                fromAPI:api];
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

    if ((self = [super init]))
    {
        _type = type;
        _api = api;
        _currentEstimatedTotalItemsCount = 0;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSString *type = [coder decodeObjectForKey:@"type"];
    DMAPI *api = [coder decodeObjectForKey:@"api"];

    if ((self = [self initWithType:type api:api]))
    {
        _currentEstimatedTotalItemsCount = [coder decodeIntegerForKey:@"currentEstimatedTotalItemsCount"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_api forKey:@"api"];
    [coder encodeInteger:_currentEstimatedTotalItemsCount forKey:@"currentEstimatedTotalItemsCount"];
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

- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback
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

@end
