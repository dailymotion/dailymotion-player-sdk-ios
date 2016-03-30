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
    playerViewController.autoOpenExternalURLs = true;
    
    // Load the video using its ID and some parameters (if any)
    playerViewController.webBaseURLString = self.baseURL;
    [playerViewController loadVideo:self.videoID withParams:self.additionalParameters];

    self.initialPlayerSize = self.playerSize;
    // Starting in fullscreen?
    if ([self.additionalParameters[@"fullscreen-state"] isEqualToString:@"fullscreen"]) {
        self.playerSize = self.view.frame.size;
    }
    self.playerWidthLayoutConstraint.constant = self.playerSize.width;
    self.playerHeightLayoutConstraint.constant = self.playerSize.height;

    [self.view setNeedsUpdateConstraints];
  }
}

- (void) toggleFullscreen:(DMPlayerViewController *)player {

    self.playerSize = player.fullscreen ? self.initialPlayerSize : self.view.frame.size;

    self.playerWidthLayoutConstraint.constant = self.playerSize.width;
    self.playerHeightLayoutConstraint.constant = self.playerSize.height;

    // Once the transition from/to fullscreen is complete, notify the player so it can update its UI.
    [player notifyFullscreenChange];
}

#pragma mark DMPlayerDelegate
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName {
  // Grab the "apiready" event to trigger an autoplay
  if ([eventName isEqualToString:@"apiready"]) {
    // From here, it's possible to interact with the player API.
    NSLog(@"Received apiready event");
  }

  // When "fullscreen-action" parameter is set to "trigger_event", the transition from/to fullscreen must be handled by the host application
  // This allow the host application to keep the player UI when going to fullscreen instead of depending on the native iOS player UI.
  if ([self.additionalParameters[@"fullscreen-action"] isEqualToString:@"trigger_event"] && [eventName isEqualToString:@"fullscreen_toggle_requested"]) {
    [self toggleFullscreen:player];
  }
}

@end
