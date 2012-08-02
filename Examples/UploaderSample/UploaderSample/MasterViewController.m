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
#import <DailymotionSDK/DMItemTableViewCellDefaultCell.h>
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"chooseVideo"])
    {
        ((VideoPickerNavigationViewController *)segue.destinationViewController).videoDelegate = self;
        ((UIImagePickerController *)segue.destinationViewController).sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    else if ([segue.identifier isEqualToString:@"captureVideo"])
    {
        ((VideoPickerNavigationViewController *)segue.destinationViewController).videoDelegate = self;
        ((UIImagePickerController *)segue.destinationViewController).sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    }
    else if ([segue.identifier isEqualToString:@"publishVideo"])
    {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        NSAssert(indexPath.section == 0, @"wrong section for publish video segue");
        VideoUploadOperation *uploadOperation = [self._pendingUploads objectAtIndex:indexPath.row];
        ((VideoEditViewController *)segue.destinationViewController).delegate = self;
        ((VideoEditViewController *)segue.destinationViewController).videoInfo = uploadOperation.videoInfo;
    }
    else if ([segue.identifier isEqualToString:@"editVideo"])
    {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        NSAssert(indexPath.section == 1, @"wrong section for edit video segue");
        __weak VideoEditViewController *controller = (VideoEditViewController *)segue.destinationViewController;
        controller.delegate = self;

        [self.itemDataSource.itemCollection withItemFields:@[@"id", @"title", @"description", @"tags", @"channel", @"channel.name"] atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            VideoInfo *videoInfo = [[VideoInfo alloc] init];
            videoInfo.videoId = [data valueForKey:@"id"];
            videoInfo.title = [data valueForKey:@"title"];
            videoInfo.description = [data valueForKey:@"description"];
            videoInfo.tags = [(NSArray *)[data valueForKey:@"tags"] componentsJoinedByString:@", "];
            videoInfo.channel = [data valueForKey:@"channel"];
            videoInfo.channelName = [data valueForKey:@"channel.name"];
            controller.videoInfo = videoInfo;
        }];
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

- (void)itemTableViewDataSourceDidStartLoadingData:(DMItemTableViewDataSource *)dataSource
{
    [super itemTableViewDataSourceDidStartLoadingData:dataSource];
    [self setLoading:YES];
}

- (void)itemTableViewDataSourceDidFinishLoadingData:(DMItemTableViewDataSource *)dataSource
{
    [super itemTableViewDataSourceDidFinishLoadingData:dataSource];
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
    [args setValue:@(YES) forKey:@"published"];

    void (^callback)(NSError *) = ^(NSError *error)
    {
        if (error)
        {
            [UIAlertView showAlertViewWithTitle:@"Error"
                                        message:error.localizedDescription
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil
                                   dismissBlock:nil
                                    cancelBlock:nil];
            if (!videoInfo.videoId)
            {
                [self performSegueWithIdentifier:@"publishVideo" sender:videoInfo];
            }
        }
        else
        {
            NSInteger row = [self._pendingUploads indexOfObject:videoInfo];
            if (row == NSNotFound)
            {
                [self.tableView reloadData];
            }
            else
            {
                [self._pendingUploads removeObjectAtIndex:row];
                [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.tableView reloadData];
                });
            }
        }
    };

    if (videoInfo.videoId)
    {
        DMItem *item = [DMItem itemWithType:@"video" forId:videoInfo.videoId fromAPI:[DMAPI sharedAPI]];
        [self.itemDataSource.itemCollection editItem:item withData:args done:^(NSError *error)
        {
            callback(error);
        }];
    }
    else
    {
        [[DMAPI sharedAPI] post:@"/me/videos" args:args callback:^(id result, DMAPICacheInfo *cacheInfo, NSError *error)
        {
            callback(error);
        }];
    }
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
    [self.navigationController popToViewController:self animated:YES];
    [self postVideoInfo:videoEditController.videoInfo];
}

- (void)videoEditControllerDidCancel:(VideoEditViewController *)videoEditController
{
    [self dismissModalViewControllerAnimated:YES];
}

@end
