//
//  CESendObj.h
//  CE_BleSDK
//
//  Created by cxq on 2017/1/12.
//  Copyright © 2017年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BluetoothLibrary/CE_Cmd.h>
#import <BluetoothLibrary/CEProduct.h>
#import <BluetoothLibrary/CE_ProductProtocol.h>

@interface SendingCmd : NSObject

@property (nonatomic,strong) CE_Cmd *cmd;
@property (nonatomic,strong) NSData *header;
@property (nonatomic,assign) int type;//0从头发 1从上次发送的位置重发 2从接下来的位置继续发
@property (nonatomic,assign) int sendTimes;

@end


@protocol CESendDelegate <NSObject>

- (void)didSendCmd:(NSData *)curCmd;

@end


/**
 K6 跟 K2 的处理基本一致
 */
@interface CESendObj : NSObject

@property (nonatomic, strong) NSMutableArray *sendQueue;
@property (nonatomic, strong) SendingCmd *curSendCmd;

@property (nonatomic, weak) id <CESendDelegate> sendDelegate;
@property (nonatomic, weak) id <CE_Protocol> protocol;

- (void)addCmdToSendQueue:(CE_Cmd *)cmd;

- (void)sendAgain;

- (void)sendRemaining;

- (void)finishCmdWithError:(NSError *)error;

- (void)stopCmdQueueWithError:(NSError *)error;

@end
