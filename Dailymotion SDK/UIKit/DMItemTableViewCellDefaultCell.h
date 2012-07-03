//
//  DMItemTableViewCellDefaultCell.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 26/06/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemTableViewCell.h"

/**
 * Example implementation of DMItemTableViewCell protocol.
 */
@interface DMItemTableViewDefaultCell : UITableViewCell <DMItemTableViewCell>

- (NSArray *)fieldsNeeded;
- (void)prepareForLoading;
- (void)setFieldsData:(NSDictionary *)data;

@end
