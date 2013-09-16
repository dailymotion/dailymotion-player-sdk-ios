//
//  DMQueryString.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//  Adapted from GMT
//

#import "DMQueryString.h"

@implementation NSString (DMQueryString)

- (NSString *)stringByURLEncoding
{
    // Encode all the reserved characters, per RFC 3986 (<http://www.ietf.org/rfc/rfc3986.txt>)
    return (__bridge_transfer NSString *)(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                  (__bridge CFStringRef)self,
                                                                                  NULL,
                                                                                  (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                  kCFStringEncodingUTF8));
}

- (NSString *)stringByURLDencoding
{
    NSString *resultString = [self stringByReplacingOccurrencesOfString:@"+"
                                                             withString:@" "
                                                                options:NSLiteralSearch
                                                                  range:NSMakeRange(0, self.length)];
    return [resultString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end

@implementation NSDictionary (DMURLArguments)

+ (NSDictionary *)dictionaryWithWithQueryString:(NSString *)queryString
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSArray *components = [queryString componentsSeparatedByString:@"&"];

    // Use reverse order so that the first occurrence of a key replaces those subsequent.
    for (NSString *component in [components reverseObjectEnumerator])
    {
        if ([component length] == 0)
        {
            continue;
        }
        NSRange pos = [component rangeOfString:@"="];
        NSString *key, *val;
        if (pos.location == NSNotFound)
        {
            key = [component stringByURLDencoding];
            val = @"";
        }
        else
        {
            key = [[component substringToIndex:pos.location] stringByURLDencoding];
            val = [[component substringFromIndex:pos.location + pos.length] stringByURLDencoding];
        }

        // stringByURLDencoding returns nil on invalid UTF8
        // and NSMutableDictionary raises an exception when passed nil values.
        if (!key) key = @"";
        if (!val) val = @"";

        params[key] = val;
    }

    return params;
}

- (NSString *)stringAsQueryString
{
    if ([self count] == 0)
    {
        return @"";
    }

    NSMutableArray* arguments = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop)
    {
        [arguments addObject:[NSString stringWithFormat:@"%@=%@",
                              [key stringByURLEncoding], [val.description stringByURLEncoding]]];
    }];

    return [[arguments sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"&"];
}

@end
