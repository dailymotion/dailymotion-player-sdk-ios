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
    DMPlayerViewController *playerViewController = segue.destinationViewController;
    playerViewController.delegate = self;
    [playerViewController loadVideo:@"x4v4jp" withParams:@{@"webkit-playsinline":@(YES)}];
  }
}

#pragma mark DMPlayerDelegate
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName {
  if ([eventName isEqualToString:@"apiready"]) {
    [player play];
  }
}

@end
