//
//  DMItemTableViewController.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemTableViewDataSource.h"

@interface DMItemTableViewController : UITableViewController <DMItemTableViewDataSourceDelegate>

@property (nonatomic, readonly) DMItemTableViewDataSource *itemDataSource;

@end