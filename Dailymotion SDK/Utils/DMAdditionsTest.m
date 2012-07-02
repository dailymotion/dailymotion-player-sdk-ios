//
//  DMAdditionsTest.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 03/07/12.
//
//

#import "DMAdditionsTest.h"
#import "DMAdditions.h"

@implementation DMAdditionsTest

#pragma mark - NSDictionary additions

- (void)testDictionaryForKeys
{
    NSDictionary *subdict = [@{@"a":@"b", @"c": @"d", @"e": @"f"} dictionaryForKeys:@[@"a", @"e"]];
    NSDictionary *expectedDict = @{@"a": @"b", @"e": @"f"};
    STAssertEqualObjects(subdict, expectedDict, @"Extracted expected keys");
}

- (void)testAllMissingKeysForKeys
{
    NSArray *missingKeys = [@{@"a":@"b", @"c": @"d", @"e": @"f"} allMissingKeysForKeys:@[@"-", @"a", @"e", @"b", @"g"]];
    NSArray *expectedMissingKeys = @[@"b", @"g", @"-"];
    STAssertEqualObjects(missingKeys, expectedMissingKeys, @"Returned expected keys");

}

- (void)testObjectsForExistingKeys
{
    NSArray *existingObjects = [@{@"a":@"b", @"c": @"d", @"e": @"f"} objectsForExistingKeys:@[@"-", @"a", @"e", @"b", @"g"]];
    NSArray *expectedObjects = @[@"b", @"f"];
    STAssertEqualObjects(existingObjects, expectedObjects, @"Returned only existing objects");
}

#pragma mark - NSArray additions

- (void)testObjectsInRange
{
    NSArray *objects = [@[@"a", @"b", @"c"] objectsInRange:NSMakeRange(0, 3) notFoundMarker:[NSNull null]];
    NSArray *excpetedObjects = @[@"a", @"b", @"c"];
    STAssertEqualObjects(objects, excpetedObjects, @"Returned objects in range");

    objects = [@[@"a", @"b", @"c"] objectsInRange:NSMakeRange(1, 3) notFoundMarker:[NSNull null]];
    excpetedObjects = @[@"b", @"c", [NSNull null]];
    STAssertEqualObjects(objects, excpetedObjects, @"Returned objects in range + marker on missing");

    objects = [@[@"a", @"b", @"c"] objectsInRange:NSMakeRange(1, 1) notFoundMarker:[NSNull null]];
    excpetedObjects = @[@"b"];
    STAssertEqualObjects(objects, excpetedObjects, @"Returned only objects in range");

    objects = [@[@"a", @"b", @"c"] objectsInRange:NSMakeRange(1, 0) notFoundMarker:[NSNull null]];
    excpetedObjects = @[];
    STAssertEqualObjects(objects, excpetedObjects, @"Returned empty array if range is zero length");
}

#pragma mark - NSMutableArray additions

- (void)testReplaceObjectsInRange
{
    NSMutableArray *mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray replaceObjectsInRange:NSMakeRange(1, 2) withObjectsFromArray:@[@"1", @"2"] fillWithObject:[NSNull null]];
    NSArray *expectedArray = @[@"a", @"1", @"2"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Replaced objects in range");

    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray replaceObjectsInRange:NSMakeRange(2, 2) withObjectsFromArray:@[@"1", @"2"] fillWithObject:[NSNull null]];
    expectedArray = @[@"a", @"b", @"1", @"2"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Replaced objects in range and added missing idx");

    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray replaceObjectsInRange:NSMakeRange(5, 2) withObjectsFromArray:@[@"1", @"2"] fillWithObject:[NSNull null]];
    expectedArray = @[@"a", @"b", @"c", [NSNull null], [NSNull null], @"1", @"2"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Replaced objects in range filling gap with marker");

    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray replaceObjectsInRange:NSMakeRange(0, 2) withObjectsFromArray:@[@"1"] fillWithObject:[NSNull null]];
    expectedArray = @[@"1", @"c"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Replaced objects in range with less objects, shrinking array");
}

- (void)testRaiseWithObject
{
    NSMutableArray *mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray raise:5 withObject:@"-"];
    NSArray *expectedArray = @[@"a", @"b", @"c", @"-", @"-"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Raised array to given size");

    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray raise:3 withObject:@"-"];
    expectedArray = @[@"a", @"b", @"c"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Array untouched if already sized");

    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray raise:1 withObject:@"-"];
    expectedArray = @[@"a", @"b", @"c"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Array untouched if raise size lower than current array size");
}

- (void)testShrink
{
    NSMutableArray *mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray shrink:2];
    NSArray *expectedArray = @[@"a", @"b"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Shrinked array to given size");
    
    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray shrink:3];
    expectedArray = @[@"a", @"b", @"c"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Array untouched if already sized");
    
    mutableArray = [NSMutableArray arrayWithObjects:@"a", @"b", @"c", nil];
    [mutableArray shrink:5];
    expectedArray = @[@"a", @"b", @"c"];
    STAssertEqualObjects(mutableArray, expectedArray, @"Array untouched if shrink size greater than current array size");
}

@end
