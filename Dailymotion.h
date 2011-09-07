//
//  Dailymotion.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

@class Dailymotion;

@protocol DailymotionDelegate <NSObject>

@optional

/**
 * Called when an API request returned a successful response.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param result The result returned by the API. It may be a ``NSDictionnary`` or an
 *               ``NSArray`` of ``NSDictionnary``s depending on the format of the API response.
 * @param userInfo The dictionnary provided to the ``request:withArguments:delegate:userInfo:`` method.
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
 *                <http://www.dailymotion.com/doc/api/reference.html>`_)
 * @param userInfo The dictionnary provided to the ``request:withArguments:delegate:userInfo:`` method.
 */
- (void)dailymotion:(Dailymotion *)dailymotion didReturnError:(NSError *)error userInfo:(NSDictionary *)userInfo;

/**
 * Called when an API request call resulted in a ``403`` error. This can happen when an API request requiring an authentication has
 * been call with no previous authentication or if the authorization doesn't have sufficient scope or if the used API key is
 * missing a requires role.
 *
 * @param dailymotion The dailymotion instance sending the message.
 * @param message The message comming from the server asking for authentication
 * @param userInfo The dictionnary provided to the ``request:withArguments:delegate:userInfo:`` method.
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

@protocol DailymotionUIDelegate <NSObject>

@optional

/**
 * This delegate method is called when the Dailymotion SDK needs to show a modal dialog window to the user in order to
 * ask for end-user permission to connect your application with his account. You may implement this method only if you
 * choose ``DailymotionGrantTypeAuthorization`` grant type. In response to this delegate, your application have to present the
 * given view to the end-user.
 *
 * The default implementation of this delegate method is to create a new window with the content of the view.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypeAuthorization``.
 */
#if TARGET_OS_IPHONE
- (void)dailymotion:(Dailymotion *)dailymotion createModalDialogWithView:(UIView *)view;
#else
- (void)dailymotion:(Dailymotion *)dailymotion createModalDialogWithView:(NSView *)view;
#endif

/**
 * This delegate method is called when the Dailymotion SDK authorization process is finished and instruct the reciever
 * to close the previousely created modal dialog.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypeAuthorization``.
 */
- (void)dailymotionCloseModalDialog:(Dailymotion *)dailymotion;

/**
 * Called when the grant method is ``DailymotionGrantTypePassword`` and the credentials are requested by the library.
 * The delegate have to ask the user for her credentials and need to call ``setUsername:password:`` method in order for
 * the pending API calls to be performed.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypePassword``.
 */
- (void)dailymotionDidRequestUserCredentials:(Dailymotion *)dailymotion;


/**
 * When a link is clicked in the authorization dialog, like for instance to create an account or recover a lost password,
 * the Dailymotion SDK asks the UI delegate if the link should be openned in an external browser or if the UI delegate
 * want to handle the openned link by itself.
 */
- (BOOL)dailymotion:(Dailymotion *)dailymotion shouldOpenURLInExternalBrowser:(NSURL *)url;

@end

typedef enum
{
    DailymotionNoGrant,
    DailymotionGrantTypeAuthorization,
    DailymotionGrantTypeClientCredentials,
    DailymotionGrantTypePassword
} DailymotionGrantType;

typedef enum
{
    DailymotionConnectionStateNone,
    DailymotionConnectionStateOAuthRequest,
    DailymotionConnectionStateAPIRequest
} DailymotionConnectionState;

extern NSString * const DailymotionTransportErrorDomain;
extern NSString * const DailymotionAuthErrorDomain;
extern NSString * const DailymotionApiErrorDomain;

#if TARGET_OS_IPHONE
#define PLATFORM_DELEGATES , UIWebViewDelegate
#else
#define PLATFORM_DELEGATES
#import <WebKit/WebKit.h>
#endif

@interface Dailymotion : NSObject <DailymotionDelegate PLATFORM_DELEGATES>
{
    @private
    DailymotionConnectionState apiConnectionState;
    DailymotionGrantType grantType;
    NSDictionary *grantInfo;
    NSTimeInterval timeout;
    NSURLConnection *apiConnection, *uploadConnection;
    NSHTTPURLResponse *uploadResponse, *apiResponse;
    NSMutableData *uploadResponseData, *apiResponseData;
    NSMutableDictionary *callQueue;
    NSMutableArray *uploadFileQueue;
    NSDictionary *session;
    BOOL autoSaveSession, sessionLoaded;
    NSUInteger callNextId;
    id<DailymotionUIDelegate> UIDelegate;
}

