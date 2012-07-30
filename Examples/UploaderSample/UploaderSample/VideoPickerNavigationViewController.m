//
//  VideoPickerNavigationViewController.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 24/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "VideoPickerNavigationViewController.h"
#import "VideoInfo.h"
#import <MobileCoreServices/UTCoreTypes.h>

@implementation VideoPickerNavigationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    super.delegate = self;
    self.mediaTypes = @[(NSString *)kUTTypeMovie];
    self.allowsEditing = YES;
    self.videoMaximumDuration = 60 * 60;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    ((VideoEditViewController *)segue.destinationViewController).delegate = self;
    ((VideoEditViewController *)segue.destinationViewController).videoInfo = self.videoInfo;
    [self pushViewController:segue.destinationViewController animated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.videoInfo = [[VideoInfo alloc] init];
    self.videoInfo.fileURL = [info valueForKey:UIImagePickerControllerMediaURL];
    [self performSegueWithIdentifier:@"editInfo" sender:self];
}

- (void)videoEditControllerDidFinishEditingVideo:(VideoEditViewController *)videoEditController
{
    if ([self.videoDelegate respondsToSelector:@selector(videoPickerController:didFinishPickingVideoWithInfo:)])
    {
        [self.videoDelegate videoPickerController:self didFinishPickingVideoWithInfo:videoEditController.videoInfo];
    }
}

- (void)videoEditControllerDidCancel:(VideoEditViewController *)videoEditController
{
    if ([self.videoDelegate respondsToSelector:@selector(videoPickerControllerDidCancel:)])
    {
        [self.videoDelegate videoPickerControllerDidCancel:self];
    }
}

@end
