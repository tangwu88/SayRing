//
//  AlarmModel.h
//  OudmonBandV2
//
//  Created by steve on 2021/6/26.
//  Copyright © 2021 ODM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/OdmBleConstants.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCAlarmModel : NSObject

@property(nonatomic,assign) ALARMTYPE type; // Alarm type. 闹钟类型
@property(nonatomic,assign) NSInteger time; // Alarm time, e.g. 08:30. 闹钟时间，如：08:30
@property(nonatomic,strong) NSString *name; // Alarm name, max 30 bytes. 闹钟名称，最多 30 个 Byte
@property(nonatomic,strong) NSArray<NSString*>* weekDays; // Sun–Sat flags, 0=off, 1=on. 周日到周六状态，0=关闭，1=开启

- (NSData*)toCmd;

@end

NS_ASSUME_NONNULL_END