@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, readonly) NSString *version;

/**
 * Set the user interface delegate that conforms to the ``DailymotionUIDelegate`` protocol.
 */
@property (nonatomic, assign) id<DailymotionUIDelegate> UIDelegate;

/**
 * This propoerty contains an OAuth 2.0 valid session to be used to access the API or request an access token. This session
 * is normaly autmoatically generated using the provided API key/secret. Although, you can manualy set it if you got,
 * for instance, an ``access_token`` from another source like your own backend.
 *
 * A session is an NSDictionary which can contain any of the following keys:
 * - ``access_token``: a token which can be used to access the API
 * - ``expires``: an ``NSDate`` which indicates until when the ``access_token`` remains valid
 * - ``refresh_token``: a token used to request a new valid ``access_token`` without having to ask the end-user again and again
 * - ``scope``: an indication on the permission scope granted by the end-user for this session
 */
@property (nonatomic, retain) NSDictionary *session;

/**
 * If this property is set to ``NO``, the session won't be stored automatically for latter use. When not stored, your
 * application will have to ask end-user to authorize your API key each time you restart your application.
 * By default this property is set to ``YES``.
 */
@property (nonatomic, assign) BOOL autoSaveSession;

/**
 * Set the grant type to be used for API requests.
 *
 * To create an API key/secret pair, go to: http://www.dailymotion.com/profile/developer
 *
 * @param grantType Can be one of ``DailymotionGrantTypeAuthorization``, ``DailymotionGrantTypeClientCredentials`` or ``DailymotionGrantTypePassword```.
 * @param apiKey The API key
 * @param apiSecret The API secret
 * @param scope The permission scope requested (can be none of any of ``read``, ``write`` or ``delete``).
 *              To specify several scope, separate them with whitespaces.
 */
- (void)setGrantType:(DailymotionGrantType)grantType withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope;

/**
 * Call this method when the API asked for credentials thru the ``dailymotionDidRequestUserCredentials:`` UIDelegate
 * method. DO NOT call this method BEFORE the API asked for it as it won't work.
 */
- (void)setUsername:(NSString *)username password:(NSString *)password;

/**
 * Remove the right for the current API key to access the current user account.
 */
- (void)logout;

/**
 * Make a request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API URI path
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param delegate An object implementing ``DailymotionDelegate`` protocol for notifying the calling application
 *                 when the request has received response
 * @param userInfo A dictionary containing user-defined information which will be passed back with each delegate methods
 */
- (void)request:(NSString *)path delegate:(id<DailymotionDelegate>)delegate;
- (void)request:(NSString *)path delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo;
- (void)request:(NSString *)path withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate;
- (void)request:(NSString *)path withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo;

/**
 * @deprecated
 */
- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate userInfo:(NSDictionary *)userInfo __attribute__ ((deprecated));
- (void)callMethod:(NSString *)methodName withArguments:(NSDictionary *)arguments delegate:(id<DailymotionDelegate>)delegate __attribute__ ((deprecated));

/**
 * Upload a file to Dailymotion and generate an URL to be used by API fields requiring a file URL like ``POST /me/videos`` ``url`` field.
 *
 * @param filePath The path to the file to upload
 */
- (void)uploadFile:(NSString *)filePath delegate:(id<DailymotionDelegate>)delegate;

/**
 * Clears the session for the current grant type.
 */
- (void)clearSession;

/**
 * Returns the key used to store the session. If this method returns nil, the session won't be stored.
 */
- (NSString *)sessionStoreKey;

/**
 * Store the current session on a local store for future use. By default, the session is stored in the NSUserDefaults.
 *
 * This method can be overloaded to handle different type of storage.
 */
- (void)storeSession;

/**
 * Read a previousely stored session from the local store.
 *
 * This method can be overloaded to handle different type of storage.
 */
- (NSDictionary *)readSession;

@end
