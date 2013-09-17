//
//  DMAdditions.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DMDictionnaryOption)
{
    DMDictionaryOptionFilterNullValues = 1
} ;

/**
 * Some useful additions to NSDictionary.
 */
@interface NSDictionary(DMAdditions)

/**
 * Return a new NSDictionnary with only the given keys if they are present
 *
 * Keys which are missing in the current dictionnary are omitted in the returned dictionnary.
 *
 * @param keys The keys to be returned in the result dictionnary
 *
 * @return An NSDictionnary containing a subset of the current dictionnary containing only the given keys if present
 */
- (NSDictionary *)dictionaryForKeys:(NSArray *)keys;

- (NSDictionary *)dictionaryForKeys:(NSArray *)keys options:(DMDictionnaryOption)options;

/**
 * Return all given keys which are missing in the current dictionnary
 *
 * @param keys The keys to tested on the current dictionnary
 *
 * @result The list of keys which are not present in the current dictionnary
 */
- (NSArray *)allMissingKeysForKeys:(NSArray *)keys;

/**
 * Return objects for the given keys which are found in the current dictionnary
 *
 * Values for missing keys are just skipped. The result NSArray of values may count
 * less elements than given keys.
 *
 * @param keys The keys for values be returned if present
 *
 * @result An array of values for the given key
 */
- (NSArray *)objectsForExistingKeys:(NSArray *)keys;

@end

/**
 * Some useful additions to NSArray.
 */
@interface NSArray (DMAdditions)

/**
 * Safely return all objects in given range
 *
 * If the given range is out of bound, missing indices are replaced in the result
 * by a given `marker` object.
 *
 * @param range The range to get objects in
 * @param marker The object to be used for out of bound values
 *
 * @return An array of the size of the `range.length` containing objects for that range in the receiver
 */
- (NSArray *)objectsInRange:(NSRange)range notFoundMarker:(id)marker;

@end

/**
 * Some useful additions to NSMutableArray.
 */
@interface NSMutableArray (DMAdditions)

/**
 * Safely ramplace objects in a range with some given object
 *
 * If the range is out of bound, the array is raised with the given `filler` object to match the requirement
 *
 * @param range The range of objects to be replaced
 * @param objects The object to be inserted in place of the range
 * @param filler The object to be used to raise the object size in case the given range is out of bound
 */
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray *)objects fillWithObject:(id)filler;

/**
 * Raise the size of the receiver to match the `newSize` and fill new indices with `filler`
 *
 * @param newSize The new expected new size of the receiver, if smaller than current size, receiver isn't touched
 * @param filler The object to be inserted in new created indices
 */
- (void)raise:(NSUInteger)newSize withObject:(id)filler;

/**
 * Shrink the size of the receiver to match `newSize`
 *
 * @param newSize The new expected new size of the receiver
 */
- (void)shrink:(NSUInteger)newSize;

@end