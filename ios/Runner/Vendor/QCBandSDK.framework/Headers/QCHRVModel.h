//
//  QCHRVModel.h
//  QCBandSDK
//
//  Created by steve on 2024/8/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCHRVModel : NSObject

@property (nonatomic, strong) NSString *date;                  // Date, format "yyyy-MM-dd". 日期，格式 "yyyy-MM-dd"
@property (nonatomic, strong) NSArray<NSNumber *> *hrv;        // HRV array, one sample every N minutes. HRV 数组，每 N 分钟 1 条
@property (nonatomic, assign) NSInteger secondInterval;        // Data interval, unit: seconds. 数据时间间隔，单位：秒
@end

NS_ASSUME_NONNULL_END
