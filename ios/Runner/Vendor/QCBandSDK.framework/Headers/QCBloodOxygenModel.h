//
//  BloodOxygenModel.h
//  OudmonBandV1
//
//  Created by ZongBill on 16/5/23.
//  Copyright © 2016年 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
/**
 @enum BloodOxygenTypeLow Low SpO2. 低氧
 @enum BloodOxygenTypeNormal Normal. 正常
 @enum BloodOxygenTypeHigh High. 偏高
 */
typedef enum : NSUInteger {
    BloodOxygenTypeLow = 0,
    BloodOxygenTypeNormal,
    BloodOxygenTypeHigh,
} BloodOxygenType;

extern NSString *const OdmBandRealTimeBloodOxygenFinish;


@interface QCBloodOxygenModel : NSObject

@property (assign, nonatomic) CGFloat maxSoa2;           // Max SpO2. 最大血氧饱和度
@property (assign, nonatomic) CGFloat minSoa2;           // Min SpO2. 最小血氧饱和度
@property (assign, nonatomic) CGFloat soa2;             // SpO2. 血氧饱和度
@property (strong, nonatomic) NSDate *date;             // Measurement time. 测量时间
@property (assign, nonatomic) BloodOxygenType soa2Type; // SpO2 type: low/normal/high. 血氧饱和度类型：低氧/正常/偏高
@property (assign, nonatomic) NSInteger sourceType;     // Data source: 0=scheduled, 1=manual. 血氧数据类型：0 定时，1 手动测量
@property (assign, nonatomic) BOOL isSubmit;            // Whether submitted to server. 是否已提交服务器
@property (strong, nonatomic) NSString *device;         // Device name. 设备名称

+ (instancetype)bloodOxygenWithSoa2:(CGFloat)soa2;

+ (instancetype)bloodOxygenWithSoa2:(CGFloat)soa2 testDate:(NSDate *)date;

+ (instancetype)bloodOxygenModelFromResponseObject:(NSDictionary *)dict;

@end
