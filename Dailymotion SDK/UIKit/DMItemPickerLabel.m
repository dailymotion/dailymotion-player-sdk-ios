//
//  DMItemPickerLabel.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import "DMItemPickerLabel.h"

@interface DMItemPickerLabel ()

@property (nonatomic, strong) NSString *fieldName;

@end

@implementation DMItemPickerLabel

- (id)initWithFieldName:(NSString *)fieldName {
    self = [super init];
    if (self) {
        _fieldName = fieldName;
        self.font = [UIFont boldSystemFontOfSize:20];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    UIEdgeInsets insets = {0, 10, 0, 10};
    return [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}


- (NSArray *)fieldsNeeded {
    return @[self.fieldName];
}

- (void)prepareForLoading {
    self.text = nil;
}

- (void)setFieldsData:(NSDictionary *)data {
    self.text = data[self.fieldName];
}

@end
