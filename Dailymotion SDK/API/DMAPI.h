//
//  DMAPI.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMOAuthClient.h"
#import "DMAPICallQueue.h"
#import "DMAPIError.h"
#import "DMAPICacheInfo.h"

#if TARGET_OS_IPHONE
#import "DMPlayerViewController.h"
#endif

@interface DMAPI : NSObject

@property (nonatomic) NSString *version;
@property (nonatomic, assign) NSTimeInterval timeout;

@property (nonatomic, copy) NSURL *APIBaseURL;

/**
 * Maximum number of allowed concurrent API calls. By default, this property is automatically
 * managed regarding current network type (Wifi > 3G/Edge). Changing this value manually will
 * disable the automatic management.
 */
@property (nonatomic, assign) NSUInteger maxConcurrency;

/**
 * Maximum number of call allowed to be batched in a single request. The hard API limit is 10
 * and default value is 10 as well.
 */
@property (nonatomic, assign) NSUInteger maxAggregatedCallCount;

/**
 * The DMOAuthRequest object responsible for API authentication. You may have to set a delegate
 * and call the `setGrantType:withAPIKey:secret:scope:` method on this object if you want to
 * make authenticated API request.
 *
 * @see DMOAuthRequest
 */
@property (nonatomic, strong) DMOAuthClient *oauth;

/**
 * Perform a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path callback:(DMAPICallResultBlock)callback;

/**
 * Perform a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)post:(NSString *)path callback:(DMAPICallResultBlock)callback;

/**
 * Perform a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)delete:(NSString *)path callback:(DMAPICallResultBlock)callback;

/**
 * Perform a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback;

/**
 * Perform a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback;

/**
 * Perform a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)delete:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback;

/**
 * Perform a conditional GET request to Dailymotion's API with the given method name and arguments.
 * If the provided cache info is still fresh, callback is called with no result and a new cache info object.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param cacheInfo The cache info used to perform the conditional request
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;

/**
 * Upload a file to Dailymotion and generate an URL to be used by API fields requiring a file URL like ``POST /me/videos`` ``url`` field.
 *
 * @param filePath The path to the file to upload
 * @param progress A block called at regular interval with upload progress information
 * @param callback A block taking the uploaded file URL string as first argument and an error as second argument
 */
- (DMAPICall *)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite))progress callback:(void (^)(NSString *url, NSError *error))callback;


/**
 * Create a DailymtionPlayer object initialized with the specified video ID.
 *
 * @param video The Dailymotion video ID that identifies the video that the player will load.
 * @param params A dictionary containing `player parameters <http://www.dailymotion.com/doc/api/player.html#player-params>`_
 *               that can be used to customize the player.
 */
#if TARGET_OS_IPHONE
- (DMPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params;
- (DMPlayerViewController *)player:(NSString *)video;
#endif

/**
 * Remove the right for the current API key to access the current user account.
 */
- (void)logout;

@end

@class DMItem;
@class DMItemCollection;

@interface DMAPI (Item)

/**
 * Get an instance of DMItem for a given object type/id
 *
 * @param type The item type name
 * @param objectId The item id
 *
 * @see DMItem
 */
- (DMItem *)itemWithType:(NSString *)type forId:(NSString *)itemId;

/**
 * Get an instance of DMItemCollection for a given type/params
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param params Parameters to filter or sort the result
 *
 * @see DMItemCollection
 */
- (DMItemCollection *)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params;

@end