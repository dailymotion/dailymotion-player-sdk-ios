//
//  DMQueryString.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>

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

@interface NSDictionary (DMURLArguments)

/**
 * Return the receiver serialized as a query string
 */
- (NSString *)stringAsQueryString;

@end
