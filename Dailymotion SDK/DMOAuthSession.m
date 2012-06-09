//
//  DMOAuthSession.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMOAuthSession.h"

NSString *const kDMKeychainAccessGroup = @"com.dailymotion";

#define DMISSET(dict, key) [dict valueForKey:key] && ![[dict valueForKey:key] isKindOfClass:[NSNull class]] && ![[dict valueForKey:key] isEqual:@""]

@interface DMOAuthSession ()

@property (nonatomic, readwrite) NSString *scope;

@end

@implementation DMOAuthSession
{
    NSString *_accessToken;
}

@dynamic accessToken;
@synthesize expires = _expires;
@synthesize refreshToken = _refreshToken;
@synthesize scope = _scope;

+ (DMOAuthSession *)sessionWithSessionInfo:(NSDictionary *)sessionInfo;
{
    DMOAuthSession *session = [[self alloc] init];

    if (session)
    {
        if (DMISSET(sessionInfo, @"access_token"))
        {
            session.accessToken = [sessionInfo valueForKey:@"access_token"];
        }
        if (DMISSET(sessionInfo, @"expires_in"))
        {
            session.expires = [NSDate dateWithTimeIntervalSinceNow:[[sessionInfo valueForKey:@"expires_in"] doubleValue]];
        }
        else if (DMISSET(sessionInfo, @"expires"))
        {
            session.expires = [sessionInfo valueForKey:@"expires"];
        }
        if (DMISSET(sessionInfo, @"refresh_token"))
        {
            session.refreshToken = [sessionInfo valueForKey:@"refresh_token"];
        }
        if (DMISSET(sessionInfo, @"scope"))
        {
            session.scope = [sessionInfo valueForKey:@"scope"];
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
        [updateItem setObject:[keychainQuery objectForKey:(__bridge id)kSecClass] forKey:(__bridge id)kSecClass];

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
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];

    [query setObject:keychainIdentifier forKey:(__bridge id)kSecAttrAccount];
    [query setObject:@"Dailymotion" forKey:(__bridge id)kSecAttrService];

    // Return the attributes of the first match only:
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    // Return the attributes of the keychain item (the password is
    // acquired in the secItemFormatToDictionary: method):
    [query setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];

#if !TARGET_IPHONE_SIMULATOR
    [query setObject:kDMKeychainAccessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif

    return query;
}

- (NSMutableDictionary *)secItemDictionaryForIdentifier:(NSString *)keychainIdentifier
{
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *secItem = [NSMutableDictionary dictionary];

    /*
    if (self.accessToken)
    {
        [secItem setObject:self.accessToken forKey:@"access_token"];
    }
    if (self.expires)
    {
        [secItem setObject:self.expires forKey:@"expires"];
    }*/
    if (self.refreshToken)
    {
        // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
        // This is where to store sensitive data that should be encrypted thus we store the refresh token in there
        [secItem setObject:[self.refreshToken dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    }
    /*
    if (self.scope)
    {
        [secItem setObject:self.scope forKey:@"scope"];
    }*/

    // Add the Generic Password keychain item class attribute.
    [secItem setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [secItem setObject:keychainIdentifier forKey:(__bridge id)kSecAttrAccount];
    [secItem setObject:@"Dailymotion" forKey:(__bridge id)kSecAttrService];

    return secItem;
}

+ (NSMutableDictionary *)dictionaryFromSecItem:(NSDictionary *)secItem
{
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:secItem];

    // Add the proper search key and class attribute.
    [returnDictionary setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [returnDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];

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
        [returnDictionary setObject:password forKey:@"refresh_token"];
    }
    else
    {
        // Don't do anything if nothing is found.
        NSAssert(NO, @"Serious error, no matching item found in the keychain.\n");
    }

    return returnDictionary;
}


@end
