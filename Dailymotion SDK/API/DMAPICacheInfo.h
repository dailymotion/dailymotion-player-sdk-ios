//
//  DMAPICacheInfo.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import <Foundation/Foundation.h>

@interface DMAPICacheInfo : NSObject

@property (nonatomic, readonly) NSDate *date;
@property (nonatomic, readonly) NSString *namespace;
@property (nonatomic, readonly) NSArray *invalidates;
@property (nonatomic, readonly) NSString *etag;
@property (nonatomic, readonly) BOOL public;
@property (nonatomic, readonly) NSTimeInterval maxAge;
@property (nonatomic, assign) BOOL stalled;

- (id)initWithCacheInfo:(NSDictionary *)cacheInfo;

@end
