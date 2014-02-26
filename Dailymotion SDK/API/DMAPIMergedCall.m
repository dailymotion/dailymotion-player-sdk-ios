//
//  DMAPIMergedCall.m
//  Dailymotion SDK
//
//  Created by Fabrice Aneche on 24/02/14.
//
//

#import "DMAPIMergedCall.h"

@interface DMAPIMergedCall ()
@property(nonatomic, strong) NSMutableArray *calls;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSDictionary *args;
@end

@implementation DMAPIMergedCall

- (id)init
{
    self = [super init];
    if (self) {
        _calls = [NSMutableArray arrayWithCapacity:2];
    }
    return self;
}

- (void) addCall:(DMAPICall *)call {
    if ([self.calls count] > 0) {
        if (![self isMergeableWith:call] ) return;
        
        //merge args["fields"] if needed
        if (![self.args objectForKey:@"fields"]) {
            
        } else {
            //self.args[@"fields"] = call.args[@"field"];
        }
        
    } else {
        self.path = call.path;
        self.method = call.method;
        self.args = call.args;
    }
}

@end
