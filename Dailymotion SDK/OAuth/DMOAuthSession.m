//
//  DMOAuthSession.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthSession.h"

NSString *const kDMKeychainAccessGroup = @"com.dailymotion";

#define DMISSET(dict, key) dict[key] && ![dict[key] isKindOfClass:[NSNull class]] && ![dict[key] isEqual:@""]

@interface DMOAuthSession ()

@property (nonatomic, readwrite) NSString *scope;

@end

@implementation DMOAuthSession
{
    NSString *_accessToken;
}

+ (DMOAuthSession *)sessionWithSessionInfo:(NSDictionary *)sessionInfo;
{
    DMOAuthSession *session = [[self alloc] init];

    if (session)
    {
        if (DMISSET(sessionInfo, @"access_token"))
        {
            session.accessToken = sessionInfo[@"access_token"];
        }
        if (DMISSET(sessionInfo, @"expires_in"))
        {
            session.expires = [NSDate dateWithTimeIntervalSinceNow:[sessionInfo[@"expires_in"] doubleValue]];
        }
        else if (DMISSET(sessionInfo, @"expires"))
        {
            session.expires = sessionInfo[@"expires"];
        }
        if (DMISSET(sessionInfo, @"refresh_token"))
        {
            session.refreshToken = sessionInfo[@"refresh_token"];
        }
        if (DMISSET(sessionInfo, @"scope"))
        {
            session.scope = sessionInfo[@"scope"];
        }
        if (!session.accessToken && !session.refreshToken)
        {
            session = nil;
        }
    }

    return session;
}

- (NSString *)accessToken
{
    if (_accessToken)
    {
        if (!self.expires || [self.expires timeIntervalSinceNow] > 0)
        {
            return _accessToken;
        }
        else
        {
            // Token expired
            _accessToken = nil;
        }
    }

    return nil;
}

- (void)setAccessToken:(NSString *)accessToken
{
    _accessToken = accessToken;
}

@end


@implementation DMOAuthSession (Keychain)

+ (DMOAuthSession *)sessionFromKeychainIdentifier:(NSString *)keychainIdentifier
{
    NSDictionary *keychainQuery = [self keychainQueryForIdentifier:keychainIdentifier];
    CFTypeRef secData = nil;

    OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, &secData);
    if (result == noErr)
    {
        NSDictionary *sessionInfo = [self dictionaryFromSecItem:(__bridge NSDictionary *)secData];
        return [DMOAuthSession sessionWithSessionInfo:(NSDictionary *)sessionInfo];
    }
    else if (result != errSecItemNotFound)
    {
        NSLog(@"Keychain access error: %ld", result);
    }

    return nil;
}

- (BOOL)storeInKeychainWithIdentifier:(NSString *)keychainIdentifier
{
    CFTypeRef attributes = NULL;
    NSDictionary *keychainQuery = [self.class keychainQueryForIdentifier:(NSString *)keychainIdentifier];

    // If the keychain item already exists, modify it:
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, &attributes) == noErr)
    {
        // First we need the attributes from the Keychain.
        NSMutableDictionary *updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];

        // Second we need to add the appropriate search key/values.
        updateItem[(__bridge id)kSecClass] = keychainQuery[(__bridge id)kSecClass];

        // Lastly, we need to set up the updated attribute list being careful to remove the class.
        NSMutableDictionary *tempCheck = [self secItemDictionaryForIdentifier:keychainIdentifier];
        [tempCheck removeObjectForKey:(__bridge id)kSecClass];

#if TARGET_IPHONE_SIMULATOR
        // Remove the access group if running on the iPhone simulator.
        [tempCheck removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
#endif

        return SecItemUpdate((__bridge CFDictionaryRef)updateItem, (__bridge CFDictionaryRef)tempCheck) == noErr;
    }
    else
    {
        // No previous item found; add the new one.
        OSStatus result = SecItemAdd((__bridge CFDictionaryRef)[self secItemDictionaryForIdentifier:keychainIdentifier], NULL);
        if (result != noErr)
        {
            NSLog(@"Keychain write error: %ld", result);
        }
        return result == noErr;
    }
}

- (BOOL)clearFromKeychainWithIdentifier:(NSString *)keychainIdentifier
{
    NSDictionary *secItem = [self secItemDictionaryForIdentifier:keychainIdentifier];
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)secItem);
    if (result == noErr || result == errSecItemNotFound)
    {
        return YES;
    }
    else
    {
        NSLog(@"Keychain delete error: %ld", result);
        return NO;
    }
}

+ (NSDictionary *)keychainQueryForIdentifier:(NSString *)keychainIdentifier
{
    return
    @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: keychainIdentifier,
        (__bridge id)kSecAttrService: @"Dailymotion",

#if !TARGET_IPHONE_SIMULATOR
        (__bridge id)kSecAttrAccessGroup: kDMKeychainAccessGroup
#endif

        // Return the attributes of the first match only:
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,

        // Return the attributes of the keychain item (the password is
        // acquired in the secItemFormatToDictionary: method):
        (__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue
    };
}

- (NSMutableDictionary *)secItemDictionaryForIdentifier:(NSString *)keychainIdentifier
{
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *secItem = [NSMutableDictionary dictionary];

    if (self.refreshToken)
    {
        // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
        // This is where to store sensitive data that should be encrypted thus we store the refresh token in there
        secItem[(__bridge id)kSecValueData] = [self.refreshToken dataUsingEncoding:NSUTF8StringEncoding];
    }

    // Add the Generic Password keychain item class attribute.
    secItem[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    secItem[(__bridge id)kSecAttrAccount] = keychainIdentifier;
    secItem[(__bridge id)kSecAttrService] = @"Dailymotion";

    return secItem;
}

+ (NSMutableDictionary *)dictionaryFromSecItem:(NSDictionary *)secItem
{
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:secItem];

    // Add the proper search key and class attribute.
    returnDictionary[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
    returnDictionary[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

    // Acquire the password data from the attributes.
    CFTypeRef passwordData = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)returnDictionary, &passwordData) == noErr)
    {
        // Remove the search, class, and identifier key/value, we don't need them anymore.
        [returnDictionary removeObjectForKey:(__bridge id)kSecReturnData];

        // Add the password as refresh_token to the dictionary, converting from NSData to NSString.
        NSString *password = [[NSString alloc] initWithBytes:[(__bridge NSData *)passwordData bytes]
                                                      length:[(__bridge NSData *)passwordData length]
                                                    encoding:NSUTF8StringEncoding];
        returnDictionary[@"refresh_token"] = password;
    }
    else
    {
        // Don't do anything if nothing is found.
        NSAssert(NO, @"Serious error, no matching item found in the keychain.\n");
    }

    return returnDictionary;
}


@end
