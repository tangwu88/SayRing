//
//  CE_SyncGsensorRawCmd.h
//  CLBluetoothModule
//
//  Created by coolwear0808 on 23/06/2026.
//

#import <BluetoothLibrary/CE_Cmd.h>

NS_ASSUME_NONNULL_BEGIN

@interface CE_SyncGsensorRawCmd : CE_Cmd
// 0表示关闭检测，1表示打开检测
@property (nonatomic) uint8_t status;
@end

NS_ASSUME_NONNULL_END
