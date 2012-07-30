//
//  VideoEditViewController.h
//  UploaderSample
//
//  Created by Olivier Poitrey on 24/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VideoEditViewController;
@class VideoInfo;

@protocol VideoEditViewControllerDelegate <NSObject>

- (void)videoEditControllerDidFinishEditingVideo:(VideoEditViewController *)videoEditController;
- (void)videoEditControllerDidCancel:(VideoEditViewController *)videoEditController;

@end

@interface VideoEditViewController : UITableViewController <UITextFieldDelegate>

@property (strong, nonatomic) VideoInfo *videoInfo;
@property (weak, nonatomic) id<VideoEditViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UITextField *descriptionTextField;
@property (weak, nonatomic) IBOutlet UITextField *tagsTextField;
@property (weak, nonatomic) IBOutlet UITableViewCell *channelCell;

- (IBAction)done:(id)sender;
- (IBAction)cancel:(id)sender;

@end
