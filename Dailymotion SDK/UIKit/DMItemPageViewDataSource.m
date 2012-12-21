//
//  DMItemPageViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import "DMItemPageViewDataSource.h"
#import "DMItemOperation.h"
#import "DMItemDataSourceItem.h"
#import "objc/runtime.h"

static char indexKey;

@interface DMItemPageViewDataSource ()

@property (nonatomic, strong) DMItemOperation *_operation;

@end

@implementation DMItemPageViewDataSource

- (UIViewController<DMItemDataSourceItem> *)viewControllerAtIndex:(NSUInteger)index
{
    [self._operation cancel];
    self._operation = nil;

    UIViewController<DMItemDataSourceItem> *viewController = self.createViewControllerBlock();
    NSAssert(viewController != nil, @"The createViewControllerBlock must return a valid view controller");

    objc_setAssociatedObject(viewController, &indexKey, [NSNumber numberWithUnsignedInt:index], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [viewController prepareForLoading];
    if ([viewController respondsToSelector:@selector(setItem:)])
    {
        [viewController setItem:nil];
    }

    __weak DMItemPageViewDataSource *wself = self;
    self._operation = [self.itemCollection withItemFields:viewController.fieldsNeeded atIndex:index do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemPageViewDataSource *sself = wself;

        if (error)
        {
            BOOL notify = !sself.lastError; // prevents from error storms
            sself.lastError = error;
            if (notify)
            {
                if ([sself.delegate respondsToSelector:@selector(itemPageViewDataSource:didFailWithError:)])
                {
                    [sself.delegate itemPageViewDataSource:sself didFailWithError:error];
                }
            }
        }
        else
        {
            sself.lastError = nil;
            [viewController setFieldsData:data];

            if ([viewController respondsToSelector:@selector(setItem:)])
            {
                [sself.itemCollection itemAtIndex:index withFields:nil done:^(DMItem *item, NSError *e2)
                {
                    [viewController setItem:item];
                }];
            }
        }
    }];

    return viewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger itemIdx = ((NSNumber *)objc_getAssociatedObject(viewController, &indexKey)).unsignedIntValue;
    UIViewController<DMItemDataSourceItem> *prevViewController = nil;

    if (itemIdx - 1 > 0)
    {
        prevViewController = [self viewControllerAtIndex:itemIdx - 1];
    }

    return prevViewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger itemIdx = ((NSNumber *)objc_getAssociatedObject(viewController, &indexKey)).unsignedIntValue;
    UIViewController<DMItemDataSourceItem> *nextViewController = nil;

    if (itemIdx + 1 < self.itemCollection.currentEstimatedTotalItemsCount)
    {
        nextViewController = [self viewControllerAtIndex:itemIdx + 1];
    }

    return nextViewController;
}

@end
