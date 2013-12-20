//
//  DMAPITransfer.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/07/12.
//
//

#import "DMAPITransfer.h"

@interface DMAPITransfer ()

@property(nonatomic, readwrite) NSURL *localURL;
@property(nonatomic, readwrite) NSURL *remoteURL;
@property(nonatomic, strong) void (^cancelBlock)();
@property(nonatomic, strong) void (^completionHandler)(id result, NSError *error);

@end

@implementation DMAPITransfer

- (id)init {
    self = [super init];
    if (self) {
        // Create universally unique identifier
        CFUUIDRef uuidObject = CFUUIDCreate(kCFAllocatorDefault);
        _sessionId = (__bridge_transfer NSString *) CFUUIDCreateString(kCFAllocatorDefault, uuidObject);
        CFRelease(uuidObject);
        _localURL = nil;
        _remoteURL = nil;
        _cancelBlock = ^{
        }; // no-op by default
        _totalBytesExpectedToTransfer = 0;
        _totalBytesTransfered = 0;
        _cancelled = NO;
        _finished = NO;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self) {
        _sessionId = [coder decodeObjectForKey:@"sessionId"];
        _localURL = [coder decodeObjectForKey:@"localURL"];
        _remoteURL = [coder decodeObjectForKey:@"remoteURL"];
        _totalBytesExpectedToTransfer = [coder decodeIntegerForKey:@"totalBytesExpectedToTransfer"];
        _totalBytesTransfered = [coder decodeIntegerForKey:@"totalBytesTransfered"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_sessionId forKey:@"sessionId"];
    [coder encodeObject:_localURL forKey:@"localURL"];
    [coder encodeObject:_remoteURL forKey:@"remoteURL"];
    [coder encodeInteger:_totalBytesExpectedToTransfer forKey:@"totalBytesExpectedToTransfer"];
    [coder encodeInteger:_totalBytesTransfered forKey:@"totalBytesTransfered"];
    // Do not store cancelled/finished flags so transfer can safely be cancelled, stored, fetched then resumed
}

- (void)setFinished:(BOOL)finished {
    if (finished) {
        self.cancelBlock = ^{
        };
    }
    _finished = finished;
}

- (void)cancel {
    if (self.finished) return;
    self.cancelBlock();
    _cancelBlock = ^{
    };
    self.cancelled = YES;
    self.finished = YES;
}

@end
