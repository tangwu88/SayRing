//
//  QCEmotionItemModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/6/17.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/QCDFU_Utils.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCEmotionItemModel : NSObject

/// Emotion score / raw value from device.
/// 设备上报的情绪分数 / 原始值。
@property (nonatomic, assign) NSInteger value;

/// Emotion status enum (QCEmotionStatus).
/// 情绪状态枚举（QCEmotionStatus）。
@property (nonatomic, assign) QCEmotionStatus status;

@end

NS_ASSUME_NONNULL_END
