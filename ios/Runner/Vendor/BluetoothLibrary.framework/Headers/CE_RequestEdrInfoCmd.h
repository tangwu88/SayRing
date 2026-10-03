//
//  CE_RequestEdrInfo.h
//  BluetoothLibrary
//
//  Created by coolwear on 2022/7/5.
//  Copyright © 2022 kwan. All rights reserved.
//
//  获取通话蓝牙mac地址和蓝牙名字

#import <BluetoothLibrary/CE_Cmd.h>

NS_ASSUME_NONNULL_BEGIN

@interface CE_RequestEdrInfoCmd : CE_Cmd

+ (void)getEdrInfo:(CECmdErrorBlock)block;

@end

NS_ASSUME_NONNULL_END
