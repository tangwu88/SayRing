//
//  SchedualHeartRateModel.h
//  OudmonBandV2
//
//  Created by ZongBill on 2017/11/8.
//  Copyright © 2017年 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QCSchedualHeartRateModel : NSObject

@property (nonatomic, strong) NSString *date;                  // Date, format "yyyy-MM-dd". 日期，格式 "yyyy-MM-dd"
@property (nonatomic, strong) NSArray<NSNumber *> *heartRates; // Heart-rate array, one sample every N minutes. 心率数组，每 N 分钟 1 条
@property (nonatomic, assign) NSInteger secondInterval;        // Data interval, unit: seconds. 数据时间间隔，单位：秒
@property (nonatomic, assign) NSInteger serverID;              // Server id. 服务器 ID
@property (nonatomic, assign) NSInteger updateTime;            // Server update time, unit: ms. 服务器更新时间，单位：毫秒
@property (nonatomic, assign) BOOL isSync;                     // Whether synced to server. 是否已同步服务器
@property (nonatomic, strong) NSString *deviceID;              // Device id, usually MAC. 设备 ID，一般为 Mac 地址
@property (nonatomic, strong) NSString *deviceType;            // Device type, e.g. T90H_V1_0/. 设备类型

@end
