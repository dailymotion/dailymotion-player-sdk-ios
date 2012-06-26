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
    if ((self = [super init]))
    {
        _cancelBlock = ^{}; // no-op by default
    }
    return self;
}

- (void)cancel
{
    self.cancelBlock();
}

@end
