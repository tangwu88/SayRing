//
//  CECharacteristicManager.h
//  BluetoothLibrary
//
//  Created by coolwear on 2023/7/14.
//  Copyright © 2023 kwan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CBCharacteristic, CBPeripheral, CBService;
@interface CECharacteristicManager : NSObject

@property (nonatomic, strong, readonly) CBCharacteristic *charaOfWrite;

- (void)clear;

- (void)readPeripharal:(CBPeripheral *)peripheral service:(CBService *)service;

- (BOOL)listenCompleteWithCharac:(CBCharacteristic *)charac;

@end

NS_ASSUME_NONNULL_END
