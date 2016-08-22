//
//  ViewController.h
//  dailymotion-sdk-objc
//
//  Created by Zouhair Mahieddine on 12/15/14.
//  Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlaybackViewController : UIViewController

@property(strong, nonatomic) NSString *baseURL;
@property(strong, nonatomic) NSString *videoID;
@property(strong, nonatomic) NSDictionary *additionalParameters;
@property(assign, nonatomic) CGSize playerSize;
@property(assign, nonatomic) CGSize initialPlayerSize;

@end

