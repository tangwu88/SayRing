//
//  QCHRVSampleModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/7/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One HRV sample with an absolute timestamp (same idea as QCPressureSampleModel).
/// 一条带绝对时间戳的 HRV 采样（与 QCPressureSampleModel 相同思路）。
@interface QCHRVSampleModel : NSObject

/// Absolute sample time (local calendar, derived from day start + index * interval).
/// 绝对采样时间（本地日历，由当天起点 + 下标 × 间隔得出）。
@property (nonatomic, strong) NSDate *time;

/// Unix seconds for `time` (since 1970-01-01).
/// `time` 对应的 Unix 秒（自 1970-01-01 起）。
@property (nonatomic, assign) uint32_t unixTimestamp;

/// HRV value in milliseconds. 0 means no valid reading at this slot.
/// HRV 值，单位：毫秒。0 表示该槽位无有效读数。
@property (nonatomic, assign) NSInteger value;

+ (instancetype)sampleWithUnixTimestamp:(uint32_t)unixTimestamp value:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END
