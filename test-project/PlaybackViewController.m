//
//  ViewController.m
//  dailymotion-sdk-objc
//
//  Created by Zouhair Mahieddine on 12/15/14.
//  Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import "PlaybackViewController.h"

#import "DMPlayerViewController.h"

@interface PlaybackViewController () <DMPlayerDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *playerWidthLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *playerHeightLayoutConstraint;

@end

@implementation PlaybackViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"EmbedPlayerSegue"]) {
    // Instantiate the Player View Controller
    DMPlayerViewController *playerViewController = segue.destinationViewController;
    
    // Set its delegate and other parameters (if any)
    playerViewController.delegate = self;
//    playerViewController.autoOpenExternalURLs = true;
    
    // Load the video using its ID and some parameters (if any)
    playerViewController.webBaseURLString = self.baseURL;
    [playerViewController loadVideo:@"k6p7DomdYjX1xvdHNaO" withParams:@{@"webkit-playsinline": @0, @"logo": @0, @"info": @0}];
    
    self.playerWidthLayoutConstraint.constant = self.playerSize.width;
    self.playerHeightLayoutConstraint.constant = self.playerSize.height;
    
    [self.view setNeedsUpdateConstraints];
  }
}

#pragma mark DMPlayerDelegate
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName {
  // Grab the "apiready" event to trigger an autoplay
  if ([eventName isEqualToString:@"apiready"]) {
    [player play];
  } else if ([eventName isEqualToString:@"playing"]) {
    [player setFullscreen:YES];
  }
}

@end
