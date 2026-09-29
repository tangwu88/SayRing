//
//  QCStressModel.h
//  QCBandSDK
//
//  Created by steve on 2024/2/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCStressModel : NSObject

/// Day string, format "yyyy-MM-dd".
/// 日期字符串，格式 "yyyy-MM-dd"。
@property (nonatomic, strong) NSString *date;

/// Stress value array.
/// 压力值数组。
@property (nonatomic, strong) NSArray<NSNumber *> *stresses;

/// Data interval, unit: seconds.
/// 数据时间间隔，单位：秒。
@property (nonatomic, assign) NSInteger secondInterval;

@end

NS_ASSUME_NONNULL_END
