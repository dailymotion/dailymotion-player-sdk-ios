//
//  DMOAuthClient.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DMOAuthSession.h"
#import "DMNetworking.h"
#import "DMOAuthRequestOperation.h"

#define kDMOAuthRedirectURI @"none://fake-callback"

#if TARGET_OS_IPHONE
#define PLATFORM_DELEGATES <UIWebViewDelegate>
#else
#define PLATFORM_DELEGATES
#import <WebKit/WebKit.h>
#endif

/**
 * Test
 */
typedef enum
{
    /**
     * Use this grant type to access the API anonymously.
     */
    DailymotionNoGrant,

    /**
     * Use this grant type if must want to access the API on the behalf of a user. A UIWebView under iOS or
     * a WebView on Mac OS X will be opened with an authorization request page presented to the end-user.
     * You need to implement the DailymotionOAuthDelegate protocol to use this grant type.
     */
    DailymotionGrantTypeAuthorization,

    /**
     * Use this grant type if you don't need to access the API on behalf of a user but still need to
     * authenticate with your API key (i.e.: you API key has special rights).
     */
    DailymotionGrantTypeClientCredentials,

    /**
     * If the token grant type doesn’t suits your application workflow, you can request end-user
     * credentials and use the password grant type to authenticate requests. Note that you MUST NOT
     * store end-user credentials.
     */
    DailymotionGrantTypePassword
} DailymotionGrantType;

@protocol DailymotionOAuthDelegate;

/**
 * A wrapper for DMNetworking to perform OAuth 2.0 requests.
 */
@interface DMOAuthClient : NSObject PLATFORM_DELEGATES

@property (nonatomic, copy) NSURL *oAuthAuthorizationEndpointURL;
@property (nonatomic, copy) NSURL *oAuthTokenEndpointURL;
@property (nonatomic, strong) DMNetworking *networkQueue;

/**
 * Set the delegate that conforms to the `DailymotionDelegate` protocol.
 */
@property (nonatomic, weak) id<DailymotionOAuthDelegate> delegate;

/**
 * This propoerty contains an OAuth 2.0 valid session to be used to access the API or request an access token. This session
 * is normaly autmoatically generated using the provided API key/secret. Although, you can manualy set it if you got,
 * for instance, an `access_token` from another source like your own backend.
 *
 * A session is an NSDictionary which can contain any of the following keys:
 * - `access_token`: a token which can be used to access the API
 * - `expires`: an `NSDate` which indicates until when the `access_token` remains valid
 * - `refresh_token`: a token used to request a new valid `access_token` without having to ask the end-user again and again
 * - `scope`: an indication on the permission scope granted by the end-user for this session
 */
@property (nonatomic) DMOAuthSession *session;

/**
 * If this property is set to `NO`, the session won't be stored automatically for latter use. When not stored, your
 * application will have to ask end-user to authorize your API key each time you restart your application.
 * By default this property is set to `YES`.
 */
@property (nonatomic, assign) BOOL autoSaveSession;

/**
 * Perform a request with oauth authentication
 *
 * @param URL The URL to send request for.
 * @param method The HTTP method to use for the request.
 * @param payload The payload for POST or PUT HTTP method. @see DMNetworking for the list of supported types.
 * @param headers A dictionary with some custom headers to add.
 * @param cachePolicy The cache policy for the request.
 * @param handler The block to be called with the response.
 */
