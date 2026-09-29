//
//  QCFlipWristInfoModel.h
//  QCBandSDK
//
//  Created by steve on 2025/3/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCFlipWristInfoModel : NSObject

/// Whether raise-to-wake / flip-wrist is enabled.
/// 翻腕亮屏是否开启。
@property (nonatomic,assign) BOOL enable;

/// Wear hand: 1=Left, 2=Right.
/// 佩戴方式：1=左手，2=右手。
@property (nonatomic,assign) NSInteger flipType;

/// Brightness level.
/// 亮度调节。
@property (nonatomic,assign) NSInteger brightness;

/// Maximum brightness.
/// 最大亮度。
@property (nonatomic,assign) NSInteger brightnessMax;

/// Time mode: 1=custom, 2=off.
/// 时间模式：1=自定义，2=关闭。
@property (nonatomic,assign) NSInteger timeMode;

/// Screen-on start time (minutes from 00:00).
/// 亮屏开始时间（从 00:00 起算的分钟数）。
@property (nonatomic,assign) NSInteger startTime;

/// Screen-on end time (minutes from 00:00).
/// 亮屏结束时间（从 00:00 起算的分钟数）。
@property (nonatomic,assign) NSInteger endTime;
@end

NS_ASSUME_NONNULL_END
