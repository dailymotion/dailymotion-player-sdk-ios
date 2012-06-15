//
//  NSDictionary+DMAdditions.h
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