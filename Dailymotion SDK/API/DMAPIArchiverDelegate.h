//
//  DMAPIArchiverDelegate.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 05/07/12.
//
//

#import <Foundation/Foundation.h>
#import "DMAPI.h"

/*
 * Class to be used as delegate of `NSKeyedArchiver` and `NSKeyedUnarchiver` to archive object tree containing
 * `DMAPI` instances with a proxy object to replaced by the current instance on unarchiving.
 */
@interface DMAPIArchiverDelegate : NSObject <NSKeyedArchiverDelegate, NSKeyedUnarchiverDelegate>

@property (nonatomic, readonly, strong) DMAPI *api;

- (id)initWithAPI:(DMAPI *)api;

@end
