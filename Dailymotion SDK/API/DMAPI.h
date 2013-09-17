//
//  DMAPI.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMOAuthClient.h"
#import "DMAPICallQueue.h"
#import "DMAPITransfer.h"
#import "DMAPIError.h"
#import "DMAPICacheInfo.h"
#import "DMReachability.h"

#if TARGET_OS_IPHONE
#import "DMPlayerViewController.h"
#endif

/**
 * Low level access to the API. This object can be used to perform direct API request. It is thus recommanded
 * to use higher level objects like DMItem and DMItemCollection or UIKit data sources like DMTableViewDataSource
 * and friends.
 *
 * DMAPI doesn't handle caching, use DMItem and DMItemCollection if you need caching.
 *
 * DMAPI will automatically aggregate calls to the API performed in the same run loop tic. It can aggregate up to
 * 10 calls in a single request. This is a huge performance boost, especially for mobile network on which the
 * allowed number of concurrent network connections is very very low. Although, it can lead to unwanted behavior
 * as response won't be return until all requests have been treated by the server.
 */
@interface DMAPI : NSObject

/**
 * Get the shared DM API instance for the current application.
 */
+ (DMAPI *)sharedAPI;

/** @name Properties */

/**
 * Dailymotion SDK Version
 */
@property (nonatomic) NSString *version;

@property (nonatomic, copy) NSURL *APIBaseURL;

/**
 * Report the current reachability of the API. You may use KVO to react to reachability changes.
 */
@property (nonatomic, readonly, assign) DMNetworkStatus currentReachabilityStatus;


/**
 * @name Global Settings
 */

/**
 * Global timeout interval for API requests
 */
@property (nonatomic, assign) NSTimeInterval timeout;

/**
 * Maximum number of allowed concurrent API calls. By default, this property is automatically
 * managed regarding current network type (Wifi > 3G/Edge). Changing this value manually will
 * disable the automatic management.
 */
@property (nonatomic, assign) NSUInteger maxConcurrency;

/**
 * The size of upload chunk size for resumable uploads. By default, this property is automatically
 * managed regarding current network type (Wifi > 3G/Edge). Changing this value manually will
 * disable the automatic management.
 */
@property (nonatomic, assign) NSUInteger uploadChunkSize;

/**
 * Maximum number of call allowed to be batched in a single request. The hard API limit is 10
 * and default value is 10 as well.
 */
@property (nonatomic, assign) NSUInteger maxAggregatedCallCount;

/**
 * @name Getting the Shared API Instance
 */

/**
 * @name Global Parameters
 */

/**
 * Set a parameter that will be sent with all API calls like for instance `localization` and
 * `family_filter` parameters.
 *
 * @param value The parameter value
 * @param name The parameter name
 */
- (void)setValue:(id)value forGlobalParameter:(NSString *)name;

/**
 * Remove the specified global parameter.
 *
 * @param name The parameter to remove
 */
- (void)removeGlobalParameter:(NSString *)name;

/**
 * Get the specified global parameter.
 *
 * @param name The parameter to get
 */
- (id)valueForGlobalParameter:(NSString *)name;

/**
 * @name Performing API Requests
 */

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
 * @param args An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback;

/**
 * Perform a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param args An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(DMAPICallResultBlock)callback;

/**
 * Perform a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param args An NSDictionnary with key-value pairs containing arguments
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
 * @param args An NSDictionnary with key-value pairs containing arguments
 * @param cacheInfo The cache info used to perform the conditional request
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;

/**
 * @name Uploading Files
 */

/**
 * Upload a file to Dailymotion and generate an URL to be used by API fields requiring a file URL like ``POST /me/videos`` ``url`` field.
 *
 * @param fileURL The URL path to the file to upload
 * @param completionHandler The block to be called once upload is complete
 */
- (DMAPITransfer *)uploadFileURL:(NSURL *)fileURL withCompletionHandler:(void (^)(id result, NSError *error))completionHandler;

/**
 * Resume an unfinished upload
 *
 * @param uploadOperation An unfinished upload operation returned by uploadFileURL:withCompletionHandler:
 * @param completionHandler The block to be called once upload is complete
 */
- (void)resumeFileUploadOperation:(DMAPITransfer *)uploadOperation withCompletionHandler:(void (^)(id result, NSError *error))completionHandler;

#if TARGET_OS_IPHONE
/**
 * @name Instanciating Player
 */

/**
 * Create a DailymtionPlayer object initialized with the specified video ID.
 *
 * @param video The Dailymotion video ID that identifies the video that the player will load.
 * @param params A dictionary containing `player parameters <http://www.dailymotion.com/doc/api/player.html#player-params>`_
 *               that can be used to customize the player.
 */
- (DMPlayerViewController *)playerWithVideo:(NSString *)video params:(NSDictionary *)params;
- (DMPlayerViewController *)playerWithVideo:(NSString *)video;
- (DMPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params __attribute__((deprecated));
- (DMPlayerViewController *)player:(NSString *)video __attribute__((deprecated));
#endif

/**
 * @name Authentication
 */

/**
 * The DMOAuthClient object responsible for API authentication. You may have to set a delegate
 * and call the `setGrantType:withAPIKey:secret:scope:` method on this object if you want to
 * make authenticated API request.
 *
 * @see DMOAuthClient
 */
@property (nonatomic, strong) DMOAuthClient *oauth;

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
 * @param itemId The item id
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