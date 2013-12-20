//
//  DMAlert.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import <UIKit/UIKit.h>

typedef void (^DMAlertDismissBlock)(NSInteger buttonIndex);

typedef void (^DMAlertCancelBlock)();

@interface DMAlertView : UIAlertView

+ (UIAlertView *)showAlertViewWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles dismissBlock:(DMAlertDismissBlock)dismissBlock cancelBlock:(DMAlertCancelBlock)cancelBlock;

@end
