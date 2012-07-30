//
//  DMAPITransfer.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/07/12.
//
//

#import "DMAPITransfer.h"

@interface DMAPITransfer ()

@property (nonatomic, readwrite) NSURL *localURL;
@property (nonatomic, readwrite) NSURL *remoteURL;
@property (nonatomic, strong) void (^cancelBlock)();
@property (nonatomic, strong) void (^completionHandler)(id result, NSError *error);

@end

@implementation DMAPITransfer

- (id)init
{
    if ((self = [super init]))
    {
        // Create universally unique identifier
        CFUUIDRef uuidObject = CFUUIDCreate(kCFAllocatorDefault);
        _sessionId = (__bridge NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuidObject);
        CFRelease(uuidObject);
        _localURL = nil;
        _remoteURL = nil;
        _cancelBlock = ^{}; // no-op by default
        _totalBytesExpectedToTransfer = 0;
        _totalBytesTransfered = 0;
        _cancelled = NO;
        _finished = NO;
    }
    return self;
}

- (void)setFinished:(BOOL)finished
{
    if (finished)
    {
        self.cancelBlock = ^{};
    }
    _finished = finished;
}

- (void)cancel
{
    if (self.finished) return;
    self.cancelBlock();
    _cancelBlock = ^{};
    self.cancelled = YES;
    self.finished = YES;
}

@end
