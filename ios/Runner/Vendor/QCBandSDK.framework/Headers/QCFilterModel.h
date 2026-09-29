//
//  QCFilterModel.h
//  QCBandSDK
//
//  Created by qc on 2026/4/13.
//

#import <Foundation/Foundation.h>
#import <QCBandSDK/QCDFU_Utils.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCFilterModel : NSObject

/// Notification app type.
/// 消息通知应用类型。
@property(nonatomic,assign) QC_FILTER_APP_TYPE appType;

/// YES = this app notification is enabled.
/// YES 表示该应用通知已开启。
@property(nonatomic,assign) BOOL isOn;

@end

NS_ASSUME_NONNULL_END
