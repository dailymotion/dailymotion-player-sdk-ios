//
//  DMPickerViewComponent.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItemCollection.h"
#import "DMItemDataSourceItem.h"

@class DMItemPickerViewComponent;

@protocol DMItemPickerViewComponentDelegate <NSObject>

@optional

- (void)pickerViewComponentStartedLoadingData:(DMItemPickerViewComponent *)pickerComponent;

- (void)pickerViewComponentDidUpdateContent:(DMItemPickerViewComponent *)pickerComponent;

- (void)pickerViewComponentDidEnterOfflineMode:(DMItemPickerViewComponent *)dataSource;

- (void)pickerViewComponentDidLeaveOfflineMode:(DMItemPickerViewComponent *)dataSource;

- (void)pickerViewComponent:(DMItemPickerViewComponent *)dataSource didFailWithError:(NSError *)error;

- (void)pickerViewComponent:(DMItemPickerViewComponent *)dataSource didSelectItem:(DMItem *)item;

@end

/**
 * Data-source for UIPickerViewComponent.
 */
@interface DMItemPickerViewComponent : NSObject

@property(nonatomic, weak) id <DMItemPickerViewComponentDelegate> delegate;
@property(nonatomic, strong) NSError *lastError;

- (id)initWithItemCollection:(DMItemCollection *)itemCollection createRowViewBlock:(UIView <DMItemDataSourceItem> *(^)())createRowViewBlock;

- (id)initWithItemCollection:(DMItemCollection *)itemCollection withTitleFromField:(NSString *)fieldName;

- (NSInteger)numberOfRows;

- (UIView *)viewForRow:(NSInteger)row reusingView:(UIView *)view;

- (void)didSelectRow:(NSInteger)row;

@end
