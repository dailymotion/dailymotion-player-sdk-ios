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
@synthesize middleStream;
@dynamic headData, tailData;

- (void)setHeadData:(NSData *)newHeadData
{
    if (headData != newHeadData)
    {
        [headData release];
        headData = [newHeadData retain];
        headLength = [headData length];
    }
}

- (NSData *)headData
{
    return [[headData retain] autorelease];
}

- (void)setTailData:(NSData *)newTailData
{
    if (tailData != newTailData)
    {
        [tailData release];
        tailData = [newTailData retain];
        tailLength = [tailData length];
    }
}

- (NSData *)tailData
{
    return [[tailData retain] autorelease];
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
        readLength = [middleStream read:buffer + sentLength maxLength:maxLength - sentLength];
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
    if ([middleStream hasBytesAvailable])
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
    [middleStream open];
}

- (void)close
{
    [middleStream close];
}

- (id <NSStreamDelegate>)delegate
{
    return [middleStream delegate];
}

- (void)setDelegate:(id <NSStreamDelegate>)delegate
{
    [middleStream setDelegate:delegate];
}

- (id)propertyForKey:(NSString *)key
{
    return [middleStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return [middleStream setProperty:property forKey:key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [middleStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [middleStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (NSStreamStatus)streamStatus
{
    return [middleStream streamStatus];
}

- (NSError *)streamError
{
    return [middleStream streamError];
}

- (void)dealloc
{
    [headData release];
    [tailData release];
    [middleStream release];
    [super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [middleStream methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:middleStream];
}

@end
