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

typedef enum
{
    DailymotionNoGrant,
    DailymotionGrantTypeAuthorization,
    DailymotionGrantTypeClientCredentials,
    DailymotionGrantTypePassword
} DailymotionGrantType;

@protocol DailymotionOAuthDelegate;

@interface DMOAuthClient : NSObject PLATFORM_DELEGATES

@property (nonatomic, copy) NSURL *oAuthAuthorizationEndpointURL;
@property (nonatomic, copy) NSURL *oAuthTokenEndpointURL;
@property (nonatomic, strong) DMNetworking *networkQueue;

/**
 * Set the delegate that conforms to the ``DailymotionDelegate`` protocol.
 */
@property (nonatomic, unsafe_unretained) id<DailymotionOAuthDelegate> delegate;

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
 * Perform a request with oauth authentication
 */
- (DMOAuthRequestOperation *)performRequestWithURL:(NSURL *)URL method:(NSString *)method payload:(id)payload headers:(NSDictionary *)headers cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler;

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

@protocol DailymotionOAuthDelegate <NSObject>

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
- (void)dailymotionOAuthRequest:(DMOAuthClient *)request createModalDialogWithView:(UIView *)view;
#else
- (void)dailymotionOAuthRequest:(DMOAuthRequest *)request createModalDialogWithView:(NSView *)view;
#endif

/**
 * This delegate method is called when the Dailymotion SDK authorization process is finished and instruct the reciever
 * to close the previousely created modal dialog.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypeAuthorization``.
 */
- (void)dailymotionOAuthRequestCloseModalDialog:(DMOAuthClient *)request;

/**
 * Called when the grant method is ``DailymotionGrantTypePassword`` and the credentials are requested by the library.
 * The delegate have to ask the user for her credentials and need to call back the ``handler` method in order for
 * the pending API calls to be completed.
 *
 * You MUST implement this delegate method if you set the grant type to ``DailymotionGrantTypePassword``.
 */
- (void)dailymotionOAuthRequest:(DMOAuthClient *)request didRequestUserCredentialsWithHandler:(void (^)(NSString *username, NSString *password))setCredentials;


/**
 * When a link is clicked in the authorization dialog, like for instance to create an account or recover a lost password,
 * the Dailymotion SDK asks the UI delegate if the link should be openned in an external browser or if the UI delegate
 * want to handle the openned link by itself.
 */
- (BOOL)dailymotionOAuthRequest:(DMOAuthClient *)request shouldOpenURLInExternalBrowser:(NSURL *)url;

@end