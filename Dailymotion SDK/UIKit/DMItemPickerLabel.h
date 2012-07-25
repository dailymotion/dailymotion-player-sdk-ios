//
//  DMItemPickerLabel.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemDataSourceItem.h"

@interface DMItemPickerLabel : UILabel <DMItemDataSourceItem>

- (id)initWithFieldName:(NSString *)fieldName;

@end
