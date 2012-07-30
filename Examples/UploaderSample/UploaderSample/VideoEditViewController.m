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

- (void)configureForm
{
    self.titleTextField.text = self.videoInfo.title;
    self.descriptionTextField.text = self.videoInfo.description;
    self.tagsTextField.text = self.videoInfo.tags;
    self.channelCell.textLabel.text = self.videoInfo.channelName;
    [self.channelCell setNeedsLayout];
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

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.titleTextField)
    {
        self.videoInfo.title = self.titleTextField.text;
    }
    else if (textField == self.descriptionTextField)
    {
        self.videoInfo.description = self.descriptionTextField.text;
    }
    else if (textField == self.tagsTextField)
    {
        self.videoInfo.tags = self.tagsTextField.text;
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
