//
//  VideoTableViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "VideoTableViewController.h"
#import "DetailViewController.h"
#import <DailymotionSDK/DMAlert.h>

@interface VideoTableViewController ()

@property (nonatomic, strong) DMItemPageViewDataSource *pageViewDataSource;
@property (nonatomic, strong) DMItemOperation *_itemOperation;
@property (nonatomic, strong) UIView *_overlayView;
@property (nonatomic, strong) UIActivityIndicatorView *_loadingIndicatorView;

@end

@implementation VideoTableViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.itemDataSource.cellIdentifier = @"Cell";

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    }
    else
    {
        self.pageViewDataSource = [[DMItemPageViewDataSource alloc] init];
        UIStoryboard *storyboard = self.storyboard;
        self.pageViewDataSource.createViewControllerBlock = ^
        {
            return [storyboard instantiateViewControllerWithIdentifier:@"DetailViewController"];
        };
    }

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
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.view bringSubviewToFront:self._overlayView];
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

- (void)setLoading:(BOOL)loading
{
    if (loading)
    {
        [self._loadingIndicatorView startAnimating];
        self._overlayView.hidden = NO;
        [self.view bringSubviewToFront:self._overlayView];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.scrollEnabled = NO;
    }
    else
    {
        [self._loadingIndicatorView stopAnimating];
        self._overlayView.hidden = YES;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.scrollEnabled = YES;
    }
}

#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DMItemCollection *itemCollection = self.itemDataSource.itemCollection;
        // Cancel the previous operation if any
        [self._itemOperation cancel];

        [self.detailViewController prepareForLoading];

        // Load eventual additional needed fields and show them
        self._itemOperation = [itemCollection withItemFields:self.detailViewController.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (error)
            {
                [DMAlertView showAlertViewWithTitle:@"Error"
                                            message:error.localizedDescription
                                  cancelButtonTitle:@"Dismiss"
                                  otherButtonTitles:nil
                                       dismissBlock:nil
                                        cancelBlock:nil];
            }
            else
            {
                [self.detailViewController setFieldsData:data];
            }
        }];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"])
    {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        UIPageViewController *pageViewController = [segue destinationViewController];

        // Pass the table view data source's current itemCollection to the page view controller's datasource
        self.pageViewDataSource.itemCollection = self.itemDataSource.itemCollection;
        pageViewController.dataSource = self.pageViewDataSource;

        // Ask the datasource for the initial view controller (for the selected video) to be shown
        UIViewController <DMItemDataSourceItem> *viewController = [self.pageViewDataSource viewControllerAtIndex:indexPath.row];
        [pageViewController setViewControllers:@[viewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

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

@end
