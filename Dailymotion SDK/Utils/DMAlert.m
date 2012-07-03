//
//  DMAlert.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import "DMAlert.h"

static DMAlertDismissBlock _dismissBlock;
static DMAlertCancelBlock _cancelBlock;

@implementation UIAlertView (DMBlock)

+ (UIAlertView *)showAlertViewWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles dismissBlock:(DMAlertDismissBlock)dismissBlock cancelBlock:(DMAlertCancelBlock)cancelBlock
{
    _cancelBlock = cancelBlock;
    _dismissBlock = dismissBlock;
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:[self self] cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
    for (NSString *buttonTitle in otherButtonTitles)
    {
        [alertView addButtonWithTitle:buttonTitle];
    }
    [alertView show];
    return alertView;
}

+ (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == [alertView cancelButtonIndex])
    {
        if (_cancelBlock)
        {
            _cancelBlock();
        }
    }
    else
    {
        if (_dismissBlock)
        {
            _dismissBlock(buttonIndex - 1); // cancel button is button 0
        }
    }

    _cancelBlock = nil;
    _dismissBlock = nil;
}

@end
