//
//  AppleHealthCenter.h
//  WanKa
//
//  Created by cankujian on 15/8/19.
//  Copyright (c) 2015年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HKQuantityType;
@class HKQuantity;
@class HKObject;
@interface AppleHealthCenter : NSObject

@property (nonatomic, assign) NSInteger  appleHealthSteps;  // 保存上一次使用的最大步数，用来与最新步数相减获取当次更新的步数
@property (nonatomic, assign) NSInteger  appleHealthCalores;
@property (nonatomic, assign) NSInteger  appleHealthDistance;
@property (nonatomic, assign) double    appleHealthDateSince1970;

- (void)saveAppleHealthStepsCaloriesDistanceDateSince1970;
- (NSInteger)getAppleHealthSteps;


+ (instancetype)shareHealthyInstance;


/**  请求授权 健康数据的 读取权限 share是读。 NSSet: HKObjectType */
- (void)requestAuthorizationToShareTypes:(NSSet *)shareTypes
                               readTypes:(NSSet *)readTypes
                              completion:(void (^)(BOOL, NSError *))completion;

/**  获取健康对象 */
- (NSSet *)dataTypesToWrite;

/**  查询指定时间点之前的指定的数据类型的数据 */
- (void)apple_mostRecentQuantitySampleOfType:(HKQuantityType *)quantityType
                               predicateTime:(double)time
                                  completion:(void (^)(HKQuantity *quantity, NSError *error))completion;


/**  导入数据至苹果健康 */
- (void)saveObject:(HKObject *)object withCompletion:(void(^)(BOOL success, NSError *error))completion;

/**  导入   距离  数据至苹果健康 */
- (void)saveWalkingRunningObject:(double)length
                       startDate:(double)start
                         endDate:(double)end
                  withCompletion:(void(^)(BOOL success, NSError *error))completion;

/**  导入  步数  数据至苹果健康 */
- (void)saveStepCountObject:(double)steps
                  startDate:(double)start
                    endDate:(double)end
             withCompletion:(void(^)(BOOL success, NSError *error))completion;

/**  导入  卡路里  数据至苹果健康 start end 开始结束时间戳*/
- (void)saveCaloriesObject:(double)calories
                 startDate:(double)start
                   endDate:(double)end
            withCompletion:(void(^)(BOOL success, NSError *error))completion;

/**  导入 心率 到苹果健康  heartRate 心率 start end 开始结束时间戳*/
- (void)saveHeartRate:(double)heartRate
            startDate:(double)start
              endDate:(double)end
           completion:(void(^)(BOOL success, NSError *error))completion;


@end
