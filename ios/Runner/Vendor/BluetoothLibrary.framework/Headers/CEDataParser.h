//
//  CEDataParser.h
//  BluetoothLibrary
//
//  Created by coolwear on 2023/7/20.
//  Copyright © 2023 kwan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CEDataParser : NSObject

+ (NSArray *)handleSleepData:(UInt8 *)bytes;
+ (NSArray *)test;
+ (NSArray *)test1;
+ (NSArray *)test2;
+ (NSArray *)test3;


@end

NS_ASSUME_NONNULL_END
