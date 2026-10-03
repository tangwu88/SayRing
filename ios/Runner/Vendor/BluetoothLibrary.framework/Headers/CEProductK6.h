//
//  CEProductK6.h
//  CE_BleSDK
//
//  Created by cxq on 2017/1/3.
//  Copyright © 2017年 celink. All rights reserved.
//

#import <BluetoothLibrary/CEProduct.h>

/**  ========Start & End========== */
#import <BluetoothLibrary/CE_SyncPairOKCmd.h>
#import <BluetoothLibrary/CE_SystemPairCmd.h>
#import <BluetoothLibrary/CE_SensorCmd.h>
#import <BluetoothLibrary/CE_AppExitCmd.h>

/**  ========Request========== */
#import <BluetoothLibrary/CE_RequestSystemPairStatusCmd.h>
#import <BluetoothLibrary/CE_RequestOTAStatusCmd.h>

#import <BluetoothLibrary/CE_RequestUserInfo.h>
#import <BluetoothLibrary/CE_RequestDevInfoCmd.h>
#import <BluetoothLibrary/CE_RequestBatteryCmd.h>
#import <BluetoothLibrary/CE_RequestAlarmInfoCmd.h>
#import <BluetoothLibrary/CE_RequestAllInfoCmd.h>
#import <BluetoothLibrary/CE_RequestSettingButtonFunCmd.h>
#import <BluetoothLibrary/CE_RequestLongSitCmd.h>
#import <BluetoothLibrary/CE_RequestDisturbCmd.h>
#import <BluetoothLibrary/CE_RequestGoalCmd.h>
#import <BluetoothLibrary/CE_RequestBloodPresureCmd.h>
#import <BluetoothLibrary/YD_RequestWatchFaceSettingCmd.h>

/**  ======== Set & Send========== */
#import <BluetoothLibrary/CE_SyncUserInfoCmd.h>
#import <BluetoothLibrary/CE_SyncSettingK6Cmd.h>
#import <BluetoothLibrary/CE_SyncAlarmK6Cmd.h>
#import <BluetoothLibrary/CE_SyncTimeCmd.h>
#import <BluetoothLibrary/CE_UnitSettingCmd.h>
//电话 短信 通知---
#import <BluetoothLibrary/CE_SyncWeatherCmd.h>
#import <BluetoothLibrary/CE_SyncHybridCmd.h>
#import <BluetoothLibrary/CE_SendPhotoCmd.h>
//发现手机---
#import <BluetoothLibrary/CE_SyncGoalCmd.h>
#import <BluetoothLibrary/CE_SyncWatchMenuCmd.h>//消息推送选项 和 表盘菜单选择
#import <BluetoothLibrary/CE_SendOtaDataCmd.h>
#import <BluetoothLibrary/CE_SyncMusicInfoCmd.h>
//GPS
#import <BluetoothLibrary/CE_SyncGpsArgumentCmd.h>
#import <BluetoothLibrary/CE_SyncLongSitRemindCmd.h>
#import <BluetoothLibrary/CE_SyncPhoneControlCmd.h>
#import <BluetoothLibrary/CE_SyncDisturbCmd.h>

#import <BluetoothLibrary/YD_SyncSMSAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncCallAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncFinishGoalCmd.h>
#import <BluetoothLibrary/YD_SyncDrinkAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncUpBrightCmd.h>
#import <BluetoothLibrary/YD_SyncAutoHeartCmd.h>
#import <BluetoothLibrary/YD_SyncFindDevCmd.h>
#import <BluetoothLibrary/YD_SyncLanguageCmd.h>

#import <BluetoothLibrary/CE_SyncHeartO2Cmd.h>
#import <BluetoothLibrary/CE_SyncECGCmd.h>
#import <BluetoothLibrary/CE_SyncBloodPressureCmd.h>
#import <BluetoothLibrary/CE_SyncRRIHRVCmd.h>

#import <BluetoothLibrary/YD_SyncFaceIndexCmd.h>
#import <BluetoothLibrary/CE_SyncSystemFaceDataCmd.h>
#import <BluetoothLibrary/CE_SyncCustomFaceCmd.h>
#import <BluetoothLibrary/CE_SendMotionCmd.h>


/**  蓝牙状态改变，非关闭。都会自动发送一次自动重连（有UUID 才能连上） */
/**
 第一次连接，自动发送 确认配对命令。设备需要 点击确认
 第二次（已保存UUID）连接，自动发送确认命令，设备不需要 再点击确认。
 
 --确认配对 后，自动发送： 1.打开数据开关命令 、 2.系统配对命令、 3.同步时间命令、 4.设备信息、5.OTA状态*/


/**  设备侧发过来的 数据通过通知 获取userInfo
 数据格式：@{  @"DataType":                NSNumber,    数据类型
 @"DataType_Description":    NSString,    对应数据类型的解释
 @"error_msg":               NSString,    错误信息，没有错误则为空
 @"Data":                    NSDictionary 具体的 数据。
 }
 */
extern NSString *const CEProductK6ReceiveDataNoticeKey;

@interface CEProductK6 : CEProduct

// 产品ID号，区分不同产品,读取 pid 需要在收到数据的通知之后
// 悦动设备 1-F618 ，2-F818
@property (nonatomic, assign) NSInteger pid;

@property (nonatomic, assign) CBManagerState state;

@property (nonatomic, copy) void (^receiveOriginalDataHandler)(NSData *data); // the received original Bluetooth data
@property (nonatomic, copy) void (^sendOriginalDataHandler)(NSData *data); // the send original Bluetooth data
@property (nonatomic, copy) void (^connectStatusChanged)(ProductStatus status); // the connnection status

+ (instancetype)shareInstance;

//发送各种命令,并加入到队列(收到应答才发队列中的下个命令)
- (void)sendCmdToDevice:(CE_Cmd *)cmd complete:(CECmdErrorBlock)handler;

/// 清空cmd队列
- (void)cleanCmdQueue;

@end







