//
//  CE_GestureCmd.h
//  CLBluetoothModule
//
//  Created by zhangyin on 2024/9/1.
//

#import <BluetoothLibrary/CE_Cmd.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, Control_type) {
    GESTURE_CTRL_TYPE_NONE,
    GESTURE_CTRL_TYPE_TIKTOK,  // 短视频
    GESTURE_CTRL_TYPE_MUSIC,  // 音乐
    GESTURE_CTRL_TYPE_READER, // 阅读
    GESTURE_CTRL_TYPE_PHOTO,  // 拍照
    GESTURE_CTRL_TYPE_TELEPHONE, // 电话
    GESTURE_CTRL_TYPE_MAX
};


@interface CE_GestureCmd : CE_Cmd

@property (nonatomic, assign) Control_type type;

@end

NS_ASSUME_NONNULL_END
