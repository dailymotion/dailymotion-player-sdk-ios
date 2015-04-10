//
//  ViewController.m
//  dailymotion-sdk-objc
//
//  Created by Zouhair Mahieddine on 12/15/14.
//  Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import "ViewController.h"

#import "DMPlayerViewController.h"

@interface ViewController () <DMPlayerDelegate>
@end

@implementation ViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"EmbedPlayerSegue"]) {
    // Instantiate the Player View Controller
    DMPlayerViewController *playerViewController = segue.destinationViewController;
    
    // Set its delegate and other parameters (if any)
    playerViewController.delegate = self;
    playerViewController.autoOpenExternalURLs = true;
    
    // Load the video using its ID and some parameters (if any)
    [playerViewController loadVideo:@"x4v4jp" withParams:@{@"webkit-playsinline":@(YES)}];
  }
}

#pragma mark DMPlayerDelegate
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName {
  // Grab the "apiready" event to trigger an autoplay
  if ([eventName isEqualToString:@"apiready"]) {
    [player play];
  }
}

@end
