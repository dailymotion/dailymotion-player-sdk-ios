//
//  DetailViewController.m
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import "DetailViewController.h"
#import "HistoryVideoCollection.h"

@interface DetailViewController ()

@property (strong, nonatomic) DMPlayerViewController *playerViewController;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) NSDictionary *_fieldsData;

@end

@implementation DetailViewController


- (NSArray *)fieldsNeeded
{
    return @[@"id", @"title", @"description"];
}

- (void)prepareForLoading
{
    self._fieldsData = nil;
    [self configureView];
}

- (void)setFieldsData:(NSDictionary *)data
{
    if (self._fieldsData != data)
    {
        self._fieldsData = data;

        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self._fieldsData)
    {
        self.title = self._fieldsData[@"title"];
        self.titleLabel.text = self._fieldsData[@"title"];
        self.descriptionTextView.text = self._fieldsData[@"description"];
        [self.playerViewController load:self._fieldsData[@"id"]];
        [self pushToHistory]; // faster for testing but should be only done on play event
    }
    else
    {
        self.title = self._fieldsData[@"title"];
        self.titleLabel.text = nil;
        self.descriptionTextView.text = nil;
        [self.playerViewController pause];
    }

    if (self.masterPopoverController != nil)
    {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Init the player
    self.playerViewController = [[DMPlayerViewController alloc] init];
    self.playerViewController.delegate = self;
    [self addChildViewController:self.playerViewController];
    self.playerViewController.view.frame = self.playerContainerView.bounds;
    [self.playerContainerView addSubview:self.playerViewController.view];

    [self configureView];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.playerViewController pause];
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

- (void)pushToHistory
{
    if (self._fieldsData[@"id"])
    {
        DMItem *item = [DMItem itemWithType:@"video" forId:self._fieldsData[@"id"] fromAPI:DMAPI.sharedAPI];
        [HistoryVideoCollection historyCollectionWithAPI:DMAPI.sharedAPI callback:^(DMItemLocalCollection *historyVideoCollection)
        {
            [historyVideoCollection addItem:item done:^(NSError *error) {}];
        }];
    }
}

#pragma mark - Player

- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"play"])
    {
        [self pushToHistory];
    }
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = @"Search";
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
