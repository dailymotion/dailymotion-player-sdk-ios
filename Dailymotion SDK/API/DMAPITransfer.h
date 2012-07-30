//
//  DMAPITransfer.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/07/12.
//
//

#import <Foundation/Foundation.h>

@interface DMAPITransfer : NSObject

@property (nonatomic, readonly) NSString *sessionId;
@property (nonatomic, readonly) NSURL *localURL;
@property (nonatomic, readonly) NSURL *remoteURL;
@property (nonatomic, assign) NSInteger totalBytesTransfered;
@property (nonatomic, assign) NSInteger totalBytesExpectedToTransfer;
@property (nonatomic, strong) void (^progressHandler)(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite);
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL cancelled;

- (void)cancel;

@end
