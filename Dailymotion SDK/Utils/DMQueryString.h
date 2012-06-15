//
//  DMQueryString.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>

@interface NSString (DMQueryString)

- (NSString *)stringByURLEncoding;
- (NSString *)stringByURLDencoding;

@end

@interface NSDictionary (DMURLArguments)

- (NSString *)stringAsQueryString;

@end
