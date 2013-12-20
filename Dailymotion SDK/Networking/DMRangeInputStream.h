//
//  DMRangeInputStream.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/07/12.
//
//

#import <Foundation/Foundation.h>

@interface DMRangeInputStream : NSInputStream <NSStreamDelegate>

@property(nonatomic, weak) id <NSStreamDelegate> delegate;

+ (id)inputStreamWithFileAtPath:(NSString *)path withRange:(NSRange)range;

- (id)initWithFileAtPath:(NSString *)path withRange:(NSRange)range;

@end
