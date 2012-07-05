//
//  DMAPICacheInfo.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 14/06/12.
//
//

#import <Foundation/Foundation.h>

@class DMAPI;

@interface DMAPICacheInfo : NSObject <NSCoding>

/**
 * The date when the cache info as been issued
 */
@property (nonatomic, readonly) NSDate *date;

/**
 * The cache namespace used for invalidation
 */
@property (nonatomic, readonly) NSString *namespace;

/**
 * The optinal namespaces invalidated by this cache entry
 */
@property (nonatomic, readonly) NSArray *invalidates;

/**
 * The entity tag for the returned object that may be used to perform conditional API requests
 */
@property (nonatomic, readonly) NSString *etag;

/**
 * Tell if the entity is public or private. Private entries must be removed from the cache
 * when API session change
 */
@property (nonatomic, readonly) BOOL public;

/**
 * The maximum age of the cached data before it become stalled
 */
@property (nonatomic, readonly) NSTimeInterval maxAge;

/**
 * Tells if the cached data is currently stalled
 *
 * This parameter is by default dynamic but can be forced to YES by setting it. Setting
 * the parameter to NO won't force the value but reset the automatic handling of this property.
 */
@property (nonatomic, assign) BOOL stalled;


/**
 * Tells if the cache data can still be used or if its contain should be dropped immediately and
 * refreshed from network.
 */
@property (nonatomic, assign) BOOL valid;

/**
 * Instanciate a new cache info object with data comming from API
 */
- (id)initWithCacheInfo:(NSDictionary *)cacheInfo fromAPI:(DMAPI *)api;

@end
