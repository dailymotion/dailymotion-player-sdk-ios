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

/**
 * Call queue for DMAPI used to handle aggregated calls queuing and tracking. SDK users shouldn't have to use this class directly.
 */
@interface DMAPICallQueue : NSObject

@property(nonatomic, assign) NSUInteger count;

/**
 * Queue an API call and return a DMAPICall object
 *
 * @param path The requested API ressource path.
 * @param method The API HTTP method used.
 * @param args Arguments for the call
 * @param cacheInfo The conditional request DMAPICacheInfo object if any
 * @param callback The callback to be called once call is completed
 */
- (DMAPICall *)addCallWithPath:(NSString *)path method:(NSString *)method args:(NSDictionary *)args cacheInfo:(DMAPICacheInfo *)cacheInfo callback:(DMAPICallResultBlock)callback;

/**
 * Retrieve a DMAPICall object by its call id
 *
 * @param callId The id for the call to retrieve.
 */
- (DMAPICall *)callWithId:(NSString *)callId;

/**
 * Remove a DMAPICall object from the queue by its call id
 *
 * @param callId The id for the call to remove.
 *
 * @return The removed DMAPICall object if successfuly dequeued or nil if call id wasn't found in the queue
 */
- (DMAPICall *)removeCallWithId:(NSString *)callId;

/**
 * Remove a given DMAPICall object from the queue
 *
 * @param call The DMAPICall object to remove from the queue.
 */
- (BOOL)removeCall:(DMAPICall *)call;


/**
 * Flag an API call as handled by a given object. An object can't be handled by
 * more than one object at a time. If the call is already handled, `NO` is returned.
 *
 * @param call The call object to handle.
 * @param handler The handler to associate with the call.
 */
- (BOOL)handleCall:(DMAPICall *)call withHandler:(id)handler;

/**
 * Inform the queue that a call is no longer handled
 *
 * @param call The call to be unhandled.
 */
- (void)unhandleCall:(DMAPICall *)call;

/**
 * Get the handler object for a particular API call if any
 *
 * @param call The call to get handler for.
 */
- (id)handlerForCall:(DMAPICall *)call;

/**
 * Get all handlers with the given kind
 *
 * @param kind The class of the handler to filter on.
 */
- (NSSet *)handlersOfKind:(Class)kind;

/**
 * Ask the queue if there is some API call not yet handled
 */
- (BOOL)hasUnhandledCalls;

/**
 * Get all API calls handled by a given object
 *
 * @param handler The handler to filter on.
 */
- (NSArray *)callsWithHandler:(id)handler;

/**
 * Get all API calls with no handler set
 */
- (NSArray *)callsWithNoHandler;

@end
