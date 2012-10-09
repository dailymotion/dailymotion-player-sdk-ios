//
//  DMItemPickerLabel.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <UIKit/UIKit.h>
#import "DMItemDataSourceItem.h"

/**
 * UIPickerLabel sub-class handling Dailymotion API datasource.
 *
 * @see DMItemPickerViewComponent
 */
@interface DMItemPickerLabel : UILabel <DMItemDataSourceItem>

- (id)initWithFieldName:(NSString *)fieldName;

@end
