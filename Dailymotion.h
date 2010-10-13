//
//  Dailymotion.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
    #import <CFNetwork/CFNetwork.h>
#endif

@class Dailymotion;

@protocol DailymotionDelegate <NSObject>

@optional

/**
 * Called when an API request returned a successful response.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param result The result of the method call returned by the API. It may be a ``NSDictionnary`` or an
 *               ``NSArray`` of ``NSDictionnary``s depending on the format of the API response.
 * @param userInfo The dictionnary provided to the ``callMethod:withArguments:delegate:userInfo:`` method.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didReturnResult:(id)result userInfo:(NSDictionary *)userInfo;

/**
 * Called when an API request return an error response.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param error The error returned by the server. NSError domaines can be one of:
 *              - DailymotionTransportErrorDomain: when the error is at transport level (network error, server error, protocol error)
 *              - DailymotionAuthErrorDomain: when the error is at the OAuth level (invalid key, unsufficient permission, etc.)
 *              - DailymotionApiErrorDomain: the the error is at the API level (see `API reference for more info
 *                <http://www.dailymotion.com/doc/api/advanced-api-reference.html>`_)
 * @param userInfo The dictionnary provided to the ``callMethod:withArguments:delegate:userInfo:`` method.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didReturnError:(NSError *)error userInfo:(NSDictionary *)userInfo;

/**
 * Called when a method call resulted in a ``403`` error. This can happen when a method requesting an authentication has
 * been call with no authentication or if the authorization doesn't have sufficient scope or if the used API key is
 * missing a required role.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param message The message comming from the server asking for authentication
 * @param userInfo The dictionnary provided to the ``callMethod:withArguments:delegate:userInfo:`` method.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didRequestAuthWithMessage:(NSString *)message userInfo:(NSDictionary *)userInfo;

/**
 * Called at regular interval while uploading a file in order to let you inform end user on the progress of the upload.
 *
 * The value of totalBytesExpectedToWrite may change during the upload if the request needs to be retransmitted
 * due to a lost connection or an authentication challenge from the server.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param bytesWritten The number of bytes written in the latest write.
 * @param totalBytesWritten The total number of bytes written for this connection.
 * @param totalBytesExpectedToWrite The number of bytes the connection expects to write.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didSendFileData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite;

/**
 * This delegate method is called upon successful file upload using the ``uploadFile:delegate:`` method.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param URL The URL returned by the upload server. You can use this URL as argument for methods asking for an URL like
 *            ``video.create`` for instance.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didUploadFileAtURL:(NSString *)URL;

@end

typedef enum
{
    DailymotionNoGrant,
    DailymotionGrantTypeToken,
    DailymotionGrantTypeNone,
    DailymotionGrantTypePassword
} DailymotionGrantType;

typedef enum
{
    DailymotionStateNone,
    DailymotionStateOAuthRequest,
    DailymotionStateAPIRequest
} DailymotionState;

extern NSString * const DailymotionTransportErrorDomain;
extern NSString * const DailymotionAuthErrorDomain;
extern NSString * const DailymotionApiErrorDomain;

@interface Dailymotion : NSObject <DailymotionDelegate>
{
    @private
    DailymotionState currentState;
    DailymotionGrantType grantType;
    NSDictionary *grantInfo;
    NSTimeInterval timeout;
    NSURLConnection *apiConnection, *uploadConnection;
    NSHTTPURLResponse *uploadResponse, *apiResponse;
    NSMutableData *uploadResponseData, *apiResponseData;
    NSMutableDictionary *callQueue;
    NSMutableArray *uploadFileQueue;
    NSDictionary *session;
    NSUInteger callNextId;
}

@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, readonly) NSString *version;

/**
 * Set the grant type to be used for API requests.
 *
 * To create an API key/secret pair, go to: http://www.dailymotion.com/profile/developer
 *
 * @param grantType Can be one of ``DailymotionGrantTypeToken``, ``DailymotionGrantTypeNone`` or ``DailymotionGrantTypePassword```.
 * @param apiKey The API key
 * @param apiSecret The API secret
 * @param scope The permission scope requested (can be none of any of ``read``, ``write`` or ``delete``).
 *              To specify several scope, separate them with whitespaces.
 * @param info info associated to the chosen grant type
 *
 * Info Keys:
 * - ``username``: if ``grantType`` is ``DailymotionGrantTypePassword``, this argument are required.
 * - ``password``: if ``grantType`` is ``DailymotionGrantTypePassword``, this argument are required.
 */
- (void)setGrantType:(DailymotionGrantType)grantType withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope info:(NSDictionary *)info;
- (void)setGrantType:(DailymotionGrantType)grantType withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope;

/**
 * Make a request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/advanced-api-reference.html>`_
 *
 * @param methodName A valid method name
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param delegate An object implementing ``DailymotionDelegate`` protocol for notifying the calling application
 *                 when the request has received response
 * @param userInfo A dictionary containing user-defined information which will be passed back with each delegate methods
 */
- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo;
- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate;


/**
 * Upload a file to Dailymotion and generate an URL to be used by methods requiring a file URL like ``video.create``
 * for instance.
 *
 * @param filePath The path to the file to upload
 */
- (void)uploadFile:(NSString *)filePath delegate:(id<DailymotionDelegate>)delegate;

@end
