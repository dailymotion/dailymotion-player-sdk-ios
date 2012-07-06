//
//  MasterViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "MasterViewController.h"
#import <DailymotionSDK/SDK.h>
#import "DetailViewController.h"

@interface MasterViewController ()

@property (nonatomic, strong) DMAPI *api;
@property (nonatomic, strong) DMItemTableViewDataSource *tableDataSource;
@property (nonatomic, strong) DMItemPageViewDataSource *pageViewDataSource;
@property (nonatomic, strong) DMItemOperation *_itemOperation;
@property (nonatomic, strong) UIView *_overlayView;
@property (nonatomic, strong) UIActivityIndicatorView *_loadingIndicatorView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end

@implementation MasterViewController

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

    self.api = [[DMAPI alloc] init];
    self.tableDataSource = [[DMItemTableViewDataSource alloc] init];
    self.tableDataSource.cellIdentifier = @"Cell";
    self.tableView.dataSource = self.tableDataSource;

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

    __weak MasterViewController *bself = self;

    // Handle DMItemTableViewDataSource notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:DMItemTableViewDataSourceLoadingNotification
                                                      object:self.tableDataSource
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
    {
        [bself setLoading:YES];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:DMItemTableViewDataSourceUpdatedNotification
                                                      object:self.tableDataSource
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
    {
        [bself setLoading:NO];
        [bself.tableView reloadData];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:DMItemTableViewDataSourceErrorNotification
                                                      object:self.tableDataSource
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
    {
        NSError *error = ((DMItemTableViewDataSource *)note.object).lastError;
        [UIAlertView showAlertViewWithTitle:@"Error"
                                    message:error.localizedDescription
                          cancelButtonTitle:@"Dismiss"
                          otherButtonTitles:nil
                               dismissBlock:nil
                                cancelBlock:nil];
    }];

    // Handle auto resuming
    NSString *resumeCollectionPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"resumeVideoCollection.archive"];

    dispatch_async(dispatch_get_current_queue(), ^
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:resumeCollectionPath] && !self.tableDataSource.itemCollection)
        {
            DMItemCollection *resumedItemCollection = [DMItemCollection itemCollectionFromFile:resumeCollectionPath withAPI:self.api];
            if (!self.tableDataSource.itemCollection)
            {
                self.tableDataSource.itemCollection = resumedItemCollection;
                self.searchBar.text = ((DMItemRemoteCollection *)resumedItemCollection).params[@"search"];
            }
            //[[NSFileManager defaultManager] removeItemAtPath:resumeCollectionPath error:NULL];
        }
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
    {
        if (bself.tableDataSource.itemCollection)
        {
            [bself.tableDataSource.itemCollection saveToFile:resumeCollectionPath];
        }
    }];
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
        self.tableView.scrollEnabled = NO;
    }
    else
    {
        [self._loadingIndicatorView stopAnimating];
        self._overlayView.hidden = YES;
        self.tableView.scrollEnabled = YES;
    }
}

#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DMItemCollection *itemCollection = self.tableDataSource.itemCollection;
        // Cancel the previous operation if any
        [self._itemOperation cancel];

        [self.detailViewController prepareForLoading];

        // Load eventual additional needed fields and show them
        self._itemOperation = [itemCollection withItemFields:self.detailViewController.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (error)
            {
                [UIAlertView showAlertViewWithTitle:@"Error"
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
        self.pageViewDataSource.itemCollection = self.tableDataSource.itemCollection;
        pageViewController.dataSource = self.pageViewDataSource;

        // Ask the datasource for the initial view controller (for the selected video) to be shown
        UIViewController <DMItemDataSourceItem> *viewController = [self.pageViewDataSource viewControllerAtIndex:indexPath.row];
        [pageViewController setViewControllers:@[viewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

    }
}

#pragma mark - Search Bar

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Change the table view itemCollection with a new video list query
    // The DMItemTableViewDataSource will handle the change and send notifications to show loading and refresh the table view when necessary
    self.tableDataSource.itemCollection = [DMItemCollection itemCollectionWithType:@"video"
                                                                         forParams:@{@"sort": @"relevance", @"search": searchBar.text}
                                                                           fromAPI:self.api];
    [searchBar resignFirstResponder];
}

@end
