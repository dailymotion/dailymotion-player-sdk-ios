//
//  MasterViewController.m
//  UploaderSample
//
//  Created by Olivier Poitrey on 21/07/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import <DailymotionSDK/DMAlert.h>
#import "VideoUploadingCell.h"

@interface MasterViewController ()

@property (nonatomic, strong) UIView *_overlayView;
@property (nonatomic, strong) UIActivityIndicatorView *_loadingIndicatorView;
@property (nonatomic, strong) UIActionSheet *_pickerActionChoice;
@property (nonatomic, strong) UIImagePickerController *_videoPicker;
@property (nonatomic, strong) NSOperationQueue *_uploadOperationQueue;
@property (nonatomic, strong) NSMutableArray *_pendingUploads;

@end

@implementation MasterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.itemDataSource.editable = YES;
    self.itemDataSource.cellIdentifier = @"Cell";
    self.itemDataSource.itemCollection = [[DMItem itemWithType:@"user" forId:@"me" fromAPI:[DMAPI sharedAPI]] itemCollectionWithConnection:@"videos" ofType:@"video" withParams:nil];

    // Init loading overlay view
    self._overlayView = [[UIView alloc] initWithFrame:CGRectMake(0 ,49, self.view.frame.size.width, self.tableView.frame.size.height)];
    self._overlayView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    self._overlayView.backgroundColor = [UIColor whiteColor];
    self.tableView.scrollEnabled = NO;
    self._loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self._loadingIndicatorView.center = self._overlayView.center;
    CGRect frame = self._loadingIndicatorView.frame;
    frame.origin.y = 150;
    self._loadingIndicatorView.frame = frame;
    [self._overlayView addSubview:self._loadingIndicatorView];
    [self.view addSubview:self._overlayView];

    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertVideo:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    self._uploadOperationQueue = [[NSOperationQueue alloc] init];
    self._uploadOperationQueue.maxConcurrentOperationCount = 2;
    self._pendingUploads = [[NSMutableArray alloc] init];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.view bringSubviewToFront:self._overlayView];
}

- (void)setLoading:(BOOL)loading
{
    if (loading)
    {
        [self._loadingIndicatorView startAnimating];
        self._overlayView.hidden = NO;
        self.tableView.scrollEnabled = NO;
    }
    else
    {
        [self._loadingIndicatorView stopAnimating];
        self._overlayView.hidden = YES;
        self.tableView.scrollEnabled = YES;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
    else
    {
        return YES;
    }
}

- (void)insertVideo:(id)sender
{
#if TARGET_IPHONE_SIMULATOR
    [UIAlertView showAlertViewWithTitle:@"Simulator Not Support"
                                message:@"Video capture isn't supported from the simulator"
                      cancelButtonTitle:@"Dismiss"
                      otherButtonTitles:nil
                           dismissBlock:nil
                            cancelBlock:nil];
#else
    self._pickerActionChoice = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Capture New Video", @"Choose From Library", nil];
    [self._pickerActionChoice showFromBarButtonItem:sender animated:YES];
#endif
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.detailViewController.detailItem = nil;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    ((VideoPickerNavigationViewController *)segue.destinationViewController).videoDelegate = self;

    if ([segue.identifier isEqualToString:@"chooseVideo"])
    {
        ((UIImagePickerController *)segue.destinationViewController).sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    else if ([segue.identifier isEqualToString:@"captureVideo"])
    {
        ((UIImagePickerController *)segue.destinationViewController).sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    }

}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex)
    {
        case 0:
            [self performSegueWithIdentifier:@"chooseVideo" sender:self];
            break;

        case 1:
            [self performSegueWithIdentifier:@"captureVideo" sender:self];
            break;
    }
}

#pragma Table Data Source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return 64;
    }
    else
    {
        return 44;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self._pendingUploads.count > 0)
    {
        if (section == 0)
        {
            return @"Pending Uploads";
        }
        else
        {
            return @"Uploaded Videos";
        }
    }
    else
    {
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return self._pendingUploads.count;
    }
    else
    {
        return [super tableView:tableView numberOfRowsInSection:section];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        VideoUploadingCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PendingUploadCell"];
        cell.videoInfo = [self._pendingUploads objectAtIndex:indexPath.row];
        return cell;
    }
    else
    {
        return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return NO;
    }
    else
    {
        return [super tableView:tableView canEditRowAtIndexPath:indexPath];
    }
}

#pragma mark - DMItemTableViewDataSourceDelegate

- (void)itemTableViewDataSourceStartedLoadingData:(DMItemTableViewDataSource *)dataSource
{
    [super itemTableViewDataSourceStartedLoadingData:dataSource];
    [self setLoading:YES];
}

- (void)itemTableViewDataSourceDidUpdateContent:(DMItemTableViewDataSource *)dataSource
{
    [super itemTableViewDataSourceDidUpdateContent:dataSource];
    [self setLoading:NO];
}

#pragma mark - VideoPickerNavigationViewControllerDelegate

- (void)videoPickerController:(VideoPickerNavigationViewController *)videoPickerController didFinishPickingVideoWithInfo:(VideoInfo *)videoInfo
{
    [self dismissModalViewControllerAnimated:YES];
    [self._pendingUploads addObject:videoInfo];
    VideoUploadOperation *uploadOperation = [[VideoUploadOperation alloc] initWithVideoInfo:videoInfo];
    uploadOperation.delegate = self;
    [self._uploadOperationQueue addOperation:uploadOperation];
    [self.tableView reloadData];
}

- (void)videoPickerControllerDidCancel:(VideoPickerNavigationViewController *)videoPickerController
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - VideoUploadOperationDelegate

- (void)postVideoInfo:(VideoInfo *)videoInfo
{
    NSDictionary *args = NSMutableDictionary.dictionary;
    for (NSString *field in @[@"title", @"description", @"channel", @"tags"])
    {
        [args setValue:[videoInfo valueForKey:field] forKey:field];
    }
    [args setValue:videoInfo.uploadedFileURL.absoluteString forKey:@"url"];

    [[DMAPI sharedAPI] post:@"/me/videos" args:args callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        if (error)
        {
            [UIAlertView showAlertViewWithTitle:@"Error"
                                        message:error.localizedDescription
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil
                                   dismissBlock:nil
                                    cancelBlock:nil];

            UINavigationController *editNavController = [self.storyboard instantiateViewControllerWithIdentifier:@"videoEdit"];
            VideoEditViewController *editViewController = (VideoEditViewController *)editNavController.topViewController;
            editViewController.videoInfo = videoInfo;
            editViewController.delegate = self;
            [self presentModalViewController:editNavController animated:YES];
        }
        else
        {
            NSInteger row = [self._pendingUploads indexOfObject:videoInfo];
            [self._pendingUploads removeObjectAtIndex:row];
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.tableView reloadData];
            });
        }
    }];
}

- (void)videoUploadOperation:(VideoUploadOperation *)videoUploadOperation didFinishUploadWithURL:(NSURL *)url
{
    videoUploadOperation.videoInfo.uploadedFileURL = url;
    [self postVideoInfo:videoUploadOperation.videoInfo];
}

#pragma mark - VideoEditViewControllerDelegate

- (void)videoEditControllerDidFinishEditingVideo:(VideoEditViewController *)videoEditController
{
    [self dismissModalViewControllerAnimated:YES];
    [self postVideoInfo:videoEditController.videoInfo];
}

@end
