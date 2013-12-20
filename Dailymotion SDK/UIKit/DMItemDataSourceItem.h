//
//  DMItemDataSourceItem.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 26/06/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemCollection.h"

/**
 * The DMItemDataSourceItem protocol defines methods that datasource items class must implement to work with
 * Dailymotion UIKit data sources.
 */
@protocol DMItemDataSourceItem <NSObject>

@optional

- (void)setError:(NSError *)error;

@property(strong, nonatomic) DMItem *item;

@required

- (NSArray *)fieldsNeeded;

- (void)prepareForLoading;

- (void)setFieldsData:(NSDictionary *)data;

@end