//
//  DMAPI.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMOAuthRequest.h"
#import "DMAPICallQueue.h"
#import "DMAPIError.h"

#if TARGET_OS_IPHONE
#import "DMPlayerViewController.h"
#endif

@interface DMAPI : NSObject

@property (nonatomic) NSString *version;
@property (nonatomic, assign) NSTimeInterval timeout;

@property (nonatomic, copy) NSURL *APIBaseURL;

/**
 * The DMOAuthRequest object responsible for API authentication. You may have to set a delegate
 * and call the `setGrantType:withAPIKey:secret:scope:` method on this object if you want to
 * make authenticated API request.
 *
 * @see DMOAuthRequest
 */
@property (nonatomic, strong) DMOAuthRequest *oauth;

/**
 * Make a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)post:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)delete:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)get:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Make a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)post:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Make a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (DMAPICall *)delete:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Upload a file to Dailymotion and generate an URL to be used by API fields requiring a file URL like ``POST /me/videos`` ``url`` field.
 *
 * @param filePath The path to the file to upload
 * @param progress A block called at regular interval with upload progress information
 * @param callback A block taking the uploaded file URL string as first argument and an error as second argument
 */
- (DMAPICall *)uploadFile:(NSString *)filePath progress:(void (^)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite))progress callback:(void (^)(NSString *, NSError*))callback;


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