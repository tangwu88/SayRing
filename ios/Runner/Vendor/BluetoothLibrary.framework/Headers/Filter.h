//
//  WatchFilter.h
//  BluetoothLibrary
//
//  Created by coolwear on 2022/5/31.
//  Copyright © 2022 kwan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Filter : NSObject

// 获取合法的设备
+ (NSArray *)legalPeripherals:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
