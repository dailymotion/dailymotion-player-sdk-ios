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

@end

@implementation MasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    }

    self.api = [[DMAPI alloc] init];
    self.tableDataSource = [[DMItemTableViewDataSource alloc] init];
    self.tableDataSource.itemCollection = [DMItemCollection itemCollectionWithType:@"video" forParams:@{@"filters": @"featured"} fromAPI:self.api];
    self.tableDataSource.cellIdentifier = @"Cell";
    self.tableView.dataSource = self.tableDataSource;

    self.pageViewDataSource = [[DMItemPageViewDataSource alloc] init];
    self.pageViewDataSource.itemCollection = self.tableDataSource.itemCollection;
    UIStoryboard *storyboard = self.storyboard;
    self.pageViewDataSource.createViewControllerBlock = ^
    {
        return [storyboard instantiateViewControllerWithIdentifier:@"DetailViewController"];
    };


    __weak MasterViewController *bself = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:DMItemTableViewDataSourceUpdatedNotification
                                                      object:self.tableDataSource
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {[bself.tableView reloadData];}];

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
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        DMItemCollection *itemCollection = self.tableDataSource.itemCollection;
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

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath forDetailViewController:(UIPageViewController *)pageViewController
{
    pageViewController.dataSource = self.pageViewDataSource;
    UIViewController <DMItemDataSourceItem> *viewController = [self.pageViewDataSource viewControllerAtIndex:indexPath.row];
    [pageViewController setViewControllers:@[viewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"])
    {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [self selectItemAtIndexPath:indexPath forDetailViewController:[segue destinationViewController]];
    }
}

@end
