//
//  AppDelegate.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 21/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/SDK.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, DailymotionOAuthDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
