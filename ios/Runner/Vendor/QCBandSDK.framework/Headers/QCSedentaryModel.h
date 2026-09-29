//
//  QCSedentaryModel.h
//  QCBandSDK
//
//  Created by steve on 2024/9/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCSedentaryModel : NSObject

@property (nonatomic, strong) NSString *date; // Start time, format yyyy-MM-dd HH:mm:ss. 发生时间 yyyy-MM-dd HH:mm:ss
@property (nonatomic, strong) NSString *endTime; // End time, format yyyy-MM-dd HH:mm:ss. 结束时间 yyyy-MM-dd HH:mm:ss
@property (nonatomic, assign) NSInteger type; // 0=static (<30 steps in 1 min), 1=sedentary triggered, 2=active (>30 steps). 0 静态(1分钟内小于30步)，1触发久坐，2运动(大于30步)
@property (nonatomic, assign) NSInteger duration; // Duration, unit: minutes. 单位：分钟
@end

NS_ASSUME_NONNULL_END
