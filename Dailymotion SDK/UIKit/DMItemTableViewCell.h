//
//  DMItemTableViewCell.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 26/06/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemCollection.h"

@protocol DMItemTableViewCell <NSObject>

- (NSArray *)fieldsNeeded;
- (void)prepareForLoading;
- (void)setFieldsData:(NSDictionary *)data;

@end