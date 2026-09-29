//
//  QCSportInfoModel.h
//  QCBandSDK
//
//  Created by steve on 2024/2/21.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/OdmSportPlusModels.h>
#import  <QCBandSDK/QCDFU_Utils.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCSportInfoModel : NSObject

/// Sport type.
/// 运动类型。
@property (nonatomic, assign) OdmSportPlusExerciseModelType sportType;

/// Current sport state (start / pause / resume / stop).
/// 当前运动状态（开始 / 暂停 / 继续 / 结束）。
@property (nonatomic, assign) QCSportState state;

/// Duration in seconds.
/// 持续时长，单位：秒。
@property (nonatomic, assign) NSInteger duration;

/// Heart rate in bpm.
/// 心率，单位：次/分钟。
@property (nonatomic, assign) NSInteger hr;

/// Step count.
/// 步数。
@property (nonatomic, assign) NSInteger step;

/// Distance in meters.
/// 距离，单位：米。
@property (nonatomic, assign) NSInteger distance;

/// Calories in kcal.
/// 卡路里，单位：千卡。
@property (nonatomic, assign) NSInteger calorie;
@end

NS_ASSUME_NONNULL_END
