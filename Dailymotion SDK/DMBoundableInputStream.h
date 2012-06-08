//
//  DMBoundableInputStream.h
//  Dailymotion
//
//  Created by Olivier Poitrey on 15/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMBoundableInputStream : NSInputStream
{
    @private
    NSData *headData, *tailData;
    NSUInteger headLength, tailLength, deliveredLength, tailPosition;
    NSInputStream *middleStream;
}

@property (nonatomic) NSData *headData, *tailData;
@property (nonatomic) NSInputStream *middleStream;

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL)hasBytesAvailable;

@end
