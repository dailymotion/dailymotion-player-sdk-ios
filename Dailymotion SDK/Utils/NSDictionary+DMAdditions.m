//
//  NSDictionary+DMAdditions.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "NSDictionary+DMAdditions.h"

static BOOL (^filterNull)(id key, id obj, BOOL *stop) = ^BOOL(id key, id obj, BOOL *stop)
{
    return ![obj isKindOfClass:[NSNull class]];
};

@implementation NSDictionary(DMAdditions)

- (NSDictionary *)dictionaryForKeys:(NSArray *)keys
{
    NSArray *values = [self objectsForKeys:keys notFoundMarker:[NSNull null]];
    return [NSDictionary dictionaryWithObjects:values forKeys:keys];
}

- (NSDictionary *)dictionaryByFilteringNullValues
{
    return [self dictionaryForKeys:[[self keysOfEntriesPassingTest:filterNull] allObjects]];
}

@end
