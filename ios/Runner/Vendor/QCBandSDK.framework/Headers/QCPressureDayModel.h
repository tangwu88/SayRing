//
//  QCPressureDayModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/7/24.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/QCPressureSampleModel.h>

@class QCOtherDataPressureModel;

NS_ASSUME_NONNULL_BEGIN

/// One day of pressure samples. Each sample already includes absolute time.
/// 一天的压力采样。每条采样已包含绝对时间。
@interface QCPressureDayModel : NSObject

/// Day string, format "yyyy-MM-dd".
/// 日期字符串，格式 "yyyy-MM-dd"。
@property (nonatomic, strong) NSString *date;

/// Absolute Unix seconds of local day start (00:00:00). Not the wire wall-clock timestamp.
/// 本地当天 00:00:00 的绝对 Unix 秒。不是协议上的墙上时钟时间戳。
@property (nonatomic, assign) uint32_t timestamp;

/// Sample interval in minutes (device-reported, typically 5).
/// 采样间隔（分钟），设备上报，通常为 5。
@property (nonatomic, assign) NSInteger intervalMinutes;

/// Timed samples for the whole day. Index i corresponds to time = timestamp + i * intervalMinutes * 60.
/// value == 0 means no valid reading.
/// When device returns dataLength=0, SDK still expands a full-day timeline of zeros (24h / intervalMinutes).
/// 全天定时采样。下标 i 对应时间 = timestamp + i × intervalMinutes × 60。
/// value == 0 表示该槽位无有效读数。
/// 设备返回 dataLength=0 时，SDK 仍会展开全天 0 值时间轴（24h / intervalMinutes）。
@property (nonatomic, strong) NSArray<QCPressureSampleModel *> *samples;

/// Build a day model from a legacy raw-array model (SDK internal / migration helper).
/// Legacy.timestamp may be wire wall-clock Unix; this API converts to absolute local day start for samples.
/// 从旧版原始数组模型构建（SDK 内部 / 迁移辅助）。
/// 旧模型 timestamp 可能是协议墙上时钟 Unix；本接口会换成采样用的本地当天起点。
+ (instancetype)dayModelFromLegacyPressureModel:(QCOtherDataPressureModel *)legacy;

/// Build from day fields + raw values.
/// @param timestamp Wire/protocol wall-clock Unix or absolute day start; resolved via `date` when possible.
/// 由日期字段与原始数值构建。
/// @param timestamp 协议墙上时钟 Unix 或绝对当天起点；尽可能通过 `date` 解析。
+ (instancetype)dayModelWithDate:(NSString *)date
                       timestamp:(uint32_t)timestamp
                 intervalMinutes:(NSInteger)intervalMinutes
                          values:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
