//
//  DMOAuthSession.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

/**
 * A (storable) OAuth session.
 */
@interface DMOAuthSession : NSObject

@property(nonatomic, copy) NSString *accessToken;
@property(nonatomic, strong) NSDate *expires;
@property(nonatomic, copy) NSString *refreshToken;
@property(nonatomic, readonly) NSString *scope;

/**
 * Instanciate a session object with session info dictionary coming from auth server.
 *
 * @param sessionInfo A dictionary returned by the token server with all the session information.
 */
+ (DMOAuthSession *)sessionWithSessionInfo:(NSDictionary *)sessionInfo;

@end


@interface DMOAuthSession (Keychain)

/**
 * Load a session from a given keychain identifier
 *
 * @param keychainIdentifier The keychain identifier to read the session from
 *
 * @return The session if present, nil otherwise
 */
+ (DMOAuthSession *)sessionFromKeychainIdentifier:(NSString *)keychainIdentifier;

/**
 * Save the session in the keychain at the given identifier
 *
 * @param keychainIdentifier The keychain identifier to store the session with
 */
- (BOOL)storeInKeychainWithIdentifier:(NSString *)keychainIdentifier;

/**
 * Clear the session from the keychain
 *
 * @param keychainIdentifier The keychain identifier to clear the session from
 */
- (BOOL)clearFromKeychainWithIdentifier:(NSString *)keychainIdentifier;

@end
