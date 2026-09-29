//
//  QCManualHeartRateModel.h
//  QCBandPro
//
//  Created by steve on 2022/6/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCManualHeartRateModel : NSObject

@property (nonatomic, strong) NSString *date;                  // Date, format "yyyy-MM-dd". 日期，格式 "yyyy-MM-dd"
@property (nonatomic, strong) NSArray<NSNumber *> *heartRates; // Heart-rate array, one sample every N minutes. 心率数组，每 N 分钟 1 条
@property (nonatomic, strong) NSArray<NSNumber *> *hrTimes;    // Sample time in minutes from 00:00. 心率对应的当天分钟数
@end

NS_ASSUME_NONNULL_END
