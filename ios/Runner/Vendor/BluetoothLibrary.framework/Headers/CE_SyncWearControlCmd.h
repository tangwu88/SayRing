//
//  CE_SyncWearControlCmd.h
//  CLBluetoothModule
//
//  Created by coolwear0808 on 2025/6/9.
//

#import <BluetoothLibrary/CE_Cmd.h>


@interface CE_SyncWearControlCmd : CE_Cmd

// 0表示左手，1表示右手
@property (nonatomic) uint8_t wearWay;

@end
