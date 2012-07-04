//
//  DMAdditions.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import "DMAdditions.h"
#import "DMSubscriptingSupport.h"

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


@implementation NSArray(DMAdditions)

- (NSArray *)objectsInRange:(NSRange)range notFoundMarker:(id)marker
{
    NSUInteger i;
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:range.length];
    NSUInteger count = [self count];
    NSUInteger maxIndex = count - 1;
    NSUInteger endIndex = MIN(range.location + range.length - 1, maxIndex);

    for (i = 0; i < range.length; i++)
    {
        [objects addObject:marker];
    }

    if (range.length == 0 || count == 0 || range.location > maxIndex)
    {
        return objects;
    }

    for (i = range.location; i <= endIndex; i++)
    {
        objects[i - range.location] = self[i];
    }

    return objects;
}

@end

@implementation NSMutableArray (DMAdditions)

- (void)raise:(NSUInteger)newSize withObject:(id)filler
{
    if ([self count] < newSize)
    {
        for (NSUInteger i = [self count]; i < newSize; i++)
        {
            [self addObject:filler];
        }
    }
}

- (void)shrink:(NSUInteger)newSize
{
    if (newSize >= [self count]) return;
    [self removeObjectsInRange:NSMakeRange(newSize, [self count] - newSize)];
}

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)objects fillWithObject:(id)filler
{
    [self raise:range.location + range.length withObject:filler];
    [self replaceObjectsInRange:range withObjectsFromArray:objects];
}

@end