//
//  DMAPIArchiverDelegate.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 05/07/12.
//
//

#import "DMAPIArchiverDelegate.h"

@interface DMAPIProxy : NSObject <NSCoding>

@end

@implementation DMAPIProxy

- (void)encodeWithCoder:(NSCoder *)coder {
    // do nothing
}

- (id)initWithCoder:(NSCoder *)coder {
    return [super init];
}

@end


@interface DMAPIArchiverDelegate ()

@property (nonatomic, readwrite, strong) DMAPI *api;

@end

@implementation DMAPIArchiverDelegate

- (id)initWithAPI:(DMAPI *)api {
    self = [super init];
    if (self) {
        _api = api;
    }
    return self;
}

- (id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object {
    if ([object isKindOfClass:DMAPI.class]) {
        return [[DMAPIProxy alloc] init];
    }
    return object;
}

- (id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id)object {
    if ([object isKindOfClass:DMAPIProxy.class]) {
        return self.api;
    }
    return object;
}

@end
