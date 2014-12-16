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

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  DMPlayerViewController *playerViewController = [[DMPlayerViewController alloc] initWithVideo:@"x4v4jp" params:nil];
  playerViewController.delegate = self;
  [self presentViewController:playerViewController animated:YES completion:nil];
}

#pragma mark DMPlayerDelegate
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName {
  if ([eventName isEqualToString:@"apiready"]) {
    [player play];
  }
}

@end
