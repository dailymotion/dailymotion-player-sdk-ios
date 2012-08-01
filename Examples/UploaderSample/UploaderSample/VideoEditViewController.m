//
//  VideoEditViewController.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 24/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "VideoEditViewController.h"
#import "ChannelSelectorViewController.h"
#import "VideoInfo.h"

@implementation VideoEditViewController

- (void)viewDidLoad
{
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self configureForm];
}

- (void)setVideoInfo:(VideoInfo *)videoInfo
{
    _videoInfo = videoInfo;
    [self configureForm];
}

- (void)configureForm
{
    if (self.videoInfo)
    {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.titleTextField.text = self.videoInfo.title;
        self.descriptionTextField.text = self.videoInfo.description;
        self.tagsTextField.text = self.videoInfo.tags;
        self.channelCell.textLabel.text = self.videoInfo.channelName;
        [self.channelCell setNeedsLayout];
    }
    else
    {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

- (void)saveFormData
{
    if (self.videoInfo)
    {
        self.videoInfo.title = self.titleTextField.text;
        self.videoInfo.description = self.descriptionTextField.text;
        self.videoInfo.tags = self.tagsTextField.text;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.channelCell == [self.tableView cellForRowAtIndexPath:indexPath])
    {
        [self.view endEditing:YES];
    }
}

 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"chooseChannel"])
    {
        ((ChannelSelectorViewController *)segue.destinationViewController).videoInfo = self.videoInfo;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self jumpToFieldWithTag:textField.tag + 1];
    return YES;
}

- (void)jumpToFieldWithTag:(NSUInteger)tag
{
    UIView *view = [self.tableView viewWithTag:tag];

    if (view == self.channelCell)
    {
        NSIndexPath *newIndexPath = [self.tableView indexPathForCell:(UITableViewCell *)view];
        [self.tableView selectRowAtIndexPath:newIndexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
        [self tableView:self.tableView didSelectRowAtIndexPath:newIndexPath];
        [self performSegueWithIdentifier:@"chooseChannel" sender:self];
    }
    else
    {
        [view becomeFirstResponder];
    }
}

- (IBAction)done:(id)sender
{
    [self saveFormData];
    if ([self.delegate respondsToSelector:@selector(videoEditControllerDidFinishEditingVideo:)])
    {
        [self.delegate videoEditControllerDidFinishEditingVideo:self];
    }
}

- (IBAction)cancel:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(videoEditControllerDidCancel:)])
    {
        [self.delegate videoEditControllerDidCancel:self];
    }
}

@end
