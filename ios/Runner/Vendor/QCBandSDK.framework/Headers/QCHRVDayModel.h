//
//  QCHRVDayModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/7/29.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/QCHRVSampleModel.h>

@class QCHRVModel;

NS_ASSUME_NONNULL_BEGIN

/// Unified 5-minute timeline with 288 slots per day.
/// 统一的 5 分钟时间轴，每天固定 288 个槽位。
@interface QCHRVDayModel : NSObject

/// Day string, format "yyyy-MM-dd".
/// 日期字符串，格式 "yyyy-MM-dd"。
@property (nonatomic, strong) NSString *date;

/// Absolute Unix seconds of local day start (00:00:00).
/// 本地当天 00:00:00 的绝对 Unix 秒。
@property (nonatomic, assign) uint32_t timestamp;

/// Timeline slot interval in minutes. Always 5 (288 slots per day).
/// 时间轴槽位间隔（分钟）。固定为 5（每天 288 点）。
@property (nonatomic, assign) NSInteger intervalMinutes;

/// Device-reported storage interval in minutes (e.g. 30 for DS500).
/// 设备上报的原始存储间隔（分钟），例如 DS500 为 30。
@property (nonatomic, assign) NSInteger deviceIntervalMinutes;

/// HRV samples on the 5-minute grid. Index i => time = timestamp + i * 5 * 60.
/// value == 0 means no valid reading.
/// 5 分钟网格上的 HRV 采样。下标 i 对应时间 = timestamp + i × 5 × 60。
/// value == 0 表示该槽位无有效读数。
@property (nonatomic, strong) NSArray<QCHRVSampleModel *> *samples;

/// Build a day model from a legacy raw-array HRV model (SDK internal / migration helper).
/// 从旧版原始数组 HRV 模型构建（SDK 内部 / 迁移辅助）。
+ (instancetype)dayModelFromLegacyHRVModel:(QCHRVModel *)legacy;

/// Build from day fields + raw values.
/// 由日期字段与原始数值构建。
+ (instancetype)dayModelWithDate:(NSString *)date
           deviceIntervalMinutes:(NSInteger)deviceIntervalMinutes
                          values:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
