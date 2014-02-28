//
//  DMAPIMergedCall.h
//  Dailymotion SDK
//
//  Created by Fabrice Aneche on 24/02/14.
//
//

#import "DMAPICall.h"

@interface DMAPIMergedCall : DMAPICall

@property(nonatomic, strong) NSMutableArray *calls;
- (id)initWithCall:(DMAPICall *)call;
- (void) addCall:(DMAPICall *)call;

@end
