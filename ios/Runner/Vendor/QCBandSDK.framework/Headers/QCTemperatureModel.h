//
//  TemperatureModel.h
//  QCBand
//
//  Created by 曾聪聪 on 2020/4/25.
//  Copyright © 2020 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, TemperatureType) {
    TemperatureTypeSchedual,  // Scheduled measurement. 定时测量
    TemperatureTypeManual,    // Manual measurement. 手动测量
};

NS_ASSUME_NONNULL_BEGIN

@interface QCTemperatureModel : NSObject

/// Measurement time.
/// 测量时间。
@property(strong, nonatomic) NSDate *time;

/// Body temperature in °C.
/// 体温，单位：摄氏度。
@property(assign, nonatomic) Float32 temperature;

/// Measurement type: scheduled or manual.
/// 测量类型：定时或手动。
@property(assign, nonatomic) TemperatureType type;

+ (instancetype)initWithTime:(NSDate *)time temperature:(Float32)temperature type:(TemperatureType)type;

@end

NS_ASSUME_NONNULL_END
