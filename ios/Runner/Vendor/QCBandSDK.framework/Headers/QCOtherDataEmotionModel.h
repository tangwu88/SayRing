//
//  QCOtherDataEmotionModel.h
//  QCBandSDK
//
//  Created by Cursor on 2026/6/17.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/QCEmotionItemModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCOtherDataEmotionModel : NSObject

/// Wire / wall-clock Unix of local day 00:00 (date + secondsFromGMT), same as 0x7B protocol.
/// 协议墙上时钟 Unix（本地当天 00:00 = date + secondsFromGMT），与 0x7B 协议一致。
@property (nonatomic, assign) uint32_t timestamp;

/// Day string, format "yyyy-MM-dd".
/// 日期字符串，格式 "yyyy-MM-dd"。
@property (nonatomic, strong) NSString *date;

/// Data interval in minutes.
/// 数据间隔，单位：分钟。
@property (nonatomic, assign) NSInteger interval;

/// Emotion samples for the day.
/// 当天情绪采样列表。
@property (nonatomic, strong) NSArray<QCEmotionItemModel *> *emotions;

@end

NS_ASSUME_NONNULL_END
