//
//  QCPressureSampleModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/7/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One pressure sample with an absolute timestamp (same idea as QCTemperatureModel.time).
/// 一条带绝对时间戳的压力采样（与 QCTemperatureModel.time 相同思路）。
@interface QCPressureSampleModel : NSObject

/// Absolute sample time (local calendar, derived from day start + index * interval).
/// 绝对采样时间（本地日历，由当天起点 + 下标 × 间隔得出）。
@property (nonatomic, strong) NSDate *time;

/// Unix seconds for `time` (since 1970-01-01).
/// `time` 对应的 Unix 秒（自 1970-01-01 起）。
@property (nonatomic, assign) uint32_t unixTimestamp;

/// Pressure value. 0 means no valid reading at this slot.
/// 压力值。0 表示该槽位无有效读数。
@property (nonatomic, assign) NSInteger value;

+ (instancetype)sampleWithUnixTimestamp:(uint32_t)unixTimestamp value:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END
