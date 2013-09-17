//
//  DMItemOperation.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 18/06/12.
//
//

#import "DMItemOperation.h"

@interface DMItemOperation ()

@property (nonatomic, strong) void (^cancelBlock)();

@end

@implementation DMItemOperation

- (id)init
{
    self = [super init];
    if (self)
    {
        _cancelBlock = ^{}; // no-op by default
        _isCancelled = NO;
        _isFinished = NO;
    }
    return self;
}

- (void)setIsFinished:(BOOL)isFinished
{
    if (isFinished)
    {
        self.cancelBlock = ^{};
    }
    _isFinished = isFinished;
}

- (void)cancel
{
    if (self.isFinished) return;
    self.cancelBlock();
    _cancelBlock = ^{};
    self.isCancelled = YES;
    self.isFinished = YES;
}

@end
