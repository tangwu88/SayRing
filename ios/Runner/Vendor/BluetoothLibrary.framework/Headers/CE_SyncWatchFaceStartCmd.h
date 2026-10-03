//
//  CE_SyncWatchFaceStartCmd.h
//  BluetoothLibrary
//
//  Created by kwan on 2020/12/26.
//  Copyright © 2020 kwan. All rights reserved.
//

#import <BluetoothLibrary/CE_Cmd.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Determine whether the device supports high-speed data transmission mode.
 The current data types supported by the high-speed data mode are `CE_SyncSystemFaceDataCmd`, `CE_SyncCustomFaceCmd`.
 */
@interface CE_SyncWatchFaceStartCmd : CE_Cmd

@end

NS_ASSUME_NONNULL_END
