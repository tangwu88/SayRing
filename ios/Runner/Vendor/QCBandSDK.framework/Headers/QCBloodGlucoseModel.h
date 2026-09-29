//
//  BloodGlucoseModel.h
//  QiFit
//
//  Created by steve on 2023/5/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 @enum BloodGlucoseTypeBeforeMeals Before meals. 饭前
 @enum BloodGlucoseTypeNormal Normal. 正常
 @enum BloodGlucoseTypeAfterMeals After meals. 饭后
 */
typedef enum : NSUInteger {
    QCBloodGlucoseTypeBeforeMeals = 0,
    QCBloodGlucoseTypeNormal,
    QCBloodGlucoseTypeAfterMeals,
} QCBloodGlucoseType;

typedef enum : NSUInteger {
    QCBloodGlucoseSourceTypeContinue = 0,
    QCBloodGlucoseSourceTypeRandom,
} QCBloodGlucoseModeType;

@interface QCBloodGlucoseModel : NSObject

@property (assign, nonatomic) CGFloat maxGlu;               // Max blood glucose. 最大血糖
@property (assign, nonatomic) CGFloat minGlu;               // Min blood glucose. 最小血糖
@property (assign, nonatomic) CGFloat glu;                  // Blood glucose. 血糖
@property (strong, nonatomic) NSDate *date;                 // Measurement time. 时间
@property (assign, nonatomic) QCBloodGlucoseModeType type;    // Source: 0=scheduled, 1=single. 数据类型（定时测量=0 / 单次测量=1）
@property (assign, nonatomic) QCBloodGlucoseType gluType;     // Glucose type: before meal / normal / after meal. 血糖类型：饭前/正常/饭后
@property (assign, nonatomic) BOOL isSubmit;                // Whether submitted to server. 是否已提交服务器
@property (strong, nonatomic) NSString *device;             // Device name. 设备名称
@end

NS_ASSUME_NONNULL_END
