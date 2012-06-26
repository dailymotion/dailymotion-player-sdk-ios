//
//  DMItemTableViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"

static NSString *const DMItemTableViewDataSourceUpdatedNotification = @"DMItemTableViewDataSourceUpdatedNotification";

@interface DMItemTableViewDataSource : NSObject <UITableViewDataSource>

@property (nonatomic, copy) NSString *cellIdentifier;
@property (nonatomic, strong) DMItemCollection *itemCollection;

@end
