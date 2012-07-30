//
//  MasterViewController.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 21/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/SDK.h>
#import "VideoPickerNavigationViewController.h"
#import "VideoUploadOperation.h"

@class DetailViewController;

@interface MasterViewController : DMItemTableViewController <UIActionSheetDelegate, UIImagePickerControllerDelegate, VideoPickerNavigationViewControllerDelegate, VideoUploadOperationDelegate, VideoEditViewControllerDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;

@end
