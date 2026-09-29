//
//  ExerciseModel.h
//  OudmonBandV2
//
//  Created by ZongBill on 2017/10/12.
//  Copyright © 2017年 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ExerciseType) {
    ExerciseTypeRun = 0,
    ExerciseTypeBike = 1,
    ExerciseTypeWeightLifting = 2,
    ExerciseTypeWalk = 3,
};


@interface QCExerciseModel : NSObject

@property (nonatomic, assign) NSInteger startTime;             // Start time, unit: ms. Primary key. 发生时间，单位：毫秒，主 Key
@property (nonatomic, assign) NSInteger lastSeconds;           // Duration, unit: seconds. 持续时间，单位：秒
@property (nonatomic, assign) ExerciseType type;               // Exercise mode. 锻炼模式
@property (nonatomic, assign) NSInteger steps;                 // Steps. 步数
@property (nonatomic, assign) NSInteger meters;                // Distance, unit: meters. 里程，单位：米
@property (nonatomic, assign) NSInteger calories;              // Calories. 卡路里，单位：卡
@property (nonatomic, strong) NSArray<NSNumber *> *heartRates; // Heart-rate array, one sample every 2 minutes. 心率数组，每 2 分钟 1 条
@property (nonatomic, assign) NSInteger serverID;              // Server id. 服务器 ID
@property (nonatomic, assign) NSInteger updateTime;            // Server update time, unit: ms. 服务器更新时间，单位：毫秒
@property (nonatomic, assign) BOOL usable;                     // Whether this record is visible/valid. 是否可用，本条记录是否显示/有效
@property (nonatomic, assign) BOOL isSync;                     // Whether synced to server. 是否已同步服务器

@end
