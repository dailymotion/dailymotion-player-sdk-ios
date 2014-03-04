//
//  DMAPIMergedCall.h
//  Dailymotion SDK
//
//  Created by Fabrice Aneche on 24/02/14.
//
//

#import "DMAPICall.h"

/*
 * DMAPIMergedCall is a containers object used to merge (almost) identical calls but different fields
 * It keeps track of the real call
 */
@interface DMAPIMergedCall : DMAPICall

@property (nonatomic, strong) NSMutableArray *calls;

/*
 * Create a new merged call with an already existing call 
 */
- (id)initWithCall:(DMAPICall *)call;

/*
 * Add a mergeable call (Merge) to this call
 */
- (void)addCall:(DMAPICall *)call;

@end
