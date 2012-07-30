//
//  AppDelegate.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 21/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (nonatomic, strong) UIViewController *_loginViewController;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    DMAPI *api = [DMAPI sharedAPI];
    [api.oauth setGrantType:DailymotionGrantTypeAuthorization withAPIKey:@"74720ca5788e5685c958" secret:@"dcdb37480ba47e6aba0b63cddf20dcc4c448b066" scope:@"manage_videos read"];
    api.oauth.delegate = self;
    [api get:@"/me" callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        NSLog(@"me: %@", result);
    }];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)dailymotionOAuthRequest:(DMOAuthClient *)request createModalDialogWithView:(UIView *)view
{
    if (!self._loginViewController)
    {
        self._loginViewController = [[UIViewController alloc] init];
    }
    self._loginViewController.view = view;
    [self.window.rootViewController presentModalViewController:self._loginViewController animated:YES];
}

- (void)dailymotionOAuthRequestCloseModalDialog:(DMOAuthClient *)request
{
    [self.window.rootViewController dismissModalViewControllerAnimated:YES];
}

@end
