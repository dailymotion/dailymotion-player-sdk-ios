//
//  DMItemPickerViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import "DMItemPickerViewDataSource.h"

@interface DMItemPickerViewDataSource ()

@end

@implementation DMItemPickerViewDataSource

- (void)setComponents:(NSArray *)components {
    for (id component in components) {
        NSParameterAssert([component isKindOfClass:DMItemPickerViewComponent.class]);
    }
    _components = components;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return self.components ? [self.components count] : 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [self.components[component] numberOfRows];
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    return [self.components[component] viewForRow:row reusingView:view];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [self.components[component] didSelectRow:row];

}

@end
