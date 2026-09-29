//
//  QCRealOneKeyMeasureHeartRateModel.h
//  QCBandSDK
//
//  Created by steve on 2024/2/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCRealOneKeyMeasureHeartRateModel : NSObject

/// Heart rate, unit: bpm.
/// 心率，单位：次/分钟。
@property (nonatomic, assign) NSInteger heartRateValue;

/// Heart rate variability, unit: ms.
/// 心率变异性，单位：毫秒。
@property (nonatomic, assign) NSInteger heartRateHRV;

/// Stress level (0-100).
/// 压力值（0-100）。
@property (nonatomic, assign) NSInteger stress;

/// RR interval in ms, updated every second.
/// RR 间期，单位：毫秒，每秒更新。
@property (nonatomic, assign) NSInteger rri;

/// Temperature in 0.1°C units.
/// 体温，单位：0.1℃。
@property (nonatomic, assign) NSInteger temp;

/// Systolic blood pressure, unit: mmHg.
/// 收缩压，单位：mmHg。
@property (nonatomic, assign) NSInteger bloodPressureSbp;

/// Diastolic blood pressure, unit: mmHg.
/// 舒张压，单位：mmHg。
@property (nonatomic, assign) NSInteger bloodPressureDbp;

@end

NS_ASSUME_NONNULL_END
