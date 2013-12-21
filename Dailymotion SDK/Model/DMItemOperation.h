//
//  DMItemOperation.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 18/06/12.
//
//

#import <Foundation/Foundation.h>

/**
 * Cancellable operation performed on a DMItem (NOTE: it's not a valid NSOperation).
 */
@interface DMItemOperation : NSObject

/**
 * Defines tells if the operation is completed.
 *
 * Only the owner of the operation should change this property.
 */
@property (nonatomic, assign) BOOL isFinished;

/**
 * Defines if the operation has been cancelled.
 *
 * Only the owner of the operation should change this property.
 */
@property (nonatomic, assign) BOOL isCancelled;

/**
 * Cancels the operation.
 *
 * Call this method to cancel the operation.
 */
- (void)cancel;

@end
