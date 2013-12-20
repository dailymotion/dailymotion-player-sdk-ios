//
//  DMItemPickerViewDataSource.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemPickerViewComponent.h"

/**
 * Data-source for UIPickerView.
 */
@interface DMItemPickerViewDataSource : NSObject <UIPickerViewDataSource, UIPickerViewDelegate>

@property(nonatomic, strong) NSArray *components;

@end
