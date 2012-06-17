//
//  DMAdditions.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>

@interface NSDictionary(DMAdditions)

- (NSDictionary *)dictionaryForKeys:(NSArray *)keys;
- (NSArray *)allMissingKeysForKeys:(NSArray *)keys;
- (NSArray *)objectsForExistingKeys:(NSArray *)keys;

@end

@interface NSArray (DMAdditions)

- (NSArray *)objectsInRange:(NSRange)range notFoundMarker:(id)marker;

@end

@interface NSMutableArray (DMAdditions)

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)objects fillWithObject:(id)filler;
- (void)raise:(NSUInteger)newSize withObject:(id)filler;
- (void)shrink:(NSUInteger)newSize;

@end