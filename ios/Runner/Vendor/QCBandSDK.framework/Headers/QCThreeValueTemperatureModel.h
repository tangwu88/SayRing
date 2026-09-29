//
//  TemperatureModel.h
//  QCBand
//
//  Created by 曾聪聪 on 2020/4/25.
//  Copyright © 2020 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface QCThreeValueTemperatureModel : NSObject

/// Measurement time.
/// 测量时间。
@property(strong, nonatomic) NSDate *time;

/// First temperature channel, unit: °C.
/// 第一路体温，单位：摄氏度。
@property(assign, nonatomic) Float32 temperature1;

/// Second temperature channel, unit: °C.
/// 第二路体温，单位：摄氏度。
@property(assign, nonatomic) Float32 temperature2;

/// Third temperature channel, unit: °C.
/// 第三路体温，单位：摄氏度。
@property(assign, nonatomic) Float32 temperature3;

+ (instancetype)initWithTime:(NSDate *)time temperature1:(Float32)temperature1  temperature2:(Float32)temperature2  temperature3:(Float32)temperature3;
@end

NS_ASSUME_NONNULL_END
