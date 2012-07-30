//
//  DMTestUtils.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 18/06/12.
//
//

#import <Foundation/Foundation.h>

#define INIT(plannedTests) \
    NSUInteger currentTotalRequestCount = [DMNetworking totalRequestCount]; \
    long waitResult; \
    __block NSInteger testCount = plannedTests; \
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); \
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:100];
#define REINIT(plannedTests) \
    currentTotalRequestCount = [DMNetworking totalRequestCount]; \
    testCount = plannedTests; \
    semaphore = dispatch_semaphore_create(0);
#define DONE \
    if (--testCount == 0) dispatch_semaphore_signal(semaphore);
#define WAIT \
    while ((waitResult = dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) && loopUntil.timeIntervalSinceNow > 0) \
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil]; \
    dispatch_release(semaphore); \
    STAssertTrue(waitResult == 0, @"All callbacks are done"); \
    if (currentTotalRequestCount) {}; // prevent unused var warning

#define networkRequestCount [DMNetworking totalRequestCount] - currentTotalRequestCount
