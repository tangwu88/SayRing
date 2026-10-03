//
//  CE_SyncRRIHRVCmd.h
//  BluetoothLibrary
//
//  Created by coolwear on 2026/9/10.
//

#import <BluetoothLibrary/CE_Cmd.h>

NS_ASSUME_NONNULL_BEGIN

@interface CE_SyncRRIHRVCmd : CE_Cmd
// 0表示关闭RRI-HRV检测，1表示打开RRI-HRV检测
@property (nonatomic) uint8_t status;
@end

NS_ASSUME_NONNULL_END
