//
//  DMAPIMergedCall.h
//  Dailymotion SDK
//
//  Created by Fabrice Aneche on 24/02/14.
//
//

#import "DMAPICall.h"

/*
 * DMAPIMergedCall is a containers object used to merge calls (almost) identical but different fields
 * It keeps track of the real call
 */
@interface DMAPIMergedCall : DMAPICall

@property(nonatomic, strong) NSMutableArray *calls;
- (id)initWithCall:(DMAPICall *)call;
- (void) addCall:(DMAPICall *)call;

@end
