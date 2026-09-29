//
//  QCMslPrayerModel.h
//  QiFit
//
//  Created by steve on 2024/8/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCMslPrayerModel : NSObject

@property (strong, nonatomic) NSArray<NSNumber *> *counts;      // Prayer counts. 次数
@property (strong, nonatomic) NSString *date;                     // Date, format yyyy-MM-dd. 时间，格式 yyyy-MM-dd
@property (nonatomic, assign) NSInteger secondInterval;        // Data interval, unit: seconds. 数据时间间隔，单位：秒

@end

NS_ASSUME_NONNULL_END
