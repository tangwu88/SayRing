//
//  QCBloodGlucoseRawModel.h
//  QCBandSDK
//
//  Created by steve on 2024/2/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCBloodGlucoseHeartRateRawModel : NSObject

/// PPG sample count (max 255).
/// PPG 采样点数（最大 255）。
@property (nonatomic, assign) NSInteger ppgCount;

/// Parsed value.
/// 解析后的数值。
@property (nonatomic, assign) NSInteger value;

/// Green-light PPG low byte.
/// 绿灯 PPG 低字节。
@property (nonatomic, assign) NSInteger greenLightPpgL;

/// Green-light PPG high byte.
/// 绿灯 PPG 高字节。
@property (nonatomic, assign) NSInteger greenLightPpgH;

/// X-axis acceleration low byte.
/// X 轴加速度低字节。
@property (nonatomic, assign) NSInteger xAxisL;

/// X-axis acceleration high byte.
/// X 轴加速度高字节。
@property (nonatomic, assign) NSInteger xAxisH;

/// Y-axis acceleration low byte.
/// Y 轴加速度低字节。
@property (nonatomic, assign) NSInteger yAxisL;

/// Y-axis acceleration high byte.
/// Y 轴加速度高字节。
@property (nonatomic, assign) NSInteger yAxisH;

/// Z-axis acceleration low byte.
/// Z 轴加速度低字节。
@property (nonatomic, assign) NSInteger zAxisL;

/// Z-axis acceleration high byte.
/// Z 轴加速度高字节。
@property (nonatomic, assign) NSInteger zAxisH;

/// Measurement time.
/// 测量时间。
@property (nonatomic, strong) NSDate *time;

@end

NS_ASSUME_NONNULL_END
