//
//  DMAlert.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import <Foundation/Foundation.h>

typedef void (^DMAlertDismissBlock)(NSInteger buttonIndex);
typedef void (^DMAlertCancelBlock)();

@interface UIAlertView (DMBlock)

+ (UIAlertView *)showAlertViewWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles dismissBlock:(DMAlertDismissBlock)dismissBlock cancelBlock:(DMAlertCancelBlock)cancelBlock;

@end
