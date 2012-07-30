//
//  DMRangeInputStream.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 10/07/12.
//
//

#import "DMRangeInputStream.h"

@interface DMRangeInputStream ()
{
    CFReadStreamClientCallBack copiedCallback;
	CFStreamClientContext copiedContext;
	CFOptionFlags requestedEvents;
    id <NSStreamDelegate> delegate;
}

@property (nonatomic, assign) NSRange _range;
@property (nonatomic, strong) NSInputStream *_parentStream;

@end

@implementation DMRangeInputStream

+ (id)inputStreamWithFileAtPath:(NSString *)path withRange:(NSRange)range
{
    return [[self alloc] initWithFileAtPath:path withRange:range];
}

- (id)initWithFileAtPath:(NSString *)path withRange:(NSRange)range
{
    if ((self = [self init]))
    {
        __parentStream = [[NSInputStream alloc] initWithFileAtPath:path];
        __parentStream.delegate = self;
        self.delegate = self;
        __range = range;
        [self setProperty:@0 forKey:NSStreamFileCurrentOffsetKey];
    }
    return self;
}

- (id <NSStreamDelegate> )delegate
{
    return delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate
{
    if (aDelegate == nil)
    {
		delegate = self;
	}
	else
    {
		delegate = aDelegate;
	}
}

- (void)open
{
    [self._parentStream open];
}

- (void)close
{
    [self._parentStream close];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [self._parentStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [self._parentStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    if (key == NSStreamFileCurrentOffsetKey && self._range.location > 0)
    {
        property = @(((NSNumber *)property).intValue + self._range.location);
    }

    return [self._parentStream setProperty:property forKey:key];
}

- (id)propertyForKey:(NSString *)key
{
    id property = [self._parentStream propertyForKey:key];

    if (key == NSStreamFileCurrentOffsetKey && self._range.location > 0)
    {
        property = @(((NSNumber *)property).intValue - self._range.location);
    }

    return property;
}

- (NSStreamStatus)streamStatus
{
    NSStreamStatus status = [self._parentStream streamStatus];

    if (status == NSStreamStatusOpen && ![self hasBytesAvailable])
    {
        status = NSStreamStatusAtEnd;
    }

    return status;
}

- (NSError *)streamError
{
    return [self._parentStream streamError];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    NSInteger pos = ((NSNumber *)[self propertyForKey:NSStreamFileCurrentOffsetKey]).intValue;
    if (pos + len > self._range.length)
    {
        len = self._range.length - pos;
        if (len == 0) return 0;
    }
    return [self._parentStream read:buffer maxLength:len];
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    return NO;
}

- (BOOL)hasBytesAvailable
{
    if (![self._parentStream hasBytesAvailable])
    {
        return NO;
    }

    NSUInteger pos = ((NSNumber *)[self propertyForKey:NSStreamFileCurrentOffsetKey]).unsignedIntegerValue;
    return pos < self._range.length;
}

#pragma mark - Undocumented CFReadStream bridged methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
    CFReadStreamScheduleWithRunLoop((__bridge CFReadStreamRef)self._parentStream, runLoop, mode);
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)flags callback:(CFReadStreamClientCallBack)callback context:(CFStreamClientContext *)context
{
	if (callback != NULL)
    {
		requestedEvents = flags;
		copiedCallback = callback;
		memcpy(&copiedContext, context, sizeof(CFStreamClientContext));

		if (copiedContext.info && copiedContext.retain)
        {
			copiedContext.retain(copiedContext.info);
		}
	}
	else
    {
		requestedEvents = kCFStreamEventNone;
		copiedCallback = NULL;
		if (copiedContext.info && copiedContext.release)
        {
			copiedContext.release(copiedContext.info);
		}

		memset(&copiedContext, 0, sizeof(CFStreamClientContext));
	}

	return YES;
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
	CFReadStreamUnscheduleFromRunLoop((__bridge CFReadStreamRef)self._parentStream, runLoop, mode);
}

#pragma mark NSStreamDelegate methods

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	assert(stream == self._parentStream);

	switch (eventCode)
    {
		case NSStreamEventOpenCompleted:
			if (requestedEvents & kCFStreamEventOpenCompleted)
            {
				copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventOpenCompleted, copiedContext.info);
			}
			break;

		case NSStreamEventHasBytesAvailable:
			if (requestedEvents & kCFStreamEventHasBytesAvailable)
            {
				copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventHasBytesAvailable, copiedContext.info);
			}
			break;

		case NSStreamEventErrorOccurred:
			if (requestedEvents & kCFStreamEventErrorOccurred)
            {
				copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventErrorOccurred, copiedContext.info);
			}
			break;

		case NSStreamEventEndEncountered:
			if (requestedEvents & kCFStreamEventEndEncountered)
            {
				copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventEndEncountered, copiedContext.info);
			}
			break;

		case NSStreamEventHasSpaceAvailable:
			// This doesn't make sense for a read stream
			break;

		default:
			break;
	}
}

@end
