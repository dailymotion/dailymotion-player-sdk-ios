//
//  DMUDID.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMUDID : NSObject

/**
 * Return a Device Identifier based on the MAC address of the first network interface
 *
 * Should be safely used in place of deprecated UIDevice identifier
 */
+ (NSString *)deviceIdentifier;

@end
