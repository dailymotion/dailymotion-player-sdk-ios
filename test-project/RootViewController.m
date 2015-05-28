//
//  RootViewController.m
//  dailymotion-sdk-objc
//
//  Created by Zouhair Mahieddine on 5/27/15.
//  Copyright (c) 2015 Dailymotion. All rights reserved.
//

#import "RootViewController.h"

#import "PlaybackViewController.h"

@interface RootViewController ()

@property (weak, nonatomic) IBOutlet UITextField *baseURLField;
@property (weak, nonatomic) IBOutlet UITextField *additionalParametersField;
@property (weak, nonatomic) IBOutlet UITextField *videoIDField;
@property (weak, nonatomic) IBOutlet UITextField *playerWidthField;
@property (weak, nonatomic) IBOutlet UITextField *playerHeightField;

@end

@implementation RootViewController

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.baseURLField becomeFirstResponder];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"StartPlayerTestSegue"]) {
    PlaybackViewController *playbackViewController = segue.destinationViewController;
    playbackViewController.baseURL = [self baseURLStringFromString:self.baseURLField.text];
    playbackViewController.videoID = self.videoIDField.text;
    playbackViewController.additionalParameters = [self queryDictionaryFromString:self.additionalParametersField.text];
    
    playbackViewController.playerSize = CGSizeMake([self.playerWidthField.text floatValue],
                                                   [self.playerHeightField.text floatValue]);
  }
}

- (NSString *)baseURLStringFromString:(NSString *)baseURLString {
  if ([baseURLString hasSuffix:@"/"]) {
    baseURLString = [baseURLString substringToIndex:[baseURLString rangeOfString:baseURLString].length - 1];
  }
  return baseURLString;
}

- (NSDictionary *)queryDictionaryFromString:(NSString *)queryString {
  if ([queryString hasPrefix:@"&"] || [queryString hasPrefix:@"?"]) {
    queryString = [queryString substringFromIndex:1];
  }
  NSString *urlString = [NSString stringWithFormat:@"http://www.dailymotion.com?%@", queryString];
  NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
  
  NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];
  for (NSURLQueryItem *queryItem in urlComponents.queryItems) {
    [queryDictionary setObject:queryItem.value forKey:queryItem.name];
  }
  
  return queryDictionary;
}

@end
