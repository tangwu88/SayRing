//
//  HeartRateModel.h
//  Band
//
//  Created by panguo on 16/1/15.
//  Copyright © 2016年 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const OdmBandRealTimeHeartRateFinish;


@interface QCHeartRateModel : NSObject

@property (assign, nonatomic) NSInteger hrId;      ///< Heart-rate record id. 心率 id
@property (strong, nonatomic) NSDate *date;        ///< Measurement time. 测量时间
@property (assign, nonatomic) NSInteger heartrate; ///< Heart-rate value. 心率值

+ (instancetype)heartRateModelWithHeartRate:(NSInteger)hr;

@end
