//
//  CE_ProductProtocol.h
//  CE_BleSDK
//
//  Created by LiJie on 2017/3/3.
//  Copyright © 2017年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BluetoothLibrary/FuncType.h>

@protocol CE_Protocol <NSObject>

/**
 K2 K6构造发送消息的方法。如果有新的协议，需要增加新协议发送消息的构造方法
 
 @param body 消息体
 @param funcType 功能类型
 @param number K2 K6用到的命令流水号
 @param header 构造的消息头
 @return 整个消息包括包头和消息体等
 */
- (NSData *)constructData:(NSData *)body funcType:(K6_DataFuncType)funcType cmdType:(K6_CMD_TYPE)cmdType searialNumber:(long)number header:(NSData **)header;

/**
 验证接收消息的结果
 
 @param dataItems 已经接收到的消息数据
 @param receiveData 此次接收到的消息数据
 @return CheckReceiveType
 */
- (CheckReceiveType)checkReceiveData:(NSArray *)dataItems newData:(NSData *)receiveData;

/**  解析后的 结果，（正确 或者 错误） */
- (ParseType)parseReceiveData:(NSArray *)dataItems checkType:(CheckReceiveType)checkType result:(id *)result header:(NSData **)header;

/**  生成应答 数据包。 */
- (NSData *)generateAckDataBy:(NSArray *)dataItems parseRet:(ParseType)parseType;

/**  匹配，发送的包头 和 收到的包头是否一致 */
- (BOOL)isMatch:(NSData *)sendHeader receiveHeader:(NSData *)receiveHeader;

@end


