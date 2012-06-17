//
//  DMItemCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItem.h"

@class DMAPI;

@interface DMItemCollection : NSObject

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, copy) NSDictionary *params;
@property (nonatomic, readonly, strong) DMAPICacheInfo *cacheInfo;

+ (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

+ (DMItemCollection *)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

- (void)itemsWithFields:(NSArray *)fields forPage:(NSUInteger)page withPageSize:(NSUInteger)itemsPerPage do:(void (^)(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error))callback;

/**
 * Flush all previously loaded cache for this collection (won't flush items cache data)
 */
- (void)flushCache;

@end
