//
//  NSDictionary+DMAdditions.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "NSDictionary+DMAdditions.h"

static NSString *const DMNotFound = @"DMKeyNotFound";
static BOOL (^filterNull)(id key, id obj, BOOL *stop) = ^BOOL(id key, id obj, BOOL *stop)
{
    return ![obj isKindOfClass:[NSNull class]];
};

@implementation NSDictionary(DMAdditions)

- (NSDictionary *)dictionaryForKeys:(NSArray *)keys
{
    NSArray *values = [self objectsForKeys:keys notFoundMarker:DMNotFound];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:values forKeys:keys];
    [dict removeObjectsForKeys:[dict allKeysForObject:DMNotFound]];
    return dict;
}

- (NSArray *)allMissingKeysForKeys:(NSArray *)keys
{
    NSArray *values = [self objectsForKeys:keys notFoundMarker:DMNotFound];
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    return [dict allKeysForObject:DMNotFound];
}

- (NSArray *)objectsForExistingKeys:(NSArray *)keys
{
    NSMutableArray *objects = [[self objectsForKeys:keys notFoundMarker:DMNotFound] mutableCopy];
    [objects removeObject:DMNotFound];
    return objects;
}

@end
