//
//  DMAPICallQueue.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 11/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DMAPICall.h"

@class DMAPI;

@interface DMAPICallQueue : NSObject

/**
 * Queue an API call and return a DMAPICall object
 */
- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;

/**
 * Retrieve a DMAPICall object by its call id
 */
- (DMAPICall *)callWithId:(NSString *)callId;

/**
 * Remove a DMAPICall object from the queue by its call id
 *
 * @return The removed DMAPICall object if successfuly dequeued or nil if call id wasn't found in the queue
 */
- (DMAPICall *)removeCallWithId:(NSString *)callId;

/**
 * Remove a given DMAPICall object from the queue
 */
- (BOOL)removeCall:(DMAPICall *)call;


/**
 * Flag an API call as handled by a given object. An object can't be handled by
 * more than one object at a time. If the call is already handled, `NO` is returned.
 */
- (BOOL)handleCall:(DMAPICall *)call withHandler:(id)handler;

/**
 * Inform the queue that a call is no longer handled
 */
- (void)unhandleCall:(DMAPICall *)call;

/**
 * Get the handler object for a particular API call if any
 */
- (id)handlerForCall:(DMAPICall *)call;

/**
 * Ask the queue if there is some API call not yet handled
 */
- (BOOL)hasUnhandledCalls;

/**
 * Get all API calls handled by a given object
 */
- (NSArray *)callsWithHandler:(id)handler;

/**
 * Get all API calls with no handler set
 */
- (NSArray *)callsWithNoHandler;

@end
