//
//  DMQueryString.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>

/**
 * NSString category to handle URL query-string serialization
 */
@interface NSString (DMQueryString)

/**
 * Returns an URL encoded version of the receiver
 */
- (NSString *)stringByURLEncoding;

/**
 * Returns an URL decoded version of the receiver
 */
- (NSString *)stringByURLDencoding;

@end

/**
 * NSDictionary category to handle URL query-string serialization
 */
@interface NSDictionary (DMURLArguments)

/**
 * Generate a dictionary from a query string
 */
+ (NSDictionary *)dictionaryWithWithQueryString:(NSString *)queryString;

/**
 * Return the receiver serialized as a query string
 */
- (NSString *)stringAsQueryString;

@end
