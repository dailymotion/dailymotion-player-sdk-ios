//
//  DMItemCollection.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "DMItemCollection.h"
#import "DMAPI.h"
#import "DMQueryString.h"

static NSCache *itemCollectionInstancesCache;

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
@property (nonatomic, readwrite, copy) NSDictionary *params;
@property (nonatomic, readwrite, strong) DMAPICacheInfo *cacheInfo;
@property (nonatomic, strong) DMAPI *_api;
@property (nonatomic, strong) NSString *_path;

@end


@implementation DMItemCollection

+ (void)initialize
{
    itemCollectionInstancesCache = [[NSCache alloc] init];
    itemCollectionInstancesCache.countLimit = 10;
}

+ (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", type, [params stringAsQueryString]];
    DMItemCollection *itemCollection = [itemCollectionInstancesCache objectForKey:cacheKey];
    if (!itemCollection)
    {
        itemCollection = [[self alloc] init];
        itemCollection.type = type;
        itemCollection.params = params;
        itemCollection._api = api;
        itemCollection._path = [NSString stringWithFormat:@"/%@", [type stringByApplyingPluralForm]];
    }

    return itemCollection;
}

+ (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;
{
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@:%@:%@", item.type, item.itemId, connection, [params stringAsQueryString]];
    DMItemCollection *itemCollection = [itemCollectionInstancesCache objectForKey:cacheKey];
    if (!itemCollection)
    {
        itemCollection = [[self alloc] init];
        itemCollection.type = item.type;
        itemCollection.params = params;
        itemCollection._api = api;
        itemCollection._path = [NSString stringWithFormat:@"/%@/%@/%@", item.type, item.itemId, connection];
    }

    return itemCollection;
}

- (void)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL stalled, NSError *error))callback
{
    [self._api get:self._path args:self.params cacheInfo:nil callback:^(NSDictionary *result, DMAPICacheInfo *cacheInfo, NSError *error)
    {

    }];
}

@end
