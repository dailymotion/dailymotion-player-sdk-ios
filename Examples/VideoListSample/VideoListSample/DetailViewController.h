//
//  DetailViewController.h
//  VideoListSample
//
//  Created by Olivier Poitrey on 04/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DailymotionSDK/SDK.h>

@interface DetailViewController : UIViewController <UIScrollViewDelegate, UISplitViewControllerDelegate, DMItemDataSourceItem, DMPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIView *playerContainerView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITextView *descriptionTextView;

@end
