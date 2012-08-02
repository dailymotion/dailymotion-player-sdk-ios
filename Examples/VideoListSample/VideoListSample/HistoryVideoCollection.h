//
//  HistoryVideoCollection.h
//  VideoListSample
//
//  Created by Olivier Poitrey on 08/07/12.
//  Copyright (c) 2012 Olivier Poitrey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DailymotionSDK/DailymotionSDK.h>

@interface HistoryVideoCollection : NSObject

+ (void)historyCollectionWithAPI:(DMAPI *)api callback:(void (^)(DMItemLocalCollection *historyVideoCollection)) callback;

@end
