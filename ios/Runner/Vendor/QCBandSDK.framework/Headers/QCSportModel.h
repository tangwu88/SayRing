//
//  SportModel.h
//  OdmLightBle
//
//  Created by ZongBill on 15/8/11.
//  Copyright (c) 2015年 X. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QCSportModel : NSObject

@property (nonatomic, assign) NSInteger totalStepCount; // Total steps, unit: steps. 总步数，单位：步
@property (nonatomic, assign) double calories;          // Calories. 卡路里
@property (nonatomic, assign) NSInteger distance;       // Distance, unit: meters. 距离，单位：米
@property (nonatomic, strong) NSString *happenDate;     // Occurred at, format "yyyy-MM-dd HH:mm:ss". 发生时间，格式 "yyyy-MM-dd HH:mm:ss"

/*!
 *  Pedometer parser. 计步器解析
 */
+ (QCSportModel *)initWith:(long)totalStep runStep:(long)runStep calories:(long)cal distance:(long)dis sportTime:(NSInteger)time happenDate:(NSString *)happenDate;

/// Parse real-time pedometer payload. 实时计步解析
+ (QCSportModel *)parsePedometerObjFromByte:(Byte *)byte;

@end
