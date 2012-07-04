//
//  NSObject_DMSubscriptingSupport.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 04/07/12.
//
//

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
@interface NSObject (DMSubscriptingSupport)

- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;
- (id)objectForKeyedSubscript:(id)key;

@end
#endif