- (DMOAuthRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

/**
 * Set the grant type to be used for API requests.
 *
 * To create an API key/secret pair, go to: http://www.dailymotion.com/profile/developer
 *
 * Supported grant types are:
 * 
 * - `DailymotionNoGrant`: Use this grant type to access the API anonymously.
 * - `DailymotionGrantTypeAuthorization`: Use this grant type if must want to access the API on the behalf of a user.
 *   A UIWebView under iOS or a WebView on Mac OS X will be opened with an authorization request page presented to the end-user.
 *   You need to implement the DailymotionOAuthDelegate protocol to use this grant type.
 * - `DailymotionGrantTypeClientCredentials`: Use this grant type if you don't need to access the API on behalf of a user but still need to
 *   authenticate with your API key (i.e.: you API key has special rights).
 * - `DailymotionGrantTypePassword`: If the token grant type doesn’t suits your application workflow, you can request end-user
 *   credentials and use the password grant type to authenticate requests. Note that you MUST NOT
 *   store end-user credentials.
 *
 * @param grantType Can be one of `DailymotionNoGrant`, `DailymotionGrantTypeAuthorization`, `DailymotionGrantTypeClientCredentials` or `DailymotionGrantTypePassword`.
 * @param apiKey The API key
 * @param apiSecret The API secret
 * @param scope The permission scope requested (can be none of any of `read`, `write` or `delete`).
 *              To specify several scope, separate them with whitespaces.
 */
- (void)setGrantType:(DailymotionGrantType)grantType withAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret scope:(NSString *)scope;

/**
 * Get the grantType currently in use for API requests
 */
@property (nonatomic, readonly) DailymotionGrantType grantType;

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

/**
 * Delegate protocol used to request end-user input when necessary.
 */
@protocol DailymotionOAuthDelegate <NSObject>

@optional

/**
 * This delegate method is called when the Dailymotion SDK needs to show a modal dialog window to the user in order to
 * ask for end-user permission to connect your application with his account. You may implement this method only if you
 * choose `DailymotionGrantTypeAuthorization` grant type. In response to this delegate, your application have to present the
 * given view to the end-user.
 *
 * The default implementation of this delegate method is to create a new window with the content of the view.
 *
 * You MUST implement this delegate method if you set the grant type to `DailymotionGrantTypeAuthorization`.
 *
 * @param client The DMOAuthClient sending this message.
 * @param view The view to display to the end user.
 */
#if TARGET_OS_IPHONE
- (void)dailymotionOAuthRequest:(DMOAuthClient *)client createModalDialogWithView:(UIView *)view;
#else
- (void)dailymotionOAuthRequest:(DMOAuthClient *)client createModalDialogWithView:(NSView *)view;
#endif

/**
 * This delegate method is called when the Dailymotion SDK authorization process is finished and instruct the reciever
 * to close the previousely created modal dialog.
 *
 * You MUST implement this delegate method if you set the grant type to `DailymotionGrantTypeAuthorization`.
 *
 * @param client The DMOAuthClient sending this message
 */
- (void)dailymotionOAuthRequestCloseModalDialog:(DMOAuthClient *)client;

/**
 * Called when the grant method is `DailymotionGrantTypePassword` and the credentials are requested by the library.
 * The delegate have to ask the user for her credentials and need to call back the `handler` method in order for
 * the pending API calls to be completed.
 *
 * You MUST implement this delegate method if you set the grant type to `DailymotionGrantTypePassword`.
 *
 * @param client The DMOAuthClient requesting this information.
 * @param setCredentials The block to call back with the obtained username and password.
 */
- (void)dailymotionOAuthRequest:(DMOAuthClient *)client didRequestUserCredentialsWithHandler:(void (^)(NSString *username, NSString *password))setCredentials;


/**
 * When a link is clicked in the authorization dialog, like for instance to create an account or recover a lost password,
 * the Dailymotion SDK asks the UI delegate if the link should be openned in an external browser or if the UI delegate
 * want to handle the openned link by itself.
 *
 * @param client The DMOAuthClient requesting this information.
 * @param url The URL to the webpage to show to the end-user.
 */
- (BOOL)dailymotionOAuthRequest:(DMOAuthClient *)client shouldOpenURLInExternalBrowser:(NSURL *)url;

/**
 * Called when the session expired and can't be automatically resumed.
 *
 * @param client The DMOAuthClient sending this message
 */
- (void)dailymotionOAuthRequestSessionDidExpire:(DMOAuthClient *)client;

@end