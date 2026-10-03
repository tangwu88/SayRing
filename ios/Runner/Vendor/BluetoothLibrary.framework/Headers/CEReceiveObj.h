//
//  CEReceiveObj.h
//  CE_BleSDK
//
//  Created by cxq on 2017/1/13.
//  Copyright © 2017年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BluetoothLibrary/CE_ProductProtocol.h>

@protocol CEReceiveDelegate <NSObject>

- (void)didReceiveAck:(ParseType)parseType ackHeader:(NSData *)header;

- (void)didReceiveDataInfo:(NSDictionary *)info ackData:(NSData *)ackData;

@end

@interface CEReceiveObj : NSObject

@property (nonatomic,weak) id <CE_Protocol> protocol;
@property (nonatomic,weak) id <CEReceiveDelegate> receiveDelegate;

/* 在接收蓝牙数据包的过程当中可能会夹杂接收到其它的应答包。
   可能会有数据包里面包含应答包，不会在数据包里面包含数据包或者命令包 */
- (void)receiveData:(NSData *)data;

@end
