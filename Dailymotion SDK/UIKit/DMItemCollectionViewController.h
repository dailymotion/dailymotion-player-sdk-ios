//
//  DMItemCollectionViewController.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 21/09/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemCollectionViewDataSource.h"

@interface DMItemCollectionViewController : UICollectionViewController <DMItemCollectionViewDataSourceDelegate>

@property (nonatomic, readonly) DMItemCollectionViewDataSource *itemDataSource;

@end
