//
//  DMPickerViewComponent.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/07/12.
//
//

#import "DMItemPickerViewComponent.h"
#import "DMItemPickerLabel.h"
#import "objc/runtime.h"

static char operationKey;

@interface DMItemPickerViewComponent ()

@property (nonatomic, strong) DMItemCollection *itemCollection;
@property (nonatomic, strong) UIView<DMItemDataSourceItem> *(^createRowViewBlock)();
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSMutableArray *operations;

@end

@implementation DMItemPickerViewComponent

- (id)initWithItemCollection:(DMItemCollection *)itemCollection createRowViewBlock:(UIView<DMItemDataSourceItem> *(^)())createRowViewBlock
{
    NSParameterAssert(itemCollection != nil);
    NSParameterAssert(createRowViewBlock != nil);

    self = [super init];
    if (self)
    {
        _itemCollection = itemCollection;
        _createRowViewBlock = createRowViewBlock;
        [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

- (id)initWithItemCollection:(DMItemCollection *)itemCollection withTitleFromField:(NSString *)fieldName
{
    return [self initWithItemCollection:itemCollection createRowViewBlock:^
    {
        return [[DMItemPickerLabel alloc] initWithFieldName:fieldName];
    }];
}

- (void)dealloc
{
    [self cancelAllOperations];
    [self removeObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount"];
    [self removeObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus"];
}

- (void)cancelAllOperations
{
    [self.operations makeObjectsPerformSelector:@selector(cancel)];
    [self.operations removeAllObjects];
}

- (NSInteger)numberOfRows
{
    if (!self.loaded)
    {
        UIView<DMItemDataSourceItem> *view = self.createRowViewBlock();

        __weak DMItemPickerViewComponent *wself = self;
        DMItemOperation *operation = [self.itemCollection withItemFields:view.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
        {
            if (!wself) return;
            __strong DMItemPickerViewComponent *sself = wself;
            if (error)
            {
                sself.lastError = error;
                sself.loaded = NO;
                if ([sself.delegate respondsToSelector:@selector(pickerViewComponent:didFailWithError:)])
                {
                    [sself.delegate pickerViewComponent:sself didFailWithError:error];
                }
            }
        }];
        self.operations = NSMutableArray.array;
        if (!operation.isFinished) // The operation can be synchrone in case the itemCollection was already loaded or restored from disk
        {
            [self.operations addObject:operation];
            [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];

            // Only notify about loading if we have something to load on the network
            if ([self.delegate respondsToSelector:@selector(pickerViewComponentDidUpdateContent:)])
            {
                [self.delegate pickerViewComponentDidUpdateContent:self];
            }
        }
        
        self.loaded = YES;
    }
    return self.itemCollection.currentEstimatedTotalItemsCount;
}

- (UIView *)viewForRow:(NSInteger)row reusingView:(UIView<DMItemDataSourceItem> *)view
{
    if (!view)
    {
        view = self.createRowViewBlock();
    }

    DMItemOperation *previousOperation = objc_getAssociatedObject(view, &operationKey);
    [previousOperation cancel];

    [view prepareForLoading];

    __weak DMItemPickerViewComponent *wself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:view.fieldsNeeded atIndex:row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemPickerViewComponent *sself = wself;

        objc_setAssociatedObject(view, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if (error)
        {
            BOOL notify = !sself.lastError; // prevents from error storms
            sself.lastError = error;
            if (notify)
            {
                if ([sself.delegate respondsToSelector:@selector(pickerViewComponent:didFailWithError:)])
                {
                    [sself.delegate pickerViewComponent:sself didFailWithError:error];
                }
            }
        }
        else
        {
            sself.lastError = nil;
            [view setFieldsData:data];
        }
    }];
    
    if (!operation.isFinished)
    {
        [self.operations addObject:operation];
        [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
        objc_setAssociatedObject(view, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return view;
}

- (void)didSelectRow:(NSInteger)row
{
    __weak DMItemPickerViewComponent *wself = self;
    [self.itemCollection withItemFields:@[@"id"] atIndex:row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        if (!wself) return;
        __strong DMItemPickerViewComponent *sself = wself;

        if (error)
        {
            BOOL notify = !sself.lastError; // prevents from error storms
            sself.lastError = error;
            if (notify)
            {
                if ([sself.delegate respondsToSelector:@selector(pickerViewComponent:didFailWithError:)])
                {
                    [sself.delegate pickerViewComponent:sself didFailWithError:error];
                }
            }
        }
        else
        {
            if ([sself.delegate respondsToSelector:@selector(pickerViewComponent:didSelectItem:)])
            {
                // TODO share the cache of the collection item
                [sself.delegate pickerViewComponent:sself didSelectItem:[DMItem itemWithType:sself.itemCollection.type forId:data[@"id"] fromAPI:sself.itemCollection.api]];
            }
        }
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        if (!self.loaded) return;
        if ([self.delegate respondsToSelector:@selector(pickerViewComponentDidUpdateContent:)])
        {
            [self.delegate pickerViewComponentDidUpdateContent:self];
        }
    }
    else if ([keyPath isEqualToString:@"itemCollection.api.currentReachabilityStatus"] && object == self)
    {
        if (!self.loaded) return;
        DMNetworkStatus previousReachabilityStatus = ((NSNumber *)change[NSKeyValueChangeOldKey]).intValue;
        if (self.itemCollection.api.currentReachabilityStatus != DMNotReachable && previousReachabilityStatus == DMNotReachable)
        {
            // Became recheable: notify table view controller that it should reload table data
            if ([self.delegate respondsToSelector:@selector(pickerViewComponentDidLeaveOfflineMode:)])
            {
                [self.delegate pickerViewComponentDidLeaveOfflineMode:self];
            }
        }
        else if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && previousReachabilityStatus != DMNotReachable)
        {
            if ([self.delegate respondsToSelector:@selector(pickerViewComponentDidEnterOfflineMode:)])
            {
                [self.delegate pickerViewComponentDidEnterOfflineMode:self];
            }
        }
    }
    else if ([keyPath isEqualToString:@"isFinished"])
    {
        if ([object isKindOfClass:DMItemOperation.class] && ((DMItemOperation *)object).isFinished)
        {
            [self.operations removeObject:object];
            [object removeObserver:self forKeyPath:@"isFinished"];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
