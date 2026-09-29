//
//  SleepModel.h
//  OdmLightBle
//
//  Created by ZongBill on 15/8/14.
//  Copyright (c) 2015年 X. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, SLEEPTYPE) {
    SLEEPTYPENONE = 0,    // No data. 无数据
    SLEEPTYPESOBER,       // Awake. 清醒
    SLEEPTYPELIGHT,       // Light sleep. 浅睡
    SLEEPTYPEDEEP,        // Deep sleep. 深睡
    SLEEPTYPEREM,         // REM. 快速眼动
    SLEEPTYPEUNWEARED     // Not wearing. 未佩戴
};

/// Data-position type in 0x44 sleep detail. Raw values match the device protocol.
/// 0x44 睡眠详情的数据位置类型，原始值与设备协议一致。
typedef NS_ENUM(NSInteger, QCSleepDetailDataType) {
    QCSleepDetailDataTypeUnknown = 0,
    QCSleepDetailDataTypeMainSleepBegin = 1,
    QCSleepDetailDataTypeMainSleepEnd = 2,
    QCSleepDetailDataTypeOtherSleepBegin = 3,
    QCSleepDetailDataTypeOtherSleepEnd = 4,
    QCSleepDetailDataTypeSleeping = 5,
    QCSleepDetailDataTypeDefault = QCSleepDetailDataTypeSleeping
};

@interface QCSleepModel : NSObject
@property (nonatomic, assign) SLEEPTYPE type;       // Sleep type. 睡眠类型
@property (nonatomic, strong) NSString *happenDate; // Occurred at, format yyyy-MM-dd HH:mm:ss. 发生时间 yyyy-MM-dd HH:mm:ss
@property (nonatomic, strong) NSString *endTime;    // End time. 结束时间
@property (nonatomic, assign) NSInteger total;      // Interval between start and end, unit: minutes. 开始与结束的时间间隔（单位：分钟）

// 0x27/0x3E new sleep protocol fields.
// 0x27/0x3E 新版睡眠协议字段。
@property (nonatomic, assign) NSInteger start;           // Sleep start minutes from 00:00. 当次睡眠开始分钟数（从 00:00 起算）
@property (nonatomic, assign) NSInteger end;             // Sleep end minutes from 00:00. 当次睡眠结束分钟数（从 00:00 起算）
@property (nonatomic, copy) NSString *dataTypes;         // Comma-separated device sleep states. 逗号分隔的设备睡眠状态
@property (nonatomic, copy) NSString *dataMinutes;       // Duration minutes matching dataTypes. 与 dataTypes 对应的状态持续分钟数
@property (nonatomic, assign) BOOL isMidday;             // YES = from 0x3E nap response. YES 表示来自 0x3E 小睡应答
@property (nonatomic, assign) NSInteger effectiveMinutes; // Effective sleep minutes; segment models use current segment duration. 有效睡眠分钟数；分段模型中为当前段时长


// 0x44 sleep-detail extra fields.
// 0x44 睡眠详情扩展字段。
@property (nonatomic, copy) NSString *sleepQa;                 // Device raw sleep quality. 设备原始睡眠质量
@property (nonatomic, assign) QCSleepDetailDataType dataType; // Position of this detail in the sleep interval. 当前详情在睡眠区间中的位置

+ (SLEEPTYPE)typeWithQuality:(NSInteger)qa;
+ (NSInteger)sleepQualityFromRawValue:(NSInteger)qa;
+ (QCSleepDetailDataType)sleepDataTypeFromRawValue:(NSInteger)qa;
+ (NSInteger)effectiveMinutesFromRawValue:(NSInteger)qa;
/// Compatible historical spelling; new code should use effectiveMinutesFromRawValue:.
/// 兼容历史拼写；新代码请使用 effectiveMinutesFromRawValue:。
+ (NSInteger)effetiveMinutesFromRawValue:(NSInteger)qa;
+ (BOOL)isRawQAValue:(NSInteger)qa;

/// 根据 dataType 和 effectiveMinutes 还原详情的实际开始时间。
/// Restore the actual begin time from dataType and effectiveMinutes.
- (NSString *)realBeginTime;

/// 根据 dataType 和 effectiveMinutes 还原详情的实际结束时间。
/// Restore the actual end time from dataType and effectiveMinutes.
- (NSString *)realEndTime;

/// 返回当前详情实际覆盖的分钟数。
/// Minutes actually covered by this detail.
- (NSInteger)realEffectiveMinutes;

+ (SLEEPTYPE)typeForSleepV2:(NSInteger)val;

+ (NSInteger)sleepDuration:(NSArray<QCSleepModel*>*)sleepModels;
+ (NSInteger)fallAsleepDuration:(NSArray<QCSleepModel*>*)sleepModels;
@end
