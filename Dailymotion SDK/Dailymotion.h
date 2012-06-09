//
//  Dailymotion.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 11/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMOAuthSession.h"

#if TARGET_OS_IPHONE
#import "DailymotionPlayerViewController.h"
#endif

@class Dailymotion;

@protocol DailymotionDelegate <NSObject>

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
 * The delegate have to ask the user for her credentials and need to call back the ``handler` method in order for
 * the pending API calls to be completed.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypePassword``.
 */
- (void)dailymotionDidRequestUserCredentials:(Dailymotion *)dailymotion handler:(void (^)(NSString *username, NSString *password))setCredentials;


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

extern NSString * const DailymotionTransportErrorDomain;
extern NSString * const DailymotionAuthErrorDomain;
extern NSString * const DailymotionApiErrorDomain;

#if TARGET_OS_IPHONE
#define PLATFORM_DELEGATES <UIWebViewDelegate>
#else
#define PLATFORM_DELEGATES
#import <WebKit/WebKit.h>
#endif

@interface Dailymotion : NSObject PLATFORM_DELEGATES

@property (nonatomic) NSString *version;
@property (nonatomic, assign) NSTimeInterval timeout;

@property (nonatomic, copy) NSURL *APIBaseURL;

/**
 * Make a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)get:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)post:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)delete:(NSString *)path callback:(void (^)(id, NSError*))callback;

/**
 * Make a GET request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)get:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Make a POST request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)post:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Make a DELETE request to Dailymotion's API with the given method name and arguments.
 *
 * See `Dailymotion API reference <http://www.dailymotion.com/doc/api/reference.html>`_
 *
 * @param path An API resource
 * @param arguments An NSDictionnary with key-value pairs containing arguments
 * @param callback A block taking the response as first argument and an error as second argument
 */
- (void)delete:(NSString *)path args:(NSDictionary *)args callback:(void (^)(id, NSError*))callback;

/**
 * Upload a file to Dailymotion and generate an URL to be used by API fields requiring a file URL like ``POST /me/videos`` ``url`` field.
 *
 * @param filePath The path to the file to upload
 * @param callback A block taking the uploaded file URL string as first argument and an error as second argument
 */
- (void)uploadFile:(NSString *)filePath callback:(void (^)(NSString *url, NSError *error))callback;


/**
 * Create a DailymtionPlayer object initialized with the specified video ID.
 *
 * @param video The Dailymotion video ID that identifies the video that the player will load.
 * @param params A dictionary containing `player parameters <http://www.dailymotion.com/doc/api/player.html#player-params>`_
 *               that can be used to customize the player.
 */
#if TARGET_OS_IPHONE
- (DailymotionPlayerViewController *)player:(NSString *)video params:(NSDictionary *)params;
- (DailymotionPlayerViewController *)player:(NSString *)video;
#endif


@property (nonatomic, copy) NSURL *oAuthAuthorizationEndpointURL;
@property (nonatomic, copy) NSURL *oAuthTokenEndpointURL;

/**
 * Set the delegate that conforms to the ``DailymotionDelegate`` protocol.
 */
@property (nonatomic, unsafe_unretained) id<DailymotionDelegate> delegate;

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
@property (nonatomic) DMOAuthSession *session;

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
 * Get the grantType currently in use for API requests
 */
@property (nonatomic, readonly) DailymotionGrantType grantType;

/**
 * Remove the right for the current API key to access the current user account.
 */
- (void)logout;

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
- (DMOAuthSession *)readSession;

@end
