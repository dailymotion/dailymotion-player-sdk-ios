//
//  DMBoundableInputStream.m
//  Dailymotion
//
//  Created by Olivier Poitrey on 15/10/10.
//  Copyright 2010 Dailymotion. All rights reserved.
//

#import "DMBoundableInputStream.h"

#define min(a,b) ((a) < (b) ? (a) : (b))

@implementation DMBoundableInputStream
{
    NSData *headData;
    NSData *tailData;
    NSUInteger headLength;
    NSUInteger tailLength;
    NSUInteger deliveredLength;
    NSUInteger tailPosition;
}

- (void)setHeadData:(NSData *)newHeadData
{
    if (headData != newHeadData)
    {
        headData = newHeadData;
        headLength = [headData length];
    }
}

- (NSData *)headData
{
    return headData;
}

- (void)setTailData:(NSData *)newTailData
{
    if (tailData != newTailData)
    {
        tailData = newTailData;
        tailLength = [tailData length];
    }
}

- (NSData *)tailData
{
    return tailData;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)maxLength
{
    NSUInteger sentLength = 0, readLength = 0;

    if (![self hasBytesAvailable])
    {
        return 0;
    }
    if (deliveredLength < headLength && sentLength < maxLength)
    {
        readLength = min(headLength - deliveredLength, maxLength - sentLength);
        [headData getBytes:buffer range:NSMakeRange(deliveredLength, readLength)];
        sentLength += readLength;
        deliveredLength += sentLength;
    }
    if (sentLength < maxLength && deliveredLength >= headLength && tailPosition == 0)
    {
        readLength = [self.middleStream read:buffer + sentLength maxLength:maxLength - sentLength];
        sentLength += readLength;
        deliveredLength += readLength;
    }
    if (sentLength < maxLength && tailPosition == 0)
    {
        tailPosition = deliveredLength;
    }
    if (sentLength < maxLength && deliveredLength - tailPosition < tailLength)
    {
        readLength = min(tailLength - (deliveredLength - tailPosition), maxLength - sentLength);
        [tailData getBytes:buffer + sentLength range:NSMakeRange(deliveredLength - tailPosition, readLength)];
        sentLength += readLength;
        deliveredLength += readLength;
    }

    return sentLength;
}

- (BOOL)hasBytesAvailable
{
    if ([self.middleStream hasBytesAvailable])
    {
        return YES;
    }
    else
    {
        if (tailPosition > 0)
        {
            return deliveredLength - tailPosition < tailLength;
        }
        else
        {
            return tailLength > 0;
        }
    }
}

- (void)open
{
    [self.middleStream open];
}

- (void)close
{
    [self.middleStream close];
}

- (id <NSStreamDelegate>)delegate
{
    return [self.middleStream delegate];
}

- (void)setDelegate:(id <NSStreamDelegate>)delegate
{
    [self.middleStream setDelegate:delegate];
}

- (id)propertyForKey:(NSString *)key
{
    return [self.middleStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return [self.middleStream setProperty:property forKey:key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [self.middleStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [self.middleStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (NSStreamStatus)streamStatus
{
    return [self.middleStream streamStatus];
}

- (NSError *)streamError
{
    return [self.middleStream streamError];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [self.middleStream methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:self.middleStream];
}

@end
